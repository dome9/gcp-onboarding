""" Delete previous deployment & delete resources in gcp & offboarding gcp project to intelligence """

from functions import *
import sys


def main():
    print("Delete flow logs")
    set_variables(project_id_arg=sys.argv[1], region_arg=sys.argv[2], api_key_arg=sys.argv[3],
                  api_secret_arg=sys.argv[4], client_id_arg=sys.argv[5], log_type_arg='flowlogs')
    # Delete previous deployment if exist
    status = delete_deployment()
    if status == Status.deploy_not_exist:
        print('Delete Previous deployment')
    elif status is not None:
        print('Delete Previous deployment failed')
        return
    # delete resources if exists
    delete_resources()

    print("Delete CloudTrail")
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
    delete_resources()

    # dome9 API
    """response = cloudguard_offboarding()
    if response == 'OK':
        print("Project Successfully Offboarded");
    else:
        print("Project failed to Offboarded");"""


if __name__ == '__main__':
    main()
