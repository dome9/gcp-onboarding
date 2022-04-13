from functions import *
import sys


def main():
    """
    Deploy resources in GCP with deployment manager & onboarding GCP project to intelligence with API

    Arguments:
    project_id_arg - Your GCP project name
    region_arg - The CloudGuard region you use
    api_key_arg - The CloudGuard API key
    api_secret_arg - The CloudGuard API secret key
    client_id_arg - The CloudGuard client ID
    log_type_arg - flowlogs/CloudTrail
    """

    set_variables(project_id_arg=sys.argv[1], region_arg=sys.argv[2], api_key_arg=sys.argv[3],
                  api_secret_arg=sys.argv[4], client_id_arg=sys.argv[5], log_type_arg=sys.argv[6])
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = sys.argv[7]

    # configuration
    resources_yaml_format = get_resources_yaml()

    # Delete previous deployment if exist
    status = delete_deployment()
    if status == Status.deploy_not_exist:
        print('Delete Previous deployment')
    elif status is not None:
        print('Delete Previous deployment failed')
        return

    # delete resources if already exist
    delete_resources()

    # deploy resources in GCP
    status = create_resources(resources_yaml_format)
    if status == Status.deploy_exist:
        print("Deployment success")
    else:
        return

    # Cloud Guard onboarding API
    response = cloudguard_onboarding()
    if response == 'OK':
        print("Project Successfully Onboarded");
    else:
        print("Project failed  to Onboard");


if __name__ == '__main__':
    main()
