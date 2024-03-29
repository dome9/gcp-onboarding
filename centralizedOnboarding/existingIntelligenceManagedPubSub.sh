#!/bin/bash

EchoUsage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --endpoint=<ENDPOINT>             Specify the cloudguard endpoint"
  echo "  --onboarding-type=<TYPE>          Specify the onboarding type"
  echo "  --centralized-project=<PROJECT>   Specify the centralized project id"
  echo "  --topic-name=<TOPIC>              Specify the PubSub topic name"
  echo "  --sink-name=<SINK>                Specify the logging sink name"
  echo "  --projects-to-onboard=<PROJECTS>  Specify the projects to onboard (space-separated, ex: \"projectA projectB ...\")"
}

EchoValidatePermissions(){
  echo ""
  echo "Before proceeding with the deployment, please ensure that the identity running this script has the following roles and permissions attached in the relevant projects:"
  echo ""

  projectsToOnboard=($PROJECTS_TO_ONBOARD)
  echo "In ${projectsToOnboard[*]}:"
  echo "- Logging Admin"
  echo ""

  read -p "Are you ready to proceed? (y/n): " answer

  answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

  if [[ $answer == "n" ]]; then
      echo "You choose to not proceed, exit deployment"
      exit 1
  elif [[ ! "$answer" == "y" ]]; then
    echo "Invalid response, exit deployment."
    exit 1
  fi
}

# Parse the named arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --endpoint=*) ENDPOINT="${1#*=}";;
    --onboarding-type=*) ONBOARDING_TYPE="${1#*=}";;
    --centralized-project=*) CENTRALIZED_PROJECT="${1#*=}";;
    --topic-name=*) TOPIC_NAME="${1#*=}";;
    --sink-name=*) SINK_NAME="${1#*=}";;
    --projects-to-onboard=*) PROJECTS_TO_ONBOARD="${1#*=}";;
    *)
      echo "Invalid option: $1"
      EchoUsage
      exit 1
      ;;
  esac
  shift
done

EchoValidatePermissions $PROJECTS_TO_ONBOARD

if [[ -z "$ENDPOINT" || -z "$ONBOARDING_TYPE" || -z "$CENTRALIZED_PROJECT" || -z "$TOPIC_NAME" || -z "$SINK_NAME" || -z "$PROJECTS_TO_ONBOARD" ]]; then
  echo "Missing one or more required arguments."
  EchoUsage
  exit 1
fi

if [[ $ONBOARDING_TYPE == "AccountActivity" ]]; then
    LOG_FILTER='LOG_ID("cloudaudit.googleapis.com/activity") OR LOG_ID("cloudaudit.googleapis.com%2Fdata_access") OR LOG_ID("cloudaudit.googleapis.com%2Fpolicy")'

elif [[ $ONBOARDING_TYPE == "NetworkTraffic" ]]; then
    LOG_FILTER='LOG_ID("compute.googleapis.com%2Fvpc_flows")'
else
  echo "invalid onboarding type $ONBOARDING_TYPE, EXITING WITHOUT DEPLOYMENT!"
  exit 1
fi

MAX_RETRY_DELAY=60
MIN_RETRY_DELAY=10
ACK_DEADLINE=60
EXPIRATION_PERIOD="never"

echo""
echo "Setting up default project $CENTRALIZED_PROJECT"
gcloud config set project $CENTRALIZED_PROJECT
echo ""
echo "About to deploy resources related to CloudGuard for $PROJECTS_TO_ONBOARD projects"
echo ""

# sink creation in each onboarded project
for PROJECT_ID in $PROJECTS_TO_ONBOARD
do
  if ! gcloud logging sinks describe "$SINK_NAME" --project="$PROJECT_ID" &>/dev/null; then
    sink=$(gcloud logging sinks create "$SINK_NAME" pubsub.googleapis.com/projects/"$CENTRALIZED_PROJECT"/topics/"$TOPIC_NAME" \
              --project="$PROJECT_ID" --log-filter="$LOG_FILTER" 2>&1)
    echo "$sink"
    if [[ "$sink" =~ "ERROR" ]]; then
      echo "Could not create sink "$SINK_NAME" in project "$PROJECT_ID", EXITING WITHOUT DEPLOYMENT!"
      exit 1
    fi
    # granting write permissions to sink
    writerIdentity=$(gcloud logging sinks describe "$SINK_NAME" --project "$PROJECT_ID" --format="value(writerIdentity)")
    gcloud pubsub topics add-iam-policy-binding "$TOPIC_NAME" --member="$writerIdentity" --role="roles/pubsub.publisher"
  fi
done

echo ""
green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Onboarding Completed Successfully.${clear}"