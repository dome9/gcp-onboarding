#!/bin/bash

# Function to display usage information
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --project-id=<PROJECT>          Specify the project to offboard"
  echo "  --topics=<TOPICS>               Specify the PubSub topics to delete"
  echo "  --subscriptions=<SUBSCRIPTIONS> Specify the PubSub subscriptions to delete"
  echo "  --connected-sinks=<SINKS>       Specify the logging sink names to delete"
}

SINKS_PROVIDED=false
TOPICS_PROVIDED=false
SUBSCRIPTIONS_PROVIDED=false

# Parse the named arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --project-id=*)
      PROJECT="${1#*=}";;
    --topics=*)
      TOPICS="${1#*=}"
      TOPICS_PROVIDED=true;;
    --subscriptions=*)
      SUBSCRIPTIONS="${1#*=}"
      SUBSCRIPTIONS_PROVIDED=true;;
    --connected-sinks=*)
      SINKS="${1#*=}"
      SINKS_PROVIDED=true;;
    *)
      echo "Invalid option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

SERVICE_ACCOUNT_NAME="cloudguard-centralized-auth"
echo "setting up default project "$PROJECT""
gcloud config set project "$PROJECT"
echo "Enabling Deployment Manager APIs, which you will need for the offboarding."
gcloud services enable deploymentmanager.googleapis.com

# sinks deletion
# Example input: --sinks='[{"projectId":"project1", "sinkName":"sink1"}, {"projectId":"project2", "sinkName":"sink2"}]'
if $SINKS_PROVIDED; then
  for sink in $(echo "$SINKS" | jq -c '.[]');
  do
    PROJECT_ID=$(echo "$sink" | jq -r '.projectId')
    SINK_NAME=$(echo "$sink" | jq -r '.sinkName')
    if gcloud logging sinks describe "$SINK_NAME" --project="$PROJECT_ID" &>/dev/null; then
      sink=$(gcloud logging sinks delete "$SINK_NAME" --project="$PROJECT_ID" 2>&1)
      echo $sink
      if [[ "$sink" =~ "ERROR" ]]; then
        echo "could not delete existing sink "$SINK_NAME""
      fi
    fi
  done
fi

# subscription deletion
if $SUBSCRIPTIONS_PROVIDED; then
  for SUBSCRIPTION_NAME in $SUBSCRIPTIONS
  do
    if gcloud pubsub subscriptions describe "$SUBSCRIPTION_NAME" &>/dev/null; then
      pubsubSubscription=$(gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME" 2>&1)
      echo $pubsubSubscription
      if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
        echo "could not delete existing subscription "$SUBSCRIPTION_NAME""
      fi
    fi
  done
fi

# topics deletion
if $TOPICS_PROVIDED; then
  for TOPIC_NAME in $TOPICS
  do
    if gcloud pubsub topics describe "$TOPIC_NAME" &>/dev/null; then
      topic=$(gcloud pubsub topics delete "$TOPIC_NAME" 2>&1)
      echo $topic
      if [[ "$topic" =~ "ERROR" ]]; then
        echo "could not delete existing topic "$TOPIC_NAME""
      fi
    fi
   done
fi

# service account deletion
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com &> /dev/null; then
  serviceAccount=$(gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com 2>&1)
  echo $serviceAccount
  if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not delete existing service account "$SERVICE_ACCOUNT_NAME""
  fi
fi

green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Project Offboarded Successfully.${clear}"
