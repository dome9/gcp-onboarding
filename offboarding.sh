#!/bin/bash
PROJECT=$1
TOPIC_NAME="cloudguard-topic"
SERVICE_ACCOUNT_NAME="cloudguard-logs-authentication"
SINK_NAME="cloudguard-sink"
SUBSCRIPTION_NAME="cloudguard-subscription"

echo "setting up default project "$PROJECT""
gcloud config set project "$PROJECT"
echo "Enabling Deployment Manager APIs, which you will need for the offboarding."
gcloud services enable deploymentmanager.googleapis.com

# service account deletion
serviceAccount=$(gcloud iam service-accounts list --filter="name.scope(service account):$SERVICE_ACCOUNT_NAME" 2>&1)
if [[ ! "$serviceAccount" =~ "0 items" ]]; then
  serviceAccount=$(gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com)
  if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not delete existing service account "$SERVICE_ACCOUNT_NAME" "
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

# subscription deletion
pubsubSubscription=$(gcloud pubsub subscriptions list --filter="name.scope(subscription):"$SUBSCRIPTION_NAME"" 2>&1)
if [[ ! "$pubsubSubscription" =~ "0 items" ]]; then
  pubsubSubscription=$(gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME")
  if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
    echo "could not delete existing subscription "$SUBSCRIPTION_NAME" "
  fi
fi

# sink deletion
sink=$(gcloud logging sinks list --filter="name.scope(sink):"$SINK_NAME"" 2>&1)
if [[ ! "$sink" =~ "0 items" ]]; then
  sink=$(gcloud logging sinks delete "$SINK_NAME")
  if [[ "$sink" =~ "ERROR" ]]; then
    echo "could not delete existing sink "$SINK_NAME" "
  fi
fi

echo "Done offboarding."