import argparse
from services.clouguard_service import CloudGuardService
from services.google_cloud_service import GoogleCloudService
from utils import validate_region, create_resource_lists_to_delete


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

        cloudguard_service = CloudGuardService(api_key, api_secret, region)
        google_cloud_service = GoogleCloudService(credentials_path)
        topic_list, subscription_list, sink_list, service_account_list = create_resource_lists_to_delete(
            google_cloud_service, cloudguard_service, project_id)

        user_confirmation = input(
            "Do you want to delete CloudGuard related resources that created during the onboarding of this project? (yes/no): ")

        if user_confirmation.lower() == "yes":
            google_cloud_service.delete_cloudguard_resources(project_id, service_account_list, topic_list,
                                                             subscription_list, sink_list)
            print("CloudGuard resources have been deleted.")
        elif user_confirmation.lower() == "no":
            print("CloudGuard resources will not be deleted, you can delete them manually")
        else:
            print("Invalid input. Please enter 'yes' or 'no'.")

        # Cloud Guard offboarding API
        cloudguard_service.cloudguard_offboarding_request(project_id)
        print(f"Project {project_id} successfully offboarded from CloudGuard")
    except Exception as e:
        print(f"Error occurred in onboarding process, Error: {e}")
