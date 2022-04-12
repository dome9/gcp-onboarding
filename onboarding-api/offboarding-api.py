from functions import *
import sys


def main():
    """
    Delete previous deployment & delete resources in gcp & offboarding gcp project to intelligence

    Arguments:
    project_id_arg - Your GCP project
    region_arg - The CloudGuard region you use
    api_key_arg - The
    api_secret_arg - The
    client_id_arg - The CloudGuard client ID
    log_type_arg - flowlogs/CloudTrail
    """

    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = sys.argv[6]

    print("Delete flow logs resources from GCP")
    set_variables(project_id_arg=sys.argv[1], region_arg=sys.argv[2], api_key_arg=sys.argv[3],
                  api_secret_arg=sys.argv[4], client_id_arg=sys.argv[5], log_type_arg='flowlogs')


    # Delete previous deployment if exist
    """status = delete_deployment()
    if status == Status.deploy_not_exist:
        print('Delete Previous deployment')
    elif status is not None:
        print('Delete Previous deployment failed')
        return
    # delete resources if exists
    delete_resources()

    print("Delete CloudTrail resources from GCP")
    set_variables(project_id_arg=sys.argv[1], region_arg=sys.argv[2], api_key_arg=sys.argv[3],
                  api_secret_arg=sys.argv[4], client_id_arg=sys.argv[5], log_type_arg='CloudTrail')
    # Delete previous deployment if exist
    status = delete_deployment()
    if status == Status.deploy_not_exist:
        print('Delete Previous deployment')
    elif status is not None:
        print('Delete Previous deployment failed')
        return
    # delete resources if exists
    delete_resources()"""

    # dome9 API
    response = cloudguard_offboarding()
    if response == 'OK':
        print("Project Successfully Offboarded");
    else:
        print("Project failed to Offboarded");


if __name__ == '__main__':
    main()
