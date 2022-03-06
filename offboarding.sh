#!/bin/bash
PROJECT=$1
TOPIC_NAME="cloudguard-topic"
SERVICE_ACCOUNT_NAME="cloudguard-logs-authentication"
SINK_NAME="cloudguard-sink"
SUBSCRIPTION_NAME="cloudguard-subscription"
TOPIC_NAME_FL="cloudguard-fl-topic"
SERVICE_ACCOUNT_NAME_FL="cloudguard-fl-authentication"
SINK_NAME_FL="cloudguard-fl-sink"

echo "setting up default project "$PROJECT""
gcloud config set project "$PROJECT"
echo "Enabling Deployment Manager APIs, which you will need for the offboarding."
gcloud services enable deploymentmanager.googleapis.com

# sink deletion
sink=$(gcloud logging sinks list --filter="name.scope(sink):"$SINK_NAME"" 2>&1)
if [[ ! "$sink" =~ "0 items" ]]; then
  sink=$(gcloud logging sinks delete "$SINK_NAME")
  if [[ "$sink" =~ "ERROR" ]]; then
    echo "could not delete existing sink "$SINK_NAME" "
  fi
fi
# sink deletion flowlogs
sink=$(gcloud logging sinks list --filter="name.scope(sink):"$SINK_NAME_FL"" 2>&1)
if [[ ! "$sink" =~ "0 items" ]]; then
  sink=$(gcloud logging sinks delete "$SINK_NAME_FL")
  if [[ "$sink" =~ "ERROR" ]]; then
    echo "could not delete existing sink "$SINK_NAME_FL" "
  fi
fi

# subscription deletion
pubsubSubscription=$(gcloud pubsub subscriptions list --filter="name.scope(subscription):"$SUBSCRIPTION_NAME"" 2>&1)
if [[ ! "$pubsubSubscription" =~ "0 items" ]]; then
  pubsubSubscription=$(gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME")
  if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
    echo "could not delete existing subscription "$SUBSCRIPTION_NAME" "
  fi
fi
# subscription deletion flowlogs
pubsubSubscription=$(gcloud pubsub subscriptions list --filter="name.scope(subscription):"$SUBSCRIPTION_NAME_FL"" 2>&1)
if [[ ! "$pubsubSubscription" =~ "0 items" ]]; then
  pubsubSubscription=$(gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME_FL")
  if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
    echo "could not delete existing subscription "$SUBSCRIPTION_NAME_FL" "
  fi
fi

# topic deletion
topic=$(gcloud pubsub topics list --filter="name.scope(topic):"$TOPIC_NAME"" 2>&1)
if [[ ! "$topic" =~ "0 items" ]]; then
  topic=$(gcloud pubsub topics delete "$TOPIC_NAME")
  if [[ "$topic" =~ "ERROR" ]]; then
    echo "could not delete existing topic "$TOPIC_NAME" "
  fi
fi
# topic deletion flowlogs
topic=$(gcloud pubsub topics list --filter="name.scope(topic):"$TOPIC_NAME_FL"" 2>&1)
if [[ ! "$topic" =~ "0 items" ]]; then
  topic=$(gcloud pubsub topics delete "$TOPIC_NAME_FL")
  if [[ "$topic" =~ "ERROR" ]]; then
    echo "could not delete existing topic "$TOPIC_NAME_FL" "
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

green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Project Successfully Offboarded.${clear}"