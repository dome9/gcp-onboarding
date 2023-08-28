import hashlib
import re
import argparse

CENTRALIZED_SERVICE_ACCOUNT_NAME = "cloudguard-centralized-auth"
sink_mappings = {
    'cloudguard-fl-sink': {
        'topic_name': 'projects/{}/topics/cloudguard-fl-topic',
        'subscription_name': 'projects/{}/subscriptions/cloudguard-fl-subscription',
        'sink_info': {"sinkName": "cloudguard-fl-sink", "projectId": None},
        'service_account_name': "cloudguard-fl-authentication"
    },
    'cloudguard-sink': {
        'topic_name': 'projects/{}/topics/cloudguard-topic',
        'subscription_name': 'projects/{}/subscriptions/cloudguard-subscription',
        'sink_info': {"sinkName": "cloudguard-sink", "projectId": None},
        'service_account_name': "cloudguard-logs-authentication"
    }
}


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


def create_resource_lists_to_delete(google_cloud_service, cloudguard_service, project_id):
    topic_list = []
    subscription_list = []
    sink_list = []
    service_account_list = []

    connected_topics = cloudguard_service.get_connected_topics_from_intelligence(project_id)
    connected_sinks = cloudguard_service.get_connected_sinks_from_intelligence(project_id)
    sinks_from_gcp = google_cloud_service.list_logging_sinks(project_id)

    # current project is centralized
    for topic in connected_topics.get('topics', []):
        if topic['isIntelligenceManagedTopic']:
            topic_list.append(topic['topicName'])
            subscription_list.append(topic['subscriptionName'])
            sink_list.extend(topic['connectedSinks'])
        else:
            subscription_list.append(topic['subscriptionName'])
        service_account_list.append(CENTRALIZED_SERVICE_ACCOUNT_NAME)

    # current project sending to centralized and has intelligence managed sink
    if not connected_topics['topics']:
        for sink in connected_sinks.get('sinks', []):
            sink_list.append(sink)

    # current project is from standard onboarding or not has intelligence managed sink
    if not connected_topics['topics'] and not connected_sinks['sinks']:
        for sink in sinks_from_gcp:
            for sink_name, mapping in sink_mappings.items():

                # from standard onboarding, delete resources related to standard onboarding
                if sink_name in sink.name:
                    mapping['sink_info']['projectId'] = project_id
                    topic_list.append(mapping['topic_name'].format(project_id))
                    subscription_list.append(mapping['subscription_name'].format(project_id))
                    sink_list.append(mapping['sink_info'])
                    service_account_list.append(mapping['service_account_name'])
                    break

    return topic_list, subscription_list, sink_list, service_account_list
