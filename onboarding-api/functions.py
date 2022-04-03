import json
import os
import time
import requests
import googleapiclient.discovery
from google.cloud import pubsub_v1
from google.oauth2 import service_account
from google.cloud import logging


class Status:
    deploy_exist = 1
    deploy_not_exist = 2
    error = 3


# variables
project_id = os.environ['PROJECT_ID']
region = os.environ['REGION']
service_account_name = "cloudguard-logs-authentication"
audience = "dome9-gcp-logs-collector"
ack_deadline = 60
min_retry_delay = "10s"
max_retry_delay = "60s"
topic_name = ""
subscription_name = ""
sink_name = ""
sink_destination = ""
sink_filter = ""
endpoint = ""
binding_name = ""
logType = ""


def set_variables(log_type):
    global logType
    logType = log_type
    global topic_name
    topic_name = "cloudguard-fl-topic" if log_type == "flowlogs" else "cloudguard-topic"
    global subscription_name
    subscription_name = "cloudguard-fl-subscription" if log_type == "flowlogs" else "cloudguard-subscription"
    global sink_name
    sink_name = "cloudguard-fl-sink" if log_type == "flowlogs" else "cloudguard-sink"
    global sink_destination
    sink_destination = f"pubsub.googleapis.com/projects/{project_id}/topics/{topic_name}"
    global sink_filter
    sink_filter = 'LOG_ID("compute.googleapis.com%2Fvpc_flows")' if log_type == "flowlogs" else 'LOG_ID("cloudaudit.googleapis.com/activity") OR LOG_ID("cloudaudit.googleapis.com%2Fdata_access") OR LOG_ID("cloudaudit.googleapis.com%2Fpolicy")'
    global binding_name
    binding_name = "cloudguard-fl-binding" if log_type == "flowlogs" else "cloudguard-binding"
    global endpoint
    if region == "central":
        endpoint = "https://gcp-flow-logs-endpoint.dome9.com" if log_type == 'flowlogs' else "https://gcp-activity-endpoint.dome9.com"
    else:
        endpoint = f"https://gcp-flow-logs-endpoint.logic.{region}.dome9.com" if log_type == 'flowlogs' else f"https://gcp-activity-endpoint.logic.{region}.dome9.com"


def cloudguard_onboarding():
    api_key = os.environ['API_KEY']
    api_secret = os.environ['API_SECRET']
    headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*'
    }
    # https://localhost:5551/v2/view/magellan/magellan-gcp-onboarding
    # https://api.dome9.com/v2/view/magellan/magellan-Gcp-onboarding
    data = {
        "CloudAccounts": [
            os.environ['PROJECT_ID']
        ],
        "LogType": os.environ['LOG_TYPE']
    }
    r = requests.post('https://api.941298424820.dev.falconetix.com/v2/view/magellan/magellan-gcp-onboarding',
                      data=json.dumps(data), headers=headers, auth=(api_key, api_secret))

    print(r.json())
    print("Done cloud guard onboarding")
    return r.json()


def cloudguard_offboarding():
    api_key = os.environ['API_KEY']
    api_secret = os.environ['API_SECRET']
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    data = {
        "cloudAccountId": os.environ['CLIENT_ID'],
        "vendor": "GCP"
    }
    r = requests.post('https://api.941298424820.dev.falconetix.com/v2/view/magellan/disable-magellan-for-cloud-account',
                      data=json.dumps(data), headers=headers, auth=(api_key, api_secret))

    print(r.json())
    print("Done cloudguard offboarding")
    return r.json()


def get_deployment_manager_object():
    credentials = service_account.Credentials.from_service_account_file(
        filename=os.environ['GOOGLE_APPLICATION_CREDENTIALS'],
        scopes=['https://www.googleapis.com/auth/cloud-platform'])
    service = googleapiclient.discovery.build('deploymentmanager', 'v2', credentials=credentials)
    deployService = service.deployments();
    return deployService;


def delete_deployment():
    deploy_service = get_deployment_manager_object()
    deployment_list = deploy_service.list(
        project=os.environ['PROJECT_ID'],
        filter='name=cloudguard-onboarding-api-' + logType.lower()
    ).execute()
    if len(deployment_list) > 0:
        print("Start delete previous deployment")
        request = deploy_service.delete(
            project=project_id,
            deployment="cloudguard-onboarding-api-" + logType.lower(),
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
        print("Deleted sink {}".format(sink.name))

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
                print('Deleted service account')


def create_resources(resources_yaml_format):
    print("Start Deployment");
    deploy_service = get_deployment_manager_object()
    request = deploy_service.insert(
        project=project_id,
        createPolicy='CREATE_OR_ACQUIRE',
        body=
        {
            "name": "cloudguard-onboarding-api-" + logType.lower(),
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
            deployment="cloudguard-onboarding-api-" + logType.lower())
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