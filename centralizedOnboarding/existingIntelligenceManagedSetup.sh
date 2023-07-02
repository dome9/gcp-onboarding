#!/bin/bash

# Define the usage function of this script
usage() {
    echo "Usage: existingIntelligenceManagedSetup.sh -e <endpoint> -o <onboarding type> -c <centralized project> -t <topic name> -p <list of projects to onboard>"
}

# Parse the named arguments
while getopts ":e:o:c:t:p:" opt; do
    case ${opt} in
        r)
            ENDPOINT=${OPTARG}
            ;;
        o)
            ONBOARDING_TYPE=${OPTARG}
            ;;
        c)
            CENTRALIZED_PROJECT=${OPTARG}
            ;;
        t)
            TOPIC_NAME=${OPTARG}
            ;;
        p)
            PROJECTS=${OPTARG}
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            usage
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument."
            usage
            exit 1
            ;;
    esac
done

if [[ $ONBOARDING_TYPE == "AccountActivity" ]]; then
    LOG_FILTER='LOG_ID("cloudaudit.googleapis.com/activity") OR LOG_ID("cloudaudit.googleapis.com%2Fdata_access") OR LOG_ID("cloudaudit.googleapis.com%2Fpolicy")'

elif [[ $ONBOARDING_TYPE == "NetworkTraffic" ]]; then
    LOG_FILTER='LOG_ID("compute.googleapis.com%2Fvpc_flows")'
else
  echo "invalid onboarding type, EXITING WITHOUT DEPLOYMENT!"
  exit 1
fi

MAX_RETRY_DELAY=60
MIN_RETRY_DELAY=10
ACK_DEADLINE=60
EXPIRATION_PERIOD="never"

echo""
echo "setting up default project $CENTRALIZED_PROJECT"
gcloud config set project $CENTRALIZED_PROJECT
echo "Enabling Deployment Manager APIs, which you will need for this deployment."
gcloud services enable deploymentmanager.googleapis.com

echo ""

# Split the list argument of projects into an array
IFS=' ' read -ra PROJECTS_TO_ONBOARD <<< "$PROJECTS"

# sink creation in each onboarded project
for PROJECT_ID in "${PROJECTS_TO_ONBOARD[@]}"
do
	sink=$(gcloud logging sinks create "$SINK_NAME" pubsub.googleapis.com/projects/"$CENTRALIZED_PROJECT"/topics/"$TOPIC_NAME" \
            --project="$PROJECT_ID" --log-filter="$LOG_FILTER" 2>&1)

	# granting write permissions to sink
	writerIdentity=$(gcloud logging sinks describe "$SINK_NAME" --project "$PROJECT_ID" --format="value(writerIdentity)")
  gcloud pubsub topics add-iam-policy-binding "$TOPIC_NAME" --member="$writerIdentity" --role="roles/pubsub.publisher"
	echo "$sink"
	if [[ "$sink" =~ "ERROR" ]]; then
		echo "could not create sink "$SINK_NAME" in project "$PROJECT_ID", EXITING WITHOUT DEPLOYMENT!"
		exit 1
	fi
done

echo ""
green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Onboarding Completed Successfully.${clear}"