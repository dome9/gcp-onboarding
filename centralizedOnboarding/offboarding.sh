#!/bin/bash

SINKS_PROVIDED=false
TOPICS_PROVIDED=false
SUBSCRIPTIONS_PROVIDED=FALSE

# Parse the named arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --project-id=*)
      PROJECT="${1#*=}";;

    --topics=*)
      TOPICS="${1#*=}"
      TOPIC_PROVIDED=true;;

    --subscriptions=*)
      SUBSCRIPTIONS="${1#*=}"
      SUBSCRIPTION_PROVIDED=true;;

    --sinks=*)
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

SERVICE_ACCOUNT_NAME="cloudguard-logs-authentication"
SERVICE_ACCOUNT_NAME_FL="cloudguard-fl-authentication"

echo "setting up default project "$PROJECT""
gcloud config set project "$PROJECT"
echo "Enabling Deployment Manager APIs, which you will need for the offboarding."
gcloud services enable deploymentmanager.googleapis.com

# sinks deletion
# Example input: --sinks='[{"projectId":"project1", "sinkName":"sink1"}, {"projectId":"project2", "sinkName":"sink2"}]'
if $SINKS_PROVIDED; then
  for sink in $(echo "$SINKS" | jq -c '.[]'); do
    PROJECT_ID=$(echo "$sink" | jq -r '.projectId')
    SINK_NAME=$(echo "$sink" | jq -r '.sinkName')
    sink=$(gcloud logging sinks list --project="$PROJECT_ID" --filter="name.scope(sink):"$SINK_NAME"" 2>&1)
    if [[ ! "$sink" =~ "0 items" ]]; then
      sink=$(gcloud logging sinks delete "$SINK_NAME")
      if [[ "$sink" =~ "ERROR" ]]; then
        echo "could not delete existing sink "$SINK_NAME" "
      fi
    fi
  done
fi

# subscription deletion
if $SUBSCRIPTIONS_PROVIDED; then
  for SUBSCRIPTION_NAME in $SUBSCRIPTIONS do
    pubsubSubscription=$(gcloud pubsub subscriptions list --filter="name.scope(subscription):"$SUBSCRIPTION_NAME"" 2>&1)
      if [[ ! "$pubsubSubscription" =~ "0 items" ]]; then
        pubsubSubscription=$(gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME")
        if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
          echo "could not delete existing subscription "$SUBSCRIPTION_NAME" "
        fi
      fi
  done
fi

# topics deletion
if $TOPICS_PROVIDED; then
  for TOPIC_NAME in $TOPICS do
    topic=$(gcloud pubsub topics list --filter="name.scope(topic):"$TOPIC_NAME"" 2>&1)
    if [[ ! "$topic" =~ "0 items" ]]; then
      topic=$(gcloud pubsub topics delete "$TOPIC_NAME")
      if [[ "$topic" =~ "ERROR" ]]; then
        echo "could not delete existing topic "$TOPIC_NAME" "
      fi
    fi
fi

# service account deletion
serviceAccount=$(gcloud iam service-accounts list --filter="name.scope(service account):$SERVICE_ACCOUNT_NAME" 2>&1)
if [[ ! "$serviceAccount" =~ "0 items" ]]; then
  serviceAccount=$(gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com)
  if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not delete existing service account "$SERVICE_ACCOUNT_NAME" "
  fi
fi

# service account deletion flowlogs
serviceAccount=$(gcloud iam service-accounts list --filter="name.scope(service account):$SERVICE_ACCOUNT_NAME_FL" 2>&1)
if [[ ! "$serviceAccount" =~ "0 items" ]]; then
  serviceAccount=$(gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME_FL"@"$PROJECT".iam.gserviceaccount.com)
  if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not delete existing service account "$SERVICE_ACCOUNT_NAME_FL" "
  fi
fi

green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Project Offboarded Successfully.${clear}"