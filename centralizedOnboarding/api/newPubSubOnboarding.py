import argparse
import time

from centralizedOnboarding.api.services.clouguard_service import CloudGuardService
from centralizedOnboarding.api.services.google_cloud_service import GoogleCloudService
from utils import (
    md5_hash_from_timestamp,
    get_log_filter,
    get_validator_endpoint,
    validate_region, validate_log_type, validate_boolean
)


def parse_arguments():
    parser = argparse.ArgumentParser(description="GCP New Centralized Pub/Sub Onboarding Script")
    parser.add_argument("--project-id", type=str, help="Your GCP centralized project id")
    parser.add_argument("--projects-to-onboard", type=str,
                        help="Projects you want to onboard as a single string separated by spaces", default=[],
                        nargs='+')
    parser.add_argument("--region", type=validate_region,
                        help="The CloudGuard region you use (us/eu1/ap1/ap2/ap3/cace1)")
    parser.add_argument("--log-type", type=validate_log_type, help="Onboarding type: NetworkTraffic/AccountActivity")
    parser.add_argument("--enable-auto-discovery", type=validate_boolean, help="Flag to enable auto onboarding",
                        default=False)
    parser.add_argument("--api-key", type=str, help="Your CloudGuard API key")
    parser.add_argument("--api-secret", type=str, help="Your CloudGuard API secret key")
    parser.add_argument("--google-credentials-path", type=str, help="The path to your key file")
    return parser.parse_args()


if __name__ == "__main__":

    args = parse_arguments()

    project_id = args.project_id
    projects_to_onboard = args.projects_to_onboard
    region = args.region
    enable_auto_discovery = args.enable_auto_discovery
    api_key = args.api_key
    api_secret = args.api_secret
    log_type = args.log_type
    credentials_path = args.google_credentials_path
    try:
        timestamp_hash = md5_hash_from_timestamp(int(time.time()))
        log_filter = get_log_filter(log_type)
        validator_endpoint = get_validator_endpoint(region, log_type)
        service_account_name = "cloudguard-centralized-auth"
        topic_id = f"cloudguard-centralized-{log_type}-topic"
        subscription_id = f"cloudguard-centralized-{log_type}-subscription-{timestamp_hash}"
        sink_name = f"cloudguard-{log_type}-sink-to-{project_id}"
        logic_log_type = 'GcpActivity' if log_type == 'AccountActivity' else 'GcpFlowLogs'

        # Deploy resources in GCP
        cloudguard_service = CloudGuardService(api_key, api_secret, region)
        google_cloud_service = GoogleCloudService(credentials_path)
    # Create service account
        cloudguard_service_account = google_cloud_service.create_service_account(project_id, service_account_name)
        # Create pubsub topic
        cloudguard_topic = google_cloud_service.create_pubsub_topic(project_id, topic_id)
        # Create the pubsub subscription
        cloudguard_subscription = google_cloud_service.create_pubsub_subscription(project_id, subscription_id, cloudguard_topic,
                                                             cloudguard_service_account, validator_endpoint)
        # Create the logging sinks for each project to onboard
        cloudguard_sinks = [google_cloud_service.create_logging_sink(sink_project_id, sink_name, cloudguard_topic, log_filter)
                            for sink_project_id in projects_to_onboard + [project_id]]

        # Cloud Guard onboarding API
        body = {
            "LogType": logic_log_type,
            "CentralizedProject": project_id,
            "ProjectsToOnboard": projects_to_onboard + [project_id],
            "TopicName": cloudguard_topic,
            "SubscriptionName": cloudguard_subscription,
            "ConnectedSinks": [sink for sink in cloudguard_sinks if sink is not None],
            "IsAutoDiscoveryEnabled": enable_auto_discovery,
            "IsIntelligenceManagedTopic": True
        }
        cloudguard_service.cloudguard_onboarding_request(body)
        print(f"Project {project_id} successfully onboarded to CloudGuard")
    except Exception as e:
        print(f"Error occurred in onboarding process, Error: {e}")
