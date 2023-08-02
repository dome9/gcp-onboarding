import json
import requests
from google.cloud import logging
from google.cloud import pubsub_v1
import googleapiclient.discovery
from google.cloud.pubsub_v1.types import PushConfig


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


def getCloudGuardEndpoint(region, log_type):
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


def create_service_account(project_id, service_account_name, credentials):
    service = googleapiclient.discovery.build("iam", "v1", credentials=credentials)
    try:
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
        print(f"Failed to create service account. {e.content.decode('utf-8')}")


def create_pubsub_topic(project_id, topic_id, credentials):
    pubsub_publisher_client = pubsub_v1.PublisherClient(credentials=credentials)
    topic_path = pubsub_publisher_client.topic_path(project_id, topic_id)
    try:
        pubsub_publisher_client.get_topic(request={"topic": topic_path})
        print(f"Pub/Sub topic {topic_path} already exists.")
        return topic_path
    except Exception as e:
        if e.code == 404:
            pubsub_publisher_client.create_topic(request={"name": topic_path})
            print(f"Created Pub/Sub topic: '{topic_path}'.")
            return topic_path
        else:
            print(f"Failed to create Pub/Sub topic, {e.message}")


def get_pubsub_topic(topic_name, credentials):
    pubsub_publisher_client = pubsub_v1.PublisherClient(credentials=credentials)
    try:
        return pubsub_publisher_client.get_topic(request={"topic": topic_name})
    except Exception as e:
        print(f"Failed to get Pub/Sub topic from GCP, {e.message}")


def create_pubsub_subscription(project_id, subscription_name, topic_name, service_account_name, credentials):
    pubsub_subscriber_client = pubsub_v1.SubscriberClient(credentials=credentials)
    cloud_guard_endpoint = getCloudGuardEndpoint(region, log_type)

    subscription_path = pubsub_subscriber_client.subscription_path(project_id, subscription_name)
    try:
        pubsub_subscriber_client.get_subscription(request={"subscription": subscription_path})
        print(f"Pub/Sub subscription {subscription_path} already exists.")
        return subscription_path
    except Exception as e:
        if e.code == 404:
            # Create the subscription
            push_config = PushConfig(
                push_endpoint=cloud_guard_endpoint,
                oidc_token=PushConfig.OidcToken(
                    service_account_email=service_account_name,
                    audience="dome9-gcp-logs-collector"
                ))
            pubsub_subscriber_client.create_subscription(
                request={
                    "name": subscription_path,
                    "topic": topic_name,
                    "ack_deadline_seconds": 60,  # Replace with your desired value
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
            print(f"Failed to create Pub/Sub subscription, {e.message}")


def create_logging_sink(sink_project_id, sink_name, topic_name, log_filter, credentials):
    pubsub_publisher_client = pubsub_v1.PublisherClient(credentials=credentials)
    logging_client = logging.Client(project=sink_project_id, credentials=credentials)

    try:
        sink = logging_client.sink(sink_name, filter_=log_filter, destination=f"pubsub.googleapis.com/{topic_name}")
        if sink.exists():
            print(f"Sink {sink.name} already exists.")
        else:
            sink.create()
            print(f"Created sink {sink.name}")
            policy = pubsub_publisher_client.get_iam_policy(request={"resource": topic_name})
            policy.bindings.add(role="roles/pubsub.publisher", members=[sink.writer_identity])
            pubsub_publisher_client.set_iam_policy(
                request={"resource": topic_name, "policy": policy}
            )
        return {"ProjectId": sink_project_id, "SinkName": sink_name, "TopicName": topic_name}
    except Exception as e:
        print(f"Failed to create {sink_name} in {sink_project_id} project, {e.message}")


def cloudguard_onboarding(api_key, api_secret, data, headers, region):
    if region == "us":
        response = requests.post('https://api.dome9.com/v2/intelligence/gcp/onboarding',
                                 data=json.dumps(data), headers=headers, auth=(api_key, api_secret))
    else:
        response = requests.post(f'https://api.{region}.dome9.com/v2/intelligence/gcp/onboarding',
                                 data=json.dumps(data), headers=headers, auth=(api_key, api_secret))
    return response.json()