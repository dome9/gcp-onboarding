import argparse
import json

from google.oauth2 import service_account
import time
from utils import (
    md5_hash_from_timestamp,
    getLogFilter,
    get_validator_endpoint,
    create_service_account,
    create_pubsub_subscription,
    create_logging_sink,
    cloudguard_onboarding_request,
    parse_topic_name,
    get_topics_from_intelligence,
    get_token
)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="GCP Centralized Project Onboarding Script")
    parser.add_argument("--projects-to-onboard", type=str, help="Projects you want to onboard", default=[], nargs='+')
    parser.add_argument("--region", type=str, help="The CloudGuard region you use (us/eu1/ap1/ap2/ap3/cace1)")
    parser.add_argument("--pubsub-topic", type=str, help="The GCP Pubsub topic name to connect (for example: 'projects/<projectId>/topics/<topicName>')")
    parser.add_argument("--log-type", type=str, help="Onboarding type: NetworkTraffic/AccountActivity")
    parser.add_argument("--enable-auto-discovery", type=bool, help="Flag to enable auto onboarding")
    parser.add_argument("--api-key", type=str, help="Your CloudGuard API key")
    parser.add_argument("--api-secret", type=str, help="Your CloudGuard API secret key")
    parser.add_argument("--client-id", type=str, help="Your CloudGuard client ID")
    parser.add_argument("--google-credentials-path", type=str, help="The path to your key file")

    args = parser.parse_args()

    topic_name = args.pubsub_topic
    project_id, topic_id = parse_topic_name(topic_name)
    projects_to_onboard = args.projects_to_onboard
    region = args.region
    log_type = args.log_type
    enable_auto_discovery = args.enable_auto_discovery
    api_key = args.api_key
    api_secret = args.api_secret
    client_id = args.client_id
    credentials_path = args.google_credentials_path
    timestamp_hash = md5_hash_from_timestamp(int(time.time()))
    log_filter = getLogFilter(log_type)
    validator_endpoint = get_validator_endpoint(region, log_type)
    service_account_name = "cloudguard-centralized-auth"
    cloudguard_topic_id = f"cloudguard-centralized-{log_type}-topic"
    cloudguard_subscription_id = f"cloudguard-centralized-{log_type}-subscription-{timestamp_hash}"
    cloudguard_sink_name = f"cloudguard-{log_type}-sink-to-{project_id}"

    credentials = service_account.Credentials.from_service_account_file(
        filename=credentials_path
    )

    topics_body = {
        "projectId": project_id,
        "logType": "GcpActivity" if log_type == "AccountActivity" else "GcpFlowLogs"
    }
    token = get_token(api_key, api_secret, region)
    connected_topics = get_topics_from_intelligence(token, topics_body, region)
    connected_topic = next((t for t in connected_topics if t['topicName'] == topic_name), None)
    onboarding_body = {
        "LogType": log_type,
        "CentralizedProject": project_id,
        "ProjectsToOnboard": projects_to_onboard + [project_id],
        "TopicName": topic_name,
        "SubscriptionName": "",
        "ConnectedSinks": [],
        "IsAutoDiscoveryEnabled": enable_auto_discovery,
        "IsIntelligenceManagedTopic": False
    }
    # already connected topic to intelligence
    if connected_topic:
        # if topic intelligenceManaged create sinks in onboarded projects
        if connected_topic['isIntelligenceManagedTopic']:
            cloudguard_sinks = [
                create_logging_sink(sink_project_id, cloudguard_sink_name, topic_name, log_filter, credentials)
                for sink_project_id in projects_to_onboard + [project_id]
            ]
            onboarding_body.update({
                "ConnectedSinks": [sink for sink in cloudguard_sinks if sink is not None],
            })
        onboarding_body.update({
            "SubscriptionName": connected_topic['subscriptionName'],
            "IsIntelligenceManagedTopic": connected_topic['isIntelligenceManagedTopic'],
            "IsAutoDiscoveryEnabled": connected_topic['isAutoDiscoveryEnabled']
        })

    # new user's not connected topic,
    else:
        cloudguard_service_account = create_service_account(project_id, service_account_name, credentials)
        cloudguard_subscription = create_pubsub_subscription(project_id, cloudguard_subscription_id, topic_name,
                                                             cloudguard_service_account, validator_endpoint,
                                                             credentials)
        onboarding_body.update({
            "SubscriptionName": cloudguard_subscription,
        })
    response = cloudguard_onboarding_request(token, onboarding_body, region)
    if response == 'OK':
        print("Project successfully onboarded to CloudGuard")
    else:
        print("Project failed to onboard to CloudGuard")
    pass
