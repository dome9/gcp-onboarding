""" Deploy resources in gcp with deployment manager & onboarding gcp project to intelligence """

import yaml
import functions
from functions import *


def main():
    set_variables(os.environ['LOG_TYPE'])

    # configuration
    resources_json = {
        "resources": [
            {
                "name": functions.service_account_name,
                "properties": {
                    "accountId": functions.service_account_name,
                    "displayName": functions.service_account_name
                },
                "type": "gcp-types/iam-v1:projects.serviceAccounts"
            },
            {
                "name": functions.topic_name,
                "properties": {
                    "topic": functions.topic_name
                },
                "type": "gcp-types/pubsub-v1:projects.topics"
            },
            {
                "name": functions.subscription_name,
                "properties": {
                    "ackDeadlineSeconds": functions.ack_deadline,
                    "expirationPolicy": {},
                    "pushConfig": {
                        "oidcToken": {
                            "audience": functions.audience,
                            "serviceAccountEmail": f"{functions.service_account_name}@{functions.project_id}.iam.gserviceaccount.com"
                        },
                        "pushEndpoint": functions.endpoint
                    },
                    "retryPolicy": {
                        "maximumBackoff": functions.max_retry_delay,
                        "minimumBackoff": functions.min_retry_delay
                    },
                    "subscription": functions.subscription_name,
                    "topic": f"$(ref.{functions.topic_name}.name)"
                },
                "type": "gcp-types/pubsub-v1:projects.subscriptions"
            },
            {
                "name": functions.sink_name,
                "properties": {
                    "destination": f"pubsub.googleapis.com/$(ref.{functions.topic_name}.name)",
                    "filter": functions.sink_filter,
                    "sink": functions.sink_name
                },
                "type": "gcp-types/logging-v2:projects.sinks"
            },
            {
                "accessControl": {
                    "gcpIamPolicy": {
                        "bindings": [
                            {
                                "members": [
                                    f"$(ref.{functions.sink_name}.writerIdentity)"
                                ],
                                "role": "roles/pubsub.publisher"
                            }
                        ]
                    }
                },
                "name": functions.binding_name,
                "properties": {
                    "topic": functions.topic_name
                },
                "type": "pubsub.v1.topic"
            }
        ]
    }
    resources_yaml_format = yaml.dump(resources_json)

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
