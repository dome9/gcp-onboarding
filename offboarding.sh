#!/bin/bash
PROJECT=$1
TOPIC_NAME="cloudguard-topic"
SERVICE_ACCOUNT_NAME="cloudguard-logs-authentication"
SINK_NAME="cloudguard-sink"
SUBSCRIPTION_NAME="cloudguard-subscription"
TOPIC_NAME_FL="cloudguard-fl-topic"
SERVICE_ACCOUNT_NAME_FL="cloudguard-fl-authentication"
SINK_NAME_FL="cloudguard-fl-sink"
SUBSCRIPTION_NAME_FL="cloudguard-fl-subscription"

echo "setting up default project "$PROJECT""
gcloud config set project "$PROJECT"

# sink deletion
if gcloud logging sinks describe "$SINK_NAME" &>/dev/null; then
  sink=$(gcloud logging sinks delete "$SINK_NAME")
    if [[ "$sink" =~ "ERROR" ]]; then
      echo "could not delete existing sink "$SINK_NAME" "
    fi
fi

# sink deletion flowlogs
if gcloud logging sinks describe "$SINK_NAME_FL" &>/dev/null; then
  sink=$(gcloud logging sinks delete "$SINK_NAME_FL")
    if [[ "$sink" =~ "ERROR" ]]; then
      echo "could not delete existing sink "$SINK_NAME_FL" "
    fi
fi

# subscription deletion
if gcloud pubsub subscriptions describe "$SUBSCRIPTION_NAME" &>/dev/null; then
  pubsubSubscription=$(gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME")
    if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
      echo "could not delete existing subscription "$SUBSCRIPTION_NAME" "
    fi
fi

# subscription deletion flowlogs
if gcloud pubsub subscriptions describe "$SUBSCRIPTION_NAME_FL" &>/dev/null; then
  pubsubSubscription=$(gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME_FL")
    if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
      echo "could not delete existing subscription "$SUBSCRIPTION_NAME_FL" "
    fi
fi

# topic deletion
if gcloud pubsub topics describe "$TOPIC_NAME" &>/dev/null; then
  topic=$(gcloud pubsub topics delete "$TOPIC_NAME")
  if [[ "$topic" =~ "ERROR" ]]; then
    echo "could not delete existing topic "$TOPIC_NAME" "
  fi
fi

# topic deletion flowlogs
if gcloud pubsub topics describe "$TOPIC_NAME_FL" &>/dev/null; then
  topic=$(gcloud pubsub topics delete "$TOPIC_NAME_FL")
  if [[ "$topic" =~ "ERROR" ]]; then
    echo "could not delete existing topic "$TOPIC_NAME_FL" "
  fi
fi

# service account deletion
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com &> /dev/null; then
  serviceAccount=$(gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com)
  if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not delete existing service account "$SERVICE_ACCOUNT_NAME" "
  fi
fi

# service account deletion flowlogs
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME_FL"@"$PROJECT".iam.gserviceaccount.com &> /dev/null; then
  serviceAccount=$(gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME_FL"@"$PROJECT".iam.gserviceaccount.com)
  if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not delete existing service account "$SERVICE_ACCOUNT_NAME_FL" "
  fi
fi

green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Project Successfully Offboarded.${clear}"