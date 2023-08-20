import json
import requests
import hashlib
import re
import argparse
from google.cloud import logging
from google.cloud import pubsub_v1
import googleapiclient.discovery
from google.cloud.pubsub_v1.types import PushConfig


def validate_region(region):
    valid_regions = ['us', 'eu1', 'ap1', 'ap2', 'ap3', 'cace1']
    if region not in valid_regions:
        raise argparse.ArgumentTypeError(f"Invalid region: {region}. Valid regions are: {', '.join(valid_regions)}")
    return region


def validate_log_type(log_type):
    valid_log_types = ['NetworkTraffic', 'AccountActivity']
    if log_type not in valid_log_types:
        raise argparse.ArgumentTypeError(
            f"Invalid log type: {log_type}. Valid log types are: {', '.join(valid_log_types)}")
    return log_type


def validate_pubsub_topic(topic):
    if not re.match(r'^projects/[^/]+/topics/[^/]+$', topic):
        raise argparse.ArgumentTypeError(
            f"Invalid pubsub topic format: {topic}. Example format: 'projects/<projectId>/topics/<topicName>'")
    return topic


def validate_boolean(value):
    if value.lower() not in ('true', 'false'):
        raise argparse.ArgumentTypeError("Invalid boolean value. Use 'true' or 'false'.")
    return value.lower() == 'true'


def md5_hash_from_timestamp(timestamp):
    timestamp_str = str(timestamp)
    md5 = hashlib.md5()
    md5.update(timestamp_str.encode('utf-8'))
    md5_hash = md5.hexdigest()
    return md5_hash


def parse_topic_name(topic_name):
    try:
        _, project_id, _, topic_id = topic_name.split('/')
        return project_id, topic_id
    except ValueError:
        raise ValueError("Invalid topic name format. Must be in the format 'projects/PROJECT_ID/topics/TOPIC_ID'")


def getLogFilter(log_type):
    return (
        'LOG_ID("cloudaudit.googleapis.com/activity") OR LOG_ID("cloudaudit.googleapis.com%2Fdata_access") OR LOG_ID("cloudaudit.googleapis.com%2Fpolicy")'
        if log_type == "AccountActivity"
        else 'LOG_ID("compute.googleapis.com%2Fvpc_flows")'
    )


def get_validator_endpoint(region, log_type):
    match region:
        case "us":
            return (
                "https://gcp-activity-endpoint.logic.dome9.com"
                if log_type == "AccountActivity"
                else "https://gcp-flowlogs-endpoint.logic.dome9.com"
            )
        case "eu1", "ap1", "ap2", "ap3", "cace1":
            return (
                f"https://gcp-activity-endpoint.logic.{region}.dome9.com"
                if log_type == "AccountActivity"
                else f"https://gcp-flowlogs-endpoint.logic.{region}.dome9.com"
            )
        case _:
            print("Invalid region.")


def get_cloudguard_domain(region):
    return (
        'https://api.941298424820.dev.falconetix.com'
        if region == "us"
        else f'https://api.{region}.dome9.com'
    )


def create_service_account(project_id, service_account_name, credentials):
    try:
        service = googleapiclient.discovery.build("iam", "v1", credentials=credentials)
        existing_service_accounts = (service.projects().serviceAccounts().list(name="projects/" + project_id).execute())
        cloud_guard_service_account = list(
            filter(lambda obj: service_account_name in obj["email"], existing_service_accounts['accounts']))
        if not cloud_guard_service_account:
            my_service_account = (service.projects().serviceAccounts().create(
                name="projects/" + project_id,
                body={"accountId": service_account_name, "serviceAccount": {"displayName": service_account_name}},
            ).execute())
            print(f"Created service account: {my_service_account['email']}.")
            return my_service_account['email']
        else:
            print(f"Service account {cloud_guard_service_account[0]['email']} already exists.")
            return cloud_guard_service_account[0]['email']
    except Exception as e:
        raise Exception(f"Failed to create service account, {e}")


def delete_service_account(project_id, service_accounts, credentials):
    for service_account in service_accounts:
        try:
            service = googleapiclient.discovery.build("iam", "v1", credentials=credentials)
            existing_service_accounts = (service.projects().serviceAccounts().list(name="projects/" + project_id).execute())
            cloud_guard_service_account = list(
                filter(lambda obj: service_account in obj["email"], existing_service_accounts['accounts']))
            if cloud_guard_service_account:
                (service.projects().serviceAccounts().delete(
                    name=cloud_guard_service_account[0]["name"]
                ).execute())
                print(f"Service account: {cloud_guard_service_account[0]['email']} deleted.")
        except Exception as e:
            print(f"Failed to delete service account {service_account}, {e}")


def create_pubsub_topic(project_id, topic_id, credentials):
    try:
        pubsub_publisher_client = pubsub_v1.PublisherClient(credentials=credentials)
        topic_path = pubsub_publisher_client.topic_path(project_id, topic_id)
        pubsub_publisher_client.get_topic(request={"topic": topic_path})
        print(f"Pub/Sub topic {topic_path} already exists.")
        return topic_path
    except Exception as e:
        if e.code == 404:
            pubsub_publisher_client.create_topic(request={"name": topic_path})
            print(f"Created Pub/Sub topic: '{topic_path}'.")
            return topic_path
        else:
            raise Exception(f"Failed to create Pub/Sub topic, {e}")


def delete_pubsub_topics(topics, credentials):
    for topic in topics:
        try:
            pubsub_publisher_client = pubsub_v1.PublisherClient(credentials=credentials)
            pubsub_publisher_client.delete_topic(request={"topic": topic})
            print(f"Pub/Sub topic {topic} deleted.")
        except Exception as e:
            if e.code == 404:
                print(f"Failed to delete Pub/Sub topic, {topic} not exists.")
            else:
                print(f"Failed to delete Pub/Sub topic {topic}, {e}")


def create_pubsub_subscription(project_id, subscription_name, topic_name, service_account_name, validator_endpoint,
                               credentials):
    try:
        pubsub_subscriber_client = pubsub_v1.SubscriberClient(credentials=credentials)
        subscription_path = pubsub_subscriber_client.subscription_path(project_id, subscription_name)
        pubsub_subscriber_client.get_subscription(request={"subscription": subscription_path})
        print(f"Pub/Sub subscription {subscription_path} already exists.")
        return subscription_path
    except Exception as e:
        if e.code == 404:
            # Create the subscription
            push_config = PushConfig(
                push_endpoint=validator_endpoint,
                oidc_token=PushConfig.OidcToken(
                    service_account_email=service_account_name,
                    audience="dome9-gcp-logs-collector"
                ))
            pubsub_subscriber_client.create_subscription(
                request={
                    "name": subscription_path,
                    "topic": topic_name,
                    "ack_deadline_seconds": 60,
                    "expiration_policy": {},
                    "retry_policy": {
                        "minimum_backoff": "10s",
                        "maximum_backoff": "60s"
                    },
                    "push_config": push_config
                }
            )
            print(f"Created Pub/Sub subscription: {subscription_path}.")
            return subscription_path
        else:
            raise Exception(f"Failed to create Pub/Sub subscription, {e}")


def delete_pubsub_subscriptions(subscriptions, credentials):
    for subscription in subscriptions:
        try:
            pubsub_subscriber_client = pubsub_v1.SubscriberClient(credentials=credentials)
            with pubsub_subscriber_client:
                pubsub_subscriber_client.delete_subscription(request={"subscription": subscription})
            print(f"Pub/Sub subscription {subscription} deleted.")
        except Exception as e:
            if e.code == 404:
                print(f"Failed to delete Pub/Sub subscription, {subscription} not exists.")
            else:
                print(f"Failed to delete Pub/Sub subscription {subscription}, {e}")


def create_logging_sink(sink_project_id, sink_name, topic_name, log_filter, credentials):
    try:
        pubsub_publisher_client = pubsub_v1.PublisherClient(credentials=credentials)
        logging_client = logging.Client(project=sink_project_id, credentials=credentials)
        sink = logging_client.sink(sink_name, filter_=log_filter, destination=f"pubsub.googleapis.com/{topic_name}")
        if sink.exists():
            print(f"Sink {sink.name} already exists.")
        else:
            sink.create(unique_writer_identity=True)
            print(f"Created sink {sink.name}")
            policy = pubsub_publisher_client.get_iam_policy(request={"resource": topic_name})
            policy.bindings.add(role="roles/pubsub.publisher", members=[sink.writer_identity])
            pubsub_publisher_client.set_iam_policy(
                request={"resource": topic_name, "policy": policy}
            )
        return {"ProjectId": sink_project_id, "SinkName": sink_name, "TopicName": topic_name}
    except Exception as e:
        raise Exception(f"Failed to create {sink_name} in {sink_project_id} project, {e}")


def delete_logging_sinks(sinks, credentials):
    for sink in sinks:
        try:
            logging_client = logging.Client(project=sink['projectId'], credentials=credentials)
            logging_sink = logging_client.sink(sink['sinkName'])
            if logging_sink.exists():
                logging_sink.delete()
                print(f"Sink {logging_sink.name} deleted.")
            else:
                print(f"Failed to delete sink, {sink['sinkName']} not exists.")
        except Exception as e:
            print(f"Failed to delete sink: {sink['sinkName']}, {e}")


def cloudguard_onboarding_request(token, data, region):
    domain = get_cloudguard_domain(region)
    headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        "Authorization": f"Bearer {token}"
    }
    try:
        response = requests.post(f'{domain}/v2/intelligence/gcp/onboarding',
                                 data=json.dumps(data), headers=headers)
        if response.status_code != 200 and response.status_code != 201:
            raise Exception(f"Failed to onboard: {response.text}")
    except requests.exceptions.RequestException as e:
        raise Exception(f"Failed to onboard , {e}")


def cloudguard_offboarding_request(project_id, token, region):
    domain = get_cloudguard_domain(region)
    headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        "Authorization": f"Bearer {token}"
    }
    data = {
        "cloudAccountId": project_id,
        "vendor": "GCP"
    }

    try:
        response = requests.post(f'{domain}/v2/view/magellan/disable-magellan-for-cloud-account',
                                 data=json.dumps(data), headers=headers)
        if response.status_code != 200 and response.status_code != 201:
            raise Exception(f"Failed to offboard: {response.text}")
    except requests.exceptions.RequestException as e:
        raise Exception(f"Failed to offboard , {e}")


def get_topics_from_intelligence(token, project_id, region):
    domain = get_cloudguard_domain(region)
    headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        "Authorization": f"Bearer {token}"
    }
    body = {
        "projectId": project_id
    }
    try:
        response = requests.post(f'{domain}/v2/intelligence/gcp/connected_topics',
                                 data=json.dumps(body), headers=headers)
        if response.status_code != 200 and response.status_code != 201:
            raise Exception(f"Failed to get Pub/Sub topics from Intelligence: {response.text}")
        return response.json()
    except requests.exceptions.RequestException as e:
        raise Exception(f"Failed to get Pub/Sub topics from Intelligence: {e}")


def get_connected_sinks_from_intelligence(token, project_id, region):
    domain = get_cloudguard_domain(region)
    headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        "Authorization": f"Bearer {token}"
    }
    body = {
        "projectId": project_id
    }
    try:
        response = requests.post(f'{domain}/v2/intelligence/gcp/logging-sinks',
                                 data=json.dumps(body), headers=headers)
        if response.status_code != 200 and response.status_code != 201:
            raise Exception(f"Failed to get Pub/Sub topics from Intelligence: {response.text}")
        return response.json()
    except requests.exceptions.RequestException as e:
        raise Exception(f"Failed to get Pub/Sub topics from Intelligence: {e}")


def get_token(api_key, api_secret, region):
    domain = get_cloudguard_domain(region)
    headers = {
        "Content-Type": "application/json",
        'Accept': '*/*'
    }

    try:
        response = requests.post(f'{domain}/v2/auth/assume-role/jwt', headers=headers, json={},
                                 auth=(api_key, api_secret))
        if response.status_code != 200 and response.status_code != 201:
            raise Exception(f"Failed to get CloudGuard token: {response.text}")
        response_data = response.json()
        return response_data['token']
    except requests.exceptions.RequestException as e:
        raise Exception(f"Failed to get CloudGuard token: {e}")
