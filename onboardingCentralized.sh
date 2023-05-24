#!/bin/bash

echo "setting up default project $2"
gcloud config set project $2
echo "Enabling Deployment Manager APIs, which you will need for this deployment."
gcloud services enable deploymentmanager.googleapis.com

REGION=$1
CENTRALIZED_PROJECT=$2
shift
shift
AUDIENCE="dome9-gcp-logs-collector"
TOPIC_NAME="cloudguard-centralized-topic"
SERVICE_ACCOUNT_NAME="cloudguard-logs-authentication"
SUBSCRIPTION_NAME="cloudguard-centralized-subscription"
MAX_RETRY_DELAY=60
MIN_RETRY_DELAY=10
ACK_DEADLINE=60
EXPIRATION_PERIOD="never"
SINK_NAME="cloudguard-sink-to-centralized"
LOG_FILTER='LOG_ID("cloudaudit.googleapis.com/activity") OR LOG_ID("cloudaudit.googleapis.com%2Fdata_access") OR LOG_ID("cloudaudit.googleapis.com%2Fpolicy")'

if [[ "$REGION" == "central" ]]; then
  ENDPOINT="https://gcp-activity-endpoint.330372055916.logic.941298424820.dev.falconetix.com"
else
  ENDPOINT="https://gcp-activity-endpoint.logic."$REGION".dome9.com"
fi

# delete exsiting subscription if exists
pubsubSubscription=$(gcloud pubsub subscriptions list --filter="name.scope(subscription):"$SUBSCRIPTION_NAME"" --quiet 2>&1)
if [[ ! "$pubsubSubscription" =~ "0 items" ]]; then
  pubsubSubscription=$(gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME")
  if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
    echo "could not delete existing subscription "$SUBSCRIPTION_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
  fi
fi

# delete exsiting topic if exists
topic=$(gcloud pubsub topics list --filter="name.scope(topic):"$TOPIC_NAME"" 2>&1)
if [[ ! "$topic" =~ "0 items" ]]; then
  topic=$(gcloud pubsub topics delete "$TOPIC_NAME" --quiet)
  if [[ "$topic" =~ "ERROR" ]]; then
    echo "could not delete existing topic "$TOPIC_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
  fi
fi

# delete exsiting service account if exists
serviceAccount=$(gcloud iam service-accounts list --filter="name.scope(service account):$SERVICE_ACCOUNT_NAME" 2>&1)
if [[ ! "$serviceAccount" =~ "0 items" ]]; then
  serviceAccount=$(gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME"@"$CENTRALIZED_PROJECT".iam.gserviceaccount.com --quiet)
  if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not delete existing service account "$SERVICE_ACCOUNT_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
  fi
fi

# delete exsiting sink from each onboarded project if exists
for PROJECT_ID in "$@"
do
	sink=$(gcloud logging sinks list --project="$PROJECT_ID" --filter="name.scope(sink):"$SINK_NAME"" 2>&1)
	if [[ ! "$sink" =~ "0 items" ]]; then
		sink=$(gcloud logging sinks delete "$SINK_NAME" --project="$PROJECT_ID" --quiet)
		if [[ "$sink" =~ "ERROR" ]]; then
			echo "could not delete existing sink "$SINK_NAME" EXITING WITHOUT DEPLOYMENT"
			exit 1
		fi
	fi
done


# service account creation
serviceAccount=$(gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME --display-name="$SERVICE_ACCOUNT_NAME" 2>&1)
echo "$serviceAccount"
if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not create service account "$SERVICE_ACCOUNT_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
fi

# topic creation
topic=$(gcloud pubsub topics create "$TOPIC_NAME" 2>&1)
echo "$topic"
if [[ "$topic" =~ "ERROR" ]]; then
    echo "could not create topic "$TOPIC_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
fi

# subscription creation
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
    echo "could not create subscription "$SUBSCRIPTION_NAME" EXITING WITHOUT DEPLOYMENT"
    exit 1
fi

# sink creation in each onboarded project
for PROJECT_ID in "$@"
do
	sink=$(gcloud logging sinks create "$SINK_NAME" pubsub.googleapis.com/projects/"$CENTRALIZED_PROJECT"/topics/"$TOPIC_NAME" \
            --project="$PROJECT_ID" --log-filter="$LOG_FILTER" 2>&1)

	# granting write permissions to sink
	writerIdentity=$(gcloud logging sinks describe "$SINK_NAME" --project "$PROJECT_ID" --format="value(writerIdentity)")
  gcloud pubsub topics add-iam-policy-binding "$TOPIC_NAME" --member="$writerIdentity" --role="roles/pubsub.publisher"
	echo "$sink"
	if [[ "$sink" =~ "ERROR" ]]; then
		echo "could not create sink "$SINK_NAME" in project "$PROJECT_ID" EXITING WITHOUT DEPLOYMENT"
		exit 1
	fi
done

green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Onboarding Completed Successfully.${clear}"