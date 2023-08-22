#!/bin/bash

# Function to display usage information
EchoUsage() {
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
SERVICE_ACCOUNT_NAME="cloudguard-centralized-auth"

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
      EchoUsage
      exit 1
      ;;
  esac
  shift
done

echo""
echo "Before proceeding with the offboarding, please ensure that the identity running this script has the following roles and permissions attached in the relevant projects:"
echo""

if $TOPICS_PROVIDED && $SUBSCRIPTIONS_PROVIDED; then
  echo "In $PROJECT:"
  echo "- Editor"
  echo "- Pub/Sub Admin"
  echo "- Logging Admin"
  echo ""
elif $SUBSCRIPTIONS_PROVIDED; then
  echo "In $PROJECT:"
  echo "- Pub/Sub Admin"
  echo ""
fi

if $SINKS_PROVIDED; then
  projectIds=()
  for sink in $(echo "$SINKS" | jq -c '.[]'); do
    PROJECT_ID=$(echo "$sink" | jq -r '.projectId')
    projectIds+=("$PROJECT_ID")
  done

  echo "In ${projectIds[@]}:"
  echo "- Logging Admin"
  echo ""
fi

echo "Setting up default project "$PROJECT""
gcloud config set project "$PROJECT"
echo ""
echo "About to delete resources related to CloudGuard deployment for "$PROJECT" project"
echo ""

# sinks deletion
# Example input: --sinks='[{"projectId":"project1", "sinkName":"sink1"}, {"projectId":"project2", "sinkName":"sink2"}]'
if $SINKS_PROVIDED; then
  for sink in $(echo "$SINKS" | jq -c '.[]');
  do
    PROJECT_ID=$(echo "$sink" | jq -r '.projectId')
    SINK_NAME=$(echo "$sink" | jq -r '.sinkName')
    TOPIC_NAME=$(echo "$sink" | jq -r '.topicName')
    if gcloud logging sinks describe "$SINK_NAME" --project="$PROJECT_ID" &>/dev/null; then
      gcloud logging sinks delete "$SINK_NAME" --project="$PROJECT_ID"
    fi
  done
fi

# subscription deletion
if $SUBSCRIPTIONS_PROVIDED; then
  for SUBSCRIPTION_NAME in $SUBSCRIPTIONS
  do
    if gcloud pubsub subscriptions describe "$SUBSCRIPTION_NAME" &>/dev/null; then
      gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME"
    fi
  done
fi

# topics deletion
if $TOPICS_PROVIDED; then
  for TOPIC_NAME in $TOPICS
  do
    if gcloud pubsub topics describe "$TOPIC_NAME" &>/dev/null; then
      gcloud pubsub topics delete "$TOPIC_NAME"
    fi
   done
fi

# service account deletion
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com &> /dev/null; then
  gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com
fi

green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Project Offboarded Successfully.${clear}"
