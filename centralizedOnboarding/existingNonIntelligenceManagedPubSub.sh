#!/bin/bash

EchoUsage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --endpoint=<ENDPOINT>              Specify the cloudguard endpoint"
  echo "  --centralized-project=<PROJECT>    Specify the centralized project id"
  echo "  --topic-name=<TOPIC>               Specify the PubSub topic name"
  echo "  --subscription-name=<SUBSCRIPTION> Specify the PubSub subscription name"
}

EchoValidatePermissions(){
  echo ""
  echo "Before proceeding with the deployment, please ensure that the identity running this script has the following roles and permissions attached in the relevant projects:"
  echo ""

  echo "In $1:"
  echo "- Editor"
  echo "- Pub/Sub Admin"
  echo ""

  read -p "Are you ready to proceed? (y/n): " answer

  answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

  if [[ ! "$answer" == "y" ]]; then
    echo "Invalid response, exit deployment."
    exit 1
  fi
}

# Parse the named arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --endpoint=*) ENDPOINT="${1#*=}";;
    --centralized-project=*) CENTRALIZED_PROJECT="${1#*=}";;
    --topic-name=*) TOPIC_NAME="${1#*=}";;
    --subscription-name=*) SUBSCRIPTION_NAME="${1#*=}";;
    *)
      echo "Invalid option: $1"
      EchoUsage
      exit 1
      ;;
  esac
  shift
done

EchoValidatePermissions $CENTRALIZED_PROJECT

if [[ -z "$ENDPOINT" || -z "$CENTRALIZED_PROJECT" || -z "$TOPIC_NAME" || -z "$SUBSCRIPTION_NAME" ]]; then
  echo "Missing one or more required arguments."
  EchoUsage
  exit 1
fi

AUDIENCE="dome9-gcp-logs-collector"
SERVICE_ACCOUNT_NAME="cloudguard-centralized-auth"
MAX_RETRY_DELAY=60
MIN_RETRY_DELAY=10
ACK_DEADLINE=60
EXPIRATION_PERIOD="never"

echo""
echo "setting up default project $CENTRALIZED_PROJECT"
gcloud config set project $CENTRALIZED_PROJECT
echo ""
echo "about to deploy resources related to CloudGuard for $CENTRALIZED_PROJECT project"
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
                             --min-retry-delay="$MIN_RETRY_DELAY")
  echo "$pubsubSubscription"
  if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
    echo "Could not create subscription "$SUBSCRIPTION_NAME", EXITING WITHOUT DEPLOYMENT!"
    exit 1
  fi
fi

echo ""
green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Onboarding Completed Successfully.${clear}"