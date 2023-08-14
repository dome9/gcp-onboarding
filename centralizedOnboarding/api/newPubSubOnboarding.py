import argparse
from google.oauth2 import service_account
import time
from utils import (
    md5_hash_from_timestamp,
    getLogFilter,
    get_validator_endpoint,
    create_service_account,
    create_pubsub_topic,
    create_pubsub_subscription,
    create_logging_sink,
    cloudguard_onboarding_request, get_token
)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="GCP Centralized Project Onboarding Script")
    parser.add_argument("--project-id", type=str, help="Your GCP centralized project id")
    parser.add_argument("--projects-to-onboard", type=str, help="Projects you want to onboard", default=[], nargs='+')
    parser.add_argument("--region", type=str, help="The CloudGuard region you use (us/eu1/ap1/ap2/ap3/cace1)")
    parser.add_argument("--log-type", type=str, help="Onboarding type: NetworkTraffic/AccountActivity")
    parser.add_argument("--enable-auto-discovery", type=str, help="Flag to enable auto onboarding", default=False)
    parser.add_argument("--api-key", type=str, help="Your CloudGuard API key")
    parser.add_argument("--api-secret", type=str, help="Your CloudGuard API secret key")
    parser.add_argument("--client-id", type=str, help="Your CloudGuard client ID")
    parser.add_argument("--google-credentials-path", type=str, help="The path to your key file")

    args = parser.parse_args()

    project_id = args.project_id
    projects_to_onboard = args.projects_to_onboard
    region = args.region
    enable_auto_discovery = args.enable_auto_discovery
    api_key = args.api_key
    api_secret = args.api_secret
    client_id = args.client_id
    log_type = args.log_type
    credentials_path = args.google_credentials_path
    timestamp_hash = md5_hash_from_timestamp(int(time.time()))
    log_filter = getLogFilter(log_type)
    validator_endpoint = get_validator_endpoint(region, log_type)
    service_account_name = "cloudguard-centralized-auth"
    topic_id = f"cloudguard-centralized-{log_type}-topic"
    subscription_id = f"cloudguard-centralized-{log_type}-subscription-{timestamp_hash}"
    sink_name = f"cloudguard-{log_type}-sink-to-{project_id}"

    # Deploy resources in GCP
    credentials = service_account.Credentials.from_service_account_file(
        filename=credentials_path
    )
    # Create service account
    cloudguard_service_account = create_service_account(project_id, service_account_name, credentials)
    # Create pubsub topic
    cloudguard_topic = create_pubsub_topic(project_id, topic_id, credentials)
    # Create the pubsub subscription
    cloudguard_subscription = create_pubsub_subscription(project_id, subscription_id, cloudguard_topic,
                                                               cloudguard_service_account, validator_endpoint,
                                                               credentials)
    # Create the logging sinks for each project to onboard
    cloudguard_sinks = [create_logging_sink(sink_project_id, sink_name, cloudguard_topic, log_filter, credentials)
                        for sink_project_id in projects_to_onboard + [project_id]]

    # Cloud Guard onboarding API
    body = {
        "LogType": log_type,
        "CentralizedProject": project_id,
        "ProjectsToOnboard": projects_to_onboard + [project_id],
        "TopicName": cloudguard_topic,
        "SubscriptionName": cloudguard_subscription,
        "ConnectedSinks": [sink for sink in cloudguard_sinks if sink is not None],
        "IsAutoDiscoveryEnabled": enable_auto_discovery,
        "IsIntelligenceManagedTopic": True
    }
    token = get_token(api_key, api_secret, region)
    response = cloudguard_onboarding_request(token, body, region)
    if response == 'OK':
        print("Project successfully onboarded to CloudGuard")
    else:
        print("Project failed to onboard to CloudGuard")
