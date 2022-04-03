""" Delete previous deployment & delete resources in gcp & offboarding gcp project to intelligence """

from functions import *


def main():
    print("Delete flow logs")
    set_variables('flowlogs')
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
    set_variables('CloudTrail')
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
