import argparse

from google.oauth2 import service_account
from utils import (
    delete_service_account,
    get_topics_from_intelligence,
    get_token, validate_region, delete_pubsub_topics, delete_pubsub_subscriptions, delete_logging_sinks,
    get_connected_sinks_from_intelligence, cloudguard_offboarding_request
)


def parse_arguments():
    parser = argparse.ArgumentParser(description="GCP Offboarding Script")
    parser.add_argument("--project-id", type=str, help="Your GCP centralized project id that you want to offboard")
    parser.add_argument("--region", type=validate_region,
                        help="The CloudGuard region you use (us/eu1/ap1/ap2/ap3/cace1)")
    parser.add_argument("--api-key", type=str, help="Your CloudGuard API key")
    parser.add_argument("--api-secret", type=str, help="Your CloudGuard API secret key")
    parser.add_argument("--google-credentials-path", type=str, help="The path to your key file")
    return parser.parse_args()


if __name__ == "__main__":

    args = parse_arguments()

    project_id = args.project_id
    region = args.region
    api_key = args.api_key
    api_secret = args.api_secret
    credentials_path = args.google_credentials_path

    try:
        service_account_name = "cloudguard-centralized-auth"
        credentials = service_account.Credentials.from_service_account_file(
            filename=credentials_path
        )

        token = get_token(api_key, api_secret, region)
        connected_topics = get_topics_from_intelligence(token, project_id, region)
        topic_list = []
        subscription_list = []
        sink_list = []
        service_account_list = []

        # current project is centralized
        if connected_topics['topics']:
            for topic in connected_topics:
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
            connected_sinks = get_connected_sinks_from_intelligence(token, project_id, region)
            if connected_sinks['sinks']:
                sink_list.extend(connected_sinks['sinks'])

            # current project onboarded with standard onboarding
            else:
                topic_list.extend([f'projects/{project_id}/topics/cloudguard-topic', f'projects/{project_id}/topics/cloudguard-fl-topic'])
                subscription_list.extend([f'projects/{project_id}/subscriptions/cloudguard-subscription', f'projects/{project_id}/subscriptions/cloudguard-fl-subscription'])
                sink_list.extend([{"sinkName": "cloudguard-sink", "projectId": f"{project_id}"}, {"sinkName": "cloudguard-fl-sink", "projectId": f"{project_id}"}])
                service_account_list.extend(["cloudguard-logs-authentication", "cloudguard-fl-authentication"])

        delete_service_account(project_id, service_account_list, credentials)
        delete_pubsub_topics(topic_list, credentials)
        delete_pubsub_subscriptions(subscription_list, credentials)
        delete_logging_sinks(sink_list, credentials)

        # Cloud Guard offboarding API
        cloudguard_offboarding_request(project_id, token, region)
        print(f"Project {project_id} successfully offboarded from CloudGuard")
    except Exception as e:
        print(f"Error occurred in onboarding process, Error: {e}")
