import hashlib
import re
import argparse


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


def get_log_filter(log_type):
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


def create_resource_lists_to_delete(cloudguard_service, connected_topics, project_id):
    service_account_name = "cloudguard-centralized-auth"
    topic_list = []
    subscription_list = []
    sink_list = []
    service_account_list = []

    # current project is centralized
    if connected_topics['topics']:
        for topic in connected_topics['topics']:
            if topic['isIntelligenceManagedTopic']:
                topic_list.append(topic['topicName'])
                subscription_list.append(topic['subscriptionName'])
                sink_list.extend(topic['connectedSinks'])
                service_account_list.append(service_account_name)
            else:
                subscription_list.append(topic['subscriptionName'])
                service_account_list.append(service_account_name)

        # current project sending to centralized or from standard onboarding
    else:
        connected_sinks = cloudguard_service.get_connected_sinks_from_intelligence(project_id)
        if connected_sinks['sinks']:
            sink_list.extend(connected_sinks['sinks'])

        # current project onboarded with standard onboarding
        else:
            topic_list.extend([f'projects/{project_id}/topics/cloudguard-topic', f'projects/{project_id}/topics/cloudguard-fl-topic'])
            subscription_list.extend([f'projects/{project_id}/subscriptions/cloudguard-subscription', f'projects/{project_id}/subscriptions/cloudguard-fl-subscription'])
            sink_list.extend([{"sinkName": "cloudguard-sink", "projectId": f"{project_id}"}, {"sinkName": "cloudguard-fl-sink", "projectId": f"{project_id}"}])
            service_account_list.extend(["cloudguard-logs-authentication", "cloudguard-fl-authentication"])

    return topic_list, subscription_list, sink_list, service_account_list
