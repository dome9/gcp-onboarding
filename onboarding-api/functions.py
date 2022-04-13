import json
import os
import time
import requests
import yaml
import googleapiclient.discovery
from google.cloud import pubsub_v1
from google.oauth2 import service_account
from google.cloud import logging


class Status:
    deploy_exist = 1
    deploy_not_exist = 2
    error = 3


project_id = region = api_key_var = api_secret_var = client_id = log_type_var = ""  # user input
topic_name = subscription_name = sink_name = sink_destination = sink_filter = endpoint = binding_name = ""  # depends on user input
service_account_name = "cloudguard-logs-authentication"
audience = "dome9-gcp-logs-collector"
ack_deadline = 60
min_retry_delay = "10s"
max_retry_delay = "60s"


def set_variables(project_id_arg, region_arg, api_key_arg, api_secret_arg, client_id_arg, log_type_arg):
    global project_id, region, api_key_var, api_secret_var, client_id, log_type_var
    project_id = project_id_arg
    region = region_arg
    api_key_var = api_key_arg
    api_secret_var = api_secret_arg
    client_id = client_id_arg
    log_type_var = log_type_arg

    global topic_name, subscription_name, sink_name, sink_destination, sink_filter, binding_name, endpoint
    topic_name = "cloudguard-fl-topic" if log_type_var == "flowlogs" else "cloudguard-topic"
    subscription_name = "cloudguard-fl-subscription" if log_type_var == "flowlogs" else "cloudguard-subscription"
    sink_name = "cloudguard-fl-sink" if log_type_var == "flowlogs" else "cloudguard-sink"
    sink_destination = f"pubsub.googleapis.com/projects/{project_id}/topics/{topic_name}"
    sink_filter = 'LOG_ID("compute.googleapis.com%2Fvpc_flows")' if log_type_var == "flowlogs" else 'LOG_ID("cloudaudit.googleapis.com/activity") OR LOG_ID("cloudaudit.googleapis.com%2Fdata_access") OR LOG_ID("cloudaudit.googleapis.com%2Fpolicy")'
    binding_name = "cloudguard-fl-binding" if log_type_var == "flowlogs" else "cloudguard-binding"
    if region == "central" or region == "us":
        endpoint = f"https://gcp-flowlogs-endpoint.dome9.com" if log_type_var == 'flowlogs' else f"https://gcp-activity-endpoint.dome9.com"
    else:
        endpoint = f"https://gcp-flowlogs-endpoint.logic.{region}.dome9.com" if log_type_var == 'flowlogs' else f"https://gcp-activity-endpoint.logic.{region}.dome9.com"


def get_resources_yaml():
    resources_json = {
        "resources": [
            {
                "name": service_account_name,
                "properties": {
                    "accountId": service_account_name,
                    "displayName": service_account_name
                },
                "type": "gcp-types/iam-v1:projects.serviceAccounts"
            },
            {
                "name": topic_name,
                "properties": {
                    "topic": topic_name
                },
                "type": "gcp-types/pubsub-v1:projects.topics"
            },
            {
                "name": subscription_name,
                "properties": {
                    "ackDeadlineSeconds": ack_deadline,
                    "expirationPolicy": {},
                    "pushConfig": {
                        "oidcToken": {
                            "audience": audience,
                            "serviceAccountEmail": f"{service_account_name}@{project_id}.iam.gserviceaccount.com"
                        },
                        "pushEndpoint": endpoint
                    },
                    "retryPolicy": {
                        "maximumBackoff": max_retry_delay,
                        "minimumBackoff": min_retry_delay
                    },
                    "subscription": subscription_name,
                    "topic": f"$(ref.{topic_name}.name)"
                },
                "type": "gcp-types/pubsub-v1:projects.subscriptions"
            },
            {
                "name": sink_name,
                "properties": {
                    "destination": f"pubsub.googleapis.com/$(ref.{topic_name}.name)",
                    "filter": sink_filter,
                    "sink": sink_name
                },
                "type": "gcp-types/logging-v2:projects.sinks"
            },
            {
                "accessControl": {
                    "gcpIamPolicy": {
                        "bindings": [
                            {
                                "members": [
                                    f"$(ref.{sink_name}.writerIdentity)"
                                ],
                                "role": "roles/pubsub.publisher"
                            }
                        ]
                    }
                },
                "name": binding_name,
                "properties": {
                    "topic": topic_name
                },
                "type": "pubsub.v1.topic"
            }
        ]
    }
    resources_yaml_format = yaml.dump(resources_json)
    return resources_yaml_format


def cloudguard_onboarding():
    api_key = api_key_var
    api_secret = api_secret_var
    headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*'
    }
    data = {
        "CloudAccounts": [
            project_id
        ],
        "LogType": log_type_var
    }
    if region == "central" or region == "us":
        r = requests.post('https://api.dome9.com/v2/view/magellan/magellan-gcp-onboarding',
                          data=json.dumps(data), headers=headers, auth=(api_key, api_secret))
    else:
        r = requests.post(f'https://api.{region}.dome9.com/v2/view/magellan/magellan-gcp-onboarding',
                          data=json.dumps(data), headers=headers, auth=(api_key, api_secret))
    return r.json()


def cloudguard_offboarding():
    api_key = api_key_var
    api_secret = api_secret_var
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    data = {
        "cloudAccountId": project_id,
        "vendor": "GCP"
    }
    if region == "central" or region == "us":
        r = requests.post('https://api.dome9.com/v2/view/magellan/disable-magellan-for-cloud-account',
                          data=json.dumps(data), headers=headers, auth=(api_key, api_secret))
    else:
        r = requests.post(f'https://api.{region}.dome9.com/v2/view/magellan/disable-magellan-for-cloud-account',
                          data=json.dumps(data), headers=headers, auth=(api_key, api_secret))
    return r.json()


def get_deployment_manager_object():
    credentials = service_account.Credentials.from_service_account_file(
        filename=os.environ['GOOGLE_APPLICATION_CREDENTIALS'],
        scopes=['https://www.googleapis.com/auth/cloud-platform'])
    service = googleapiclient.discovery.build('deploymentmanager', 'v2', credentials=credentials)
    deploy_service = service.deployments();
    return deploy_service;


def delete_deployment():
    deploy_service = get_deployment_manager_object()
    deployment_list = deploy_service.list(
        project=project_id,
        filter='name=cloudguard-onboarding-api-' + log_type_var.lower()
    ).execute()
    if len(deployment_list) > 0:
        print("Starting to delete previous deployment");
        request = deploy_service.delete(
            project=project_id,
            deployment="cloudguard-onboarding-api-" + log_type_var.lower(),
            deletePolicy='DELETE');
        try:
            response = request.execute()
            status = check_deployment_status()
            return status
        except Exception as e:
            print(e)
            return Status.error
    return


def delete_resources():
    # sink deletion
    logging_client = logging.Client()
    sink = logging_client.sink(sink_name)
    if sink.exists():
        sink.delete()
        print("Sink deleted: {}".format(sink.name))

    # subscription deletion
    subscriber = pubsub_v1.SubscriberClient()
    subscription_path = subscriber.subscription_path(project_id, subscription_name)
    with subscriber:
        for subscription in subscriber.list_subscriptions(request={"project": f"projects/{project_id}"}):
            if subscription.name == subscription_path:
                subscriber.delete_subscription(request={"subscription": subscription_path})
                print(f"Subscription deleted: {subscription_path}.")

    # topic deletion
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(project_id, topic_name)
    for topic in publisher.list_topics(request={"project": f"projects/{project_id}"}):
        if topic.name == topic_path:
            publisher.delete_topic(request={"topic": topic_path})
            print(f"Topic  deleted: {topic_path}")

    # service account deletion
    credentials = service_account.Credentials.from_service_account_file(
        filename=os.environ['GOOGLE_APPLICATION_CREDENTIALS'],
        scopes=['https://www.googleapis.com/auth/cloud-platform'])
    service = googleapiclient.discovery.build('iam', 'v1', credentials=credentials)
    service_accounts = service.projects().serviceAccounts().list(name='projects/' + project_id).execute()
    for service_account_item in service_accounts['accounts']:
        if service_account_item['displayName'] == service_account_name:
            request = service.projects().serviceAccounts().delete(
                name='projects/' + project_id + '/serviceAccounts/' + service_account_name + '@' + project_id + ".iam.gserviceaccount.com")
            if request is not None:
                response = request.execute()
                print(f'Service account deleted: {service_account_name}')


def create_resources(resources_yaml_format):
    print("Deployment Started");
    deploy_service = get_deployment_manager_object()
    request = deploy_service.insert(
        project=project_id,
        createPolicy='CREATE_OR_ACQUIRE',
        body=
        {
            "name": "cloudguard-onboarding-api-" + log_type_var.lower(),
            "target": {
                "config": {
                    "content": resources_yaml_format
                }
            }
        })
    try:
        response = request.execute()
        status = check_deployment_status()
        return status
    except Exception as e:
        if 'already exists and cannot be created' in e.reason:
            print("Deployment already exist. You should do offboarding and than try again.")
            return Status.error
        else:
            print(e)
            return Status.error


def check_deployment_status():
    print('Waiting for operation to finish...')
    deploy_service = get_deployment_manager_object()
    while True:
        request = deploy_service.get(
            project=project_id,
            deployment="cloudguard-onboarding-api-" + log_type_var.lower())
        try:
            response = request.execute()
            if response['operation']['status'] == 'DONE':
                if 'error' in response['operation']:
                    print(response['operation']['error'])
                    return Status.error
                else:
                    return Status.deploy_exist
        except Exception as e:
            if 'is not found' in e.reason:
                return Status.deploy_not_exist
            else:
                print(e)
                return Status.error
        time.sleep(1)
