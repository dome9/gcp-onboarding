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

echo "Setting up default project "$PROJECT""
gcloud config set project "$PROJECT"
echo ""
echo "About to delete resources related to CloudGuard deployment for "$PROJECT" project"
echo ""

# sink deletion
if gcloud logging sinks describe "$SINK_NAME" &>/dev/null; then
  gcloud logging sinks delete "$SINK_NAME"
fi

# sink deletion flowlogs
if gcloud logging sinks describe "$SINK_NAME_FL" &>/dev/null; then
  gcloud logging sinks delete "$SINK_NAME_FL"
fi

# subscription deletion
if gcloud pubsub subscriptions describe "$SUBSCRIPTION_NAME" &>/dev/null; then
  gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME"
fi

# subscription deletion flowlogs
if gcloud pubsub subscriptions describe "$SUBSCRIPTION_NAME_FL" &>/dev/null; then
  gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME_FL"
fi

# topic deletion
if gcloud pubsub topics describe "$TOPIC_NAME" &>/dev/null; then
  gcloud pubsub topics delete "$TOPIC_NAME"
fi

# topic deletion flowlogs
if gcloud pubsub topics describe "$TOPIC_NAME_FL" &>/dev/null; then
  gcloud pubsub topics delete "$TOPIC_NAME_FL"
fi

# service account deletion
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com &> /dev/null; then
  gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com
fi

# service account deletion flowlogs
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME_FL"@"$PROJECT".iam.gserviceaccount.com &> /dev/null; then
  gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME_FL"@"$PROJECT".iam.gserviceaccount.com
fi

green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Project Successfully Offboarded.${clear}"