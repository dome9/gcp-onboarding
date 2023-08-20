import argparse

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
    get_token, validate_region, validate_pubsub_topic, validate_log_type, validate_boolean
)


def parse_arguments():
    parser = argparse.ArgumentParser(description="GCP Existing Centralized Pub/Sub Onboarding Script")
    parser.add_argument("--projects-to-onboard", type=str, help="Projects you want to onboard as a single string separated by spaces", default=[], nargs='+')
    parser.add_argument("--region", type=validate_region,
                        help="The CloudGuard region you use (us/eu1/ap1/ap2/ap3/cace1)")
    parser.add_argument("--pubsub-topic", type=validate_pubsub_topic,
                        help="The GCP Pubsub topic name to connect (for example: 'projects/<projectId>/topics/<topicName>')")
    parser.add_argument("--log-type", type=validate_log_type, help="Onboarding type: NetworkTraffic/AccountActivity")
    parser.add_argument("--enable-auto-discovery", type=validate_boolean, help="Flag to enable auto onboarding")
    parser.add_argument("--api-key", type=str, help="Your CloudGuard API key")
    parser.add_argument("--api-secret", type=str, help="Your CloudGuard API secret key")
    parser.add_argument("--google-credentials-path", type=str, help="The path to your key file")
    return parser.parse_args()


if __name__ == "__main__":

    args = parse_arguments()

    topic_name = args.pubsub_topic
    project_id, topic_id = parse_topic_name(topic_name)
    projects_to_onboard = args.projects_to_onboard
    region = args.region
    log_type = args.log_type
    enable_auto_discovery = args.enable_auto_discovery
    api_key = args.api_key
    api_secret = args.api_secret
    credentials_path = args.google_credentials_path

    try:
        timestamp_hash = md5_hash_from_timestamp(int(time.time()))
        log_filter = getLogFilter(log_type)
        validator_endpoint = get_validator_endpoint(region, log_type)
        service_account_name = "cloudguard-centralized-auth"
        cloudguard_topic_id = f"cloudguard-centralized-{log_type}-topic"
        cloudguard_subscription_id = f"cloudguard-centralized-{log_type}-subscription-{timestamp_hash}"
        cloudguard_sink_name = f"cloudguard-{log_type}-sink-to-{project_id}"
        logic_log_type = 'GcpActivity' if log_type == 'AccountActivity' else 'GcpFlowLogs'

        credentials = service_account.Credentials.from_service_account_file(
            filename=credentials_path
        )

        token = get_token(api_key, api_secret, region)
        connected_topics = get_topics_from_intelligence(token, project_id, region)
        connected_topic = next((t for t in connected_topics['topic'] if t['topicName'] == topic_name), None)
        onboarding_body = {
            "LogType": logic_log_type,
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
            if connected_topic['logType'] != logic_log_type:
                raise Exception(f"Topic {topic_name} already onboarded to different logType, exiting deployment")
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
            # Create service account
            cloudguard_service_account = create_service_account(project_id, service_account_name, credentials)
            # Create the pubsub subscription
            cloudguard_subscription = create_pubsub_subscription(project_id, cloudguard_subscription_id, topic_name,
                                                                 cloudguard_service_account, validator_endpoint,
                                                                 credentials)
            onboarding_body.update({
                "SubscriptionName": cloudguard_subscription,
            })

        # Cloud Guard onboarding API
        cloudguard_onboarding_request(token, onboarding_body, region)
        print(f"Project {project_id} successfully onboarded to CloudGuard")
    except Exception as e:
        print(f"Error occurred in onboarding process, {e}")
