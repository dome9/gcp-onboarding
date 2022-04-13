from functions import *
import sys


def main():
    """
    Delete previous deployment & delete resources in gcp & offboarding gcp project to intelligence with API

    Arguments:
    project_id_arg - Your GCP project name
    region_arg - The CloudGuard region you use
    api_key_arg - Your CloudGuard API key
    api_secret_arg - Your CloudGuard API secret key
    client_id_arg - Your CloudGuard client ID
    GOOGLE_APPLICATION_CREDENTIALS - Your GCP credentials
    """

    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = sys.argv[6]

    """ Delete flow logs resources from GCP """
    set_variables(project_id_arg=sys.argv[1], region_arg=sys.argv[2], api_key_arg=sys.argv[3],
                  api_secret_arg=sys.argv[4], client_id_arg=sys.argv[5], log_type_arg='flowlogs')
    # Delete previous deployment if exist
    status = delete_deployment()
    if status == Status.deploy_not_exist:
        print('Previous deployment successfully deleted')
    elif status is not None:
        print('Previous deployment failed to delete')
        return
    # delete resources if exists
    delete_resources()

    """ Delete CloudTrail resources from GCP """
    set_variables(project_id_arg=sys.argv[1], region_arg=sys.argv[2], api_key_arg=sys.argv[3],
                  api_secret_arg=sys.argv[4], client_id_arg=sys.argv[5], log_type_arg='CloudTrail')
    # Delete previous deployment if exist
    status = delete_deployment()
    if status == Status.deploy_not_exist:
        print('Previous deployment successfully deleted')
    elif status is not None:
        print('Previous deployment failed to delete')
        return
    # delete resources if exists
    delete_resources()

    # dome9 API
    response = cloudguard_offboarding()
    if response == 'OK':
        print("Project Successfully Offboarded");
    else:
        print("Project failed to Offboard");


if __name__ == '__main__':
    main()
