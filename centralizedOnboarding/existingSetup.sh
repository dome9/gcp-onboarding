#!/bin/bash

# Define the usage function of this script
usage() {
    echo "Usage: script.sh -e <endpoint> -o <onboarding type> -c <centralized project> -t <pubsub topic name>"
}

# Parse the named arguments
while getopts ":e:o:c:t:s:" opt; do
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
            PUBSUB_TOPIC_NAME=${OPTARG}
            ;;
        s)
            SUBSCRIPTION_NAME=${OPTARG}
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

if [[ $ONBOARDING_TYPE != "AccountActivity" && $ONBOARDING_TYPE != "NetworkTraffic" ]]; then
  echo "invalid onboarding type, EXITING WITHOUT DEPLOYMENT!"
  exit 1

# Don't change those namings because some validation functions using these values to check onboarding status after onboarding finished.
AUDIENCE="dome9-gcp-logs-collector"
SERVICE_ACCOUNT_NAME="cloudguard-$ONBOARDING_TYPE-auth-es"
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

echo""
echo "Start cleaning redundant resources from previous deployment if exist..."
echo ""


# delete existing service account if exists
serviceAccount=$(gcloud iam service-accounts list --filter="name.scope(service account):$SERVICE_ACCOUNT_NAME" 2>&1)
if [[ ! "$serviceAccount" =~ "0 items" ]]; then
  serviceAccount=$(gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME"@"$CENTRALIZED_PROJECT".iam.gserviceaccount.com --quiet)
  if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not delete existing service account "$SERVICE_ACCOUNT_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
  fi
fi


# service account creation
serviceAccount=$(gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME --display-name="$SERVICE_ACCOUNT_NAME" 2>&1)
echo "$serviceAccount"
if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not create service account "$SERVICE_ACCOUNT_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
fi

echo ""
echo "Cleanup completed, starting onboarding process..."
echo ""

# subscription creation
pubsubSubscription=$(gcloud pubsub subscriptions create "$SUBSCRIPTION_NAME" \
                           --topic="$PUBSUB_TOPIC_NAME" \
                           --ack-deadline="$ACK_DEADLINE" \
                           --expiration-period="$EXPIRATION_PERIOD" \
                           --push-endpoint="$ENDPOINT" \
                           --push-auth-service-account="$SERVICE_ACCOUNT_NAME"@"$CENTRALIZED_PROJECT".iam.gserviceaccount.com \
                           --push-auth-token-audience="$AUDIENCE" \
                           --max-retry-delay="$MAX_RETRY_DELAY" \
                           --min-retry-delay="$MIN_RETRY_DELAY")
echo "$pubsubSubscription"
if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
    echo "could not create subscription "$SUBSCRIPTION_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
fi

echo ""
green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Onboarding Completed Successfully.${clear}"