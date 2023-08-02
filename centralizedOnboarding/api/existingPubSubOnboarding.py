import argparse
import json
import requests
from google.oauth2 import service_account
import utils

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="GCP Centralized Project Onboarding Script")
    parser.add_argument("--projects-to-onboard", type=str, help="Projects you want to onboard", default=[], nargs='+')
    parser.add_argument("--region", type=str, help="The CloudGuard region you use (us/eu1/ap1/ap2/ap3/cace1)")
    parser.add_argument("--pubsub-topic", type=str, help="The GCP Pubsub topic name to connect")
    parser.add_argument("--log-type", type=str, help="NetworkTraffic/AccountActivity")
    parser.add_argument("--enable-auto-discovery", type=bool, help="Flag to enable auto onboarding")
    parser.add_argument("--api-key", type=str, help="Your CloudGuard API key")
    parser.add_argument("--api-secret", type=str, help="Your CloudGuard API secret key")
    parser.add_argument("--client-id", type=str, help="Your CloudGuard client ID")
    parser.add_argument("--google-credentials-path", type=str, help="The path to your key file")

    args = parser.parse_args()

    topic_name = args.pubsub_topic
    project_id, topic_id = utils.parse_topic_name(topic_name)
    projects_to_onboard = args.projects_to_onboard
    region = args.region
    log_type = args.log_type
    enable_auto_discovery = args.enable_auto_discovery
    api_key = args.api_key
    api_secret = args.api_secret
    client_id = args.client_id
    credentials_path = args.google_credentials_path
    service_account_name = "cloudguard-centralized-auth"
    cloudguard_topic_id = f"cloudguard-centralized-{log_type}-topic"
    cloudguard_subscription_id = f"cloudguard-centralized-{log_type}-subscription"
    cloudguard_sink_name = f"cloudguard-{log_type}-sink-to-{project_id}"
    log_filter = utils.getLogFilter(log_type)

    credentials = service_account.Credentials.from_service_account_file(
        filename=credentials_path
    )

    gcp_pubsub_topic = utils.get_pubsub_topic(topic_name, credentials)
    # Intelligence managed topic
    if topic_id == cloudguard_topic_id:
        cloudguard_sinks = []
    for sink_project_id in projects_to_onboard:
        sink = utils.create_logging_sink(sink_project_id, cloudguard_sink_name, topic_name, log_filter, credentials)
        cloudguard_sinks.append(sink)
    headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*'
    }
    data = {
        "LogType": log_type,
        "CentralProject": project_id,
        "ProjectsToOnboard": projects_to_onboard.add(project_id),
        "TopicName": topic_name,
        "SubscriptionName": cloudguard_subscription_id,
        "ConnectedSinks": list(filter(lambda obj: obj is not None, cloudguard_sinks)),
        "IsAutoDiscoveryEnabled": False,
        "IsIntelligenceManagedTopic": True
    }
    response = utils.cloudguard_onboarding(api_key, api_secret, data, headers, region)
    if response == 'OK':
        print("Project successfully onboarded to CloudGuard")
    else:
        print("Project failed to onboard to CloudGuard")


