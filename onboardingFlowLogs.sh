#!/bin/bash
REGION=$1
AUDIENCE="dome9-gcp-logs-collector" # todo - need to change for flow logs?
PROJECT=$2
TOPIC_NAME="cloudguard-flowlogs-topic"
SERVICE_ACCOUNT_NAME="cloudguard-fl-authentication"
SUBSCRIPTION_NAME="cloudguard-flowlogs-subscription"
MAX_RETRY_DELAY=60
MIN_RETRY_DELAY=10
ACK_DEADLINE=60
EXPIRATION_PERIOD="never"
SINK_NAME="cloudguard-flowlogs-sink"
LOG_FILTER='LOG_ID("compute.googleapis.com%2Fvpc_flows")' # todo - do we need more filters? 

if [[ "$REGION" == "central" ]]; then
  ENDPOINT="https://gcp-flow-logs-endpoint.dome9.com" # todo - need to change to flow logs endpoint and create in dome9
else
  ENDPOINT="https://gcp-flow-logs-endpoint.logic."$REGION".dome9.com" # todo - need to change to flow logs endpoint and create in dome9
fi

# service account creation
serviceAccount=$(gcloud iam service-accounts list --filter="name.scope(service account):$SERVICE_ACCOUNT_NAME" 2>&1)
if [[ ! "$serviceAccount" =~ "0 items" ]]; then
  serviceAccount=$(gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com)
  if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not delete existing service account "$SERVICE_ACCOUNT_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
  fi
fi
serviceAccount=$(gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME --display-name="$SERVICE_ACCOUNT_NAME" 2>&1)
echo "$serviceAccount"
if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not create service account "$SERVICE_ACCOUNT_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
fi

# topic creation
topic=$(gcloud pubsub topics list --filter="name.scope(topic):"$TOPIC_NAME"" 2>&1)
if [[ ! "$topic" =~ "0 items" ]]; then
  topic=$(gcloud pubsub topics delete "$TOPIC_NAME")
  if [[ "$topic" =~ "ERROR" ]]; then
    echo "could not delete existing topic "$TOPIC_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
  fi
fi
topic=$(gcloud pubsub topics create "$TOPIC_NAME" 2>&1)
echo "$topic"
if [[ "$topic" =~ "ERROR" ]]; then
    echo "could not create topic "$TOPIC_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
fi

# subscription creation
pubsubSubscription=$(gcloud pubsub subscriptions list --filter="name.scope(subscription):"$SUBSCRIPTION_NAME"" 2>&1)
if [[ ! "$pubsubSubscription" =~ "0 items" ]]; then
  pubsubSubscription=$(gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME")
  if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
    echo "could not delete existing subscription "$SUBSCRIPTION_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
  fi
fi

pubsubSubscription=$(gcloud pubsub subscriptions create "$SUBSCRIPTION_NAME" \
                           --topic="$TOPIC_NAME" \
                           --ack-deadline="$ACK_DEADLINE" \
                           --expiration-period="$EXPIRATION_PERIOD" \
                           --push-endpoint="$ENDPOINT" \
                           --push-auth-service-account="$SERVICE_ACCOUNT_NAME"@"$PROJECT".iam.gserviceaccount.com \
                           --push-auth-token-audience="$AUDIENCE" \
                           --max-retry-delay="$MAX_RETRY_DELAY" \
                           --min-retry-delay="$MIN_RETRY_DELAY" 2>&1)
echo "$pubsubSubscription"
if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
    echo "could not create subscription "$SUBSCRIPTION_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
fi

# sink creation
sink=$(gcloud logging sinks list --filter="name.scope(sink):"$SINK_NAME"" 2>&1)
if [[ ! "$sink" =~ "0 items" ]]; then
  sink=$(gcloud logging sinks delete "$SINK_NAME")
  if [[ "$sink" =~ "ERROR" ]]; then
    echo "could not delete existing sink "$SINK_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
  fi
fi
sink=$(gcloud logging sinks create "$SINK_NAME" pubsub.googleapis.com/projects/"$PROJECT"/topics/"$TOPIC_NAME" \
            --log-filter="$LOG_FILTER" 2>&1)
echo "$sink"
if [[ "$sink" =~ "ERROR" ]]; then
    echo "could not create sink "$SINK_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
fi

# granting write permissions to sink
writerIdentity=$(gcloud logging sinks describe --format='value(writerIdentity)' "$SINK_NAME" 2>&1)
gcloud pubsub topics add-iam-policy-binding cloudguard-topic --member="$writerIdentity" --role=roles/pubsub.publisher

green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Project Successfully Onboarded.${clear}"
