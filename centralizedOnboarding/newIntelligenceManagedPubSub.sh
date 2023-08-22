#!/bin/bash

EchoUsage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --endpoint=<ENDPOINT>              Specify the cloudguard endpoint"
  echo "  --onboarding-type=<TYPE>           Specify the onboarding type"
  echo "  --centralized-project=<PROJECT>    Specify the centralized project"
  echo "  --topic-name=<TOPIC>               Specify the PubSub topic name"
  echo "  --subscription-name=<SUBSCRIPTION> Specify the PubSub subscription name"
  echo "  --sink-name=<SINK>                 Specify the logging sink name"
  echo "  --projects-to-onboard=<PROJECTS>   Specify the projects to onboard (space-separated, ex: \"projectA projectB ...\")"
}

EchoValidatePermissions(){
  echo""
  echo "Before proceeding with the deployment, please ensure that the identity running this script has the following roles and permissions attached in the relevant projects:"
  echo ""

  echo "In $1:"
  echo "- Editor"
  echo "- Pub/Sub Admin"
  echo "- Logging Admin"
  echo ""

  projectsToOnboard=($2)
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
    --subscription-name=*) SUBSCRIPTION_NAME="${1#*=}";;
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

EchoValidatePermissions $CENTRALIZED_PROJECT $PROJECTS_TO_ONBOARD

if [[ -z "$ENDPOINT" || -z "$ONBOARDING_TYPE" || -z "$CENTRALIZED_PROJECT" || -z "$TOPIC_NAME" || -z "$SUBSCRIPTION_NAME" || -z "$SINK_NAME" || -z "$PROJECTS_TO_ONBOARD" ]]; then
  echo "Missing one or more required arguments."
  EchoUsage
  exit 1
fi

if [[ $ONBOARDING_TYPE == "AccountActivity" ]]; then
    LOG_FILTER='LOG_ID("cloudaudit.googleapis.com/activity") OR LOG_ID("cloudaudit.googleapis.com%2Fdata_access") OR LOG_ID("cloudaudit.googleapis.com%2Fpolicy")'

elif [[ $ONBOARDING_TYPE == "NetworkTraffic" ]]; then
    LOG_FILTER='LOG_ID("compute.googleapis.com%2Fvpc_flows")'
else
  echo "Invalid onboarding type $ONBOARDING_TYPE, EXITING WITHOUT DEPLOYMENT!"
  exit 1
fi

SERVICE_ACCOUNT_NAME="cloudguard-centralized-auth"
AUDIENCE="dome9-gcp-logs-collector"
MAX_RETRY_DELAY=60
MIN_RETRY_DELAY=10
ACK_DEADLINE=60
EXPIRATION_PERIOD="never"

echo""
echo "Setting up default project $CENTRALIZED_PROJECT"
gcloud config set project $CENTRALIZED_PROJECT
echo""
echo "About to deploy resources related to CloudGuard for $CENTRALIZED_PROJECT $PROJECTS_TO_ONBOARD projects"
echo ""

# service account creation
if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME"@"$CENTRALIZED_PROJECT".iam.gserviceaccount.com &> /dev/null; then
  serviceAccount=$(gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME --display-name="$SERVICE_ACCOUNT_NAME" 2>&1)
  echo "$serviceAccount"
  if [[ "$serviceAccount" =~ "ERROR" ]]; then
      echo "Could not create service account "$SERVICE_ACCOUNT_NAME", EXITING WITHOUT DEPLOYMENT!"
      exit 1
  fi
fi

# topic creation
if ! gcloud pubsub topics describe "$TOPIC_NAME" &>/dev/null; then
  topic=$(gcloud pubsub topics create "$TOPIC_NAME" 2>&1)
  echo "$topic"
  if [[ "$topic" =~ "ERROR" ]]; then
      echo "Could not create topic "$TOPIC_NAME", EXITING WITHOUT DEPLOYMENT!"
      exit 1
  fi
fi

# subscription creation
if ! gcloud pubsub subscriptions describe "$SUBSCRIPTION_NAME" &>/dev/null; then
  pubsubSubscription=$(gcloud pubsub subscriptions create "$SUBSCRIPTION_NAME" \
                               --topic="$TOPIC_NAME" \
                               --ack-deadline="$ACK_DEADLINE" \
                               --expiration-period="$EXPIRATION_PERIOD" \
                               --push-endpoint="$ENDPOINT" \
                               --push-auth-service-account="$SERVICE_ACCOUNT_NAME"@"$CENTRALIZED_PROJECT".iam.gserviceaccount.com \
                               --push-auth-token-audience="$AUDIENCE" \
                               --max-retry-delay="$MAX_RETRY_DELAY" \
                               --min-retry-delay="$MIN_RETRY_DELAY" 2>&1)
  echo "$pubsubSubscription"
  if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
    echo "Could not create subscription "$SUBSCRIPTION_NAME", EXITING WITHOUT DEPLOYMENT!"
    exit 1
  fi
fi

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