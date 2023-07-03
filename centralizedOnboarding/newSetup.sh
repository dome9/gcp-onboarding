#!/bin/bash

# Function to display usage information
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --endpoint=<ENDPOINT>             Specify the cloudguard endpoint"
  echo "  --onboarding-type=<TYPE>          Specify the onboarding type"
  echo "  --centralized-project=<PROJECT>   Specify the centralized project"
  echo "  --topic-name=<TOPIC>              Specify the topic name"
  echo "  --subscription-name=<SUBSCRIPTION> Specify the subscription name"
  echo "  --projects-to-onboard=<PROJECTS>  Specify the projects to onboard (space-separated, ex: \"projectA projectB ...\")"
}

# Parse the named arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --endpoint=*) ENDPOINT="${1#*=}";;
    --onboarding-type=*) ONBOARDING_TYPE="${1#*=}";;
    --centralized-project=*) CENTRALIZED_PROJECT="${1#*=}";;
    --topic-name=*) TOPIC_NAME="${1#*=}";;
    --subscription-name=*) SUBSCRIPTION_NAME="${1#*=}";;
    --projects-to-onboard=*) PROJECTS_TO_ONBOARD="${1#*=}";;
    *)
      echo "Invalid option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$ENDPOINT" || -z "$ONBOARDING_TYPE" || -z "$CENTRALIZED_PROJECT" || -z "$TOPIC_NAME" || -z "$SUBSCRIPTION_NAME" || -z "$PROJECTS_TO_ONBOARD" ]]; then
  echo "Missing one or more required arguments."
  usage
  exit 1
fi

if [[ $ONBOARDING_TYPE == "AccountActivity" ]]; then
    LOG_FILTER='LOG_ID("cloudaudit.googleapis.com/activity") OR LOG_ID("cloudaudit.googleapis.com%2Fdata_access") OR LOG_ID("cloudaudit.googleapis.com%2Fpolicy")'

elif [[ $ONBOARDING_TYPE == "NetworkTraffic" ]]; then
    LOG_FILTER='LOG_ID("compute.googleapis.com%2Fvpc_flows")'
else
  echo "invalid onboarding type $ONBOARDING_TYPE, EXITING WITHOUT DEPLOYMENT!"
  exit 1
fi

SERVICE_ACCOUNT_NAME="cloudguard-logs-auth"
SINK_NAME="cloudguard-$ONBOARDING_TYPE-sink-to-centralized"
AUDIENCE="dome9-gcp-logs-collector"
MAX_RETRY_DELAY=60
MIN_RETRY_DELAY=10
ACK_DEADLINE=60
EXPIRATION_PERIOD="never"

echo""
echo "setting up default project $CENTRALIZED_PROJECT"
gcloud config set project $CENTRALIZED_PROJECT
echo "Enabling Deployment Manager APIs, which you will need for this deployment."
gcloud services enable deploymentmanager.googleapis.com

echo""
echo "Start cleaning redundant resources from previous onboarding if exist..."
echo ""

# delete exsiting subscription if exists
pubsubSubscription=$(gcloud pubsub subscriptions list --filter="name.scope(subscription):"$SUBSCRIPTION_NAME"" --quiet 2>&1)
if [[ ! "$pubsubSubscription" =~ "0 items" ]]; then
  pubsubSubscription=$(gcloud pubsub subscriptions delete "$SUBSCRIPTION_NAME")
  if [[ "$pubsubSubscription" =~ "ERROR" ]]; then
    echo "could not delete existing subscription "$SUBSCRIPTION_NAME", EXITING WITHOUT DEPLOYMENT!"
    exit 1
  fi
fi

# delete exsiting topic if exists
topic=$(gcloud pubsub topics list --filter="name.scope(topic):"$TOPIC_NAME"" 2>&1)
if [[ ! "$topic" =~ "0 items" ]]; then
  topic=$(gcloud pubsub topics delete "$TOPIC_NAME" --quiet)
  if [[ "$topic" =~ "ERROR" ]]; then
    echo "could not delete existing topic "$TOPIC_NAME", EXITING WITHOUT DEPLOYMENT!"
    exit 1
  fi
fi

# delete exsiting service account if exists
serviceAccount=$(gcloud iam service-accounts list --filter="name.scope(service account):$SERVICE_ACCOUNT_NAME" 2>&1)
if [[ ! "$serviceAccount" =~ "0 items" ]]; then
  serviceAccount=$(gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME"@"$CENTRALIZED_PROJECT".iam.gserviceaccount.com --quiet)
  if [[ "$serviceAccount" =~ "ERROR" ]]; then
    echo "could not delete existing service account "$SERVICE_ACCOUNT_NAME", EXITING WITHOUT DEPLOYMENT!"
    exit 1
  fi
fi

# delete exsiting sink from each onboarded project if exists
for PROJECT_ID in $PROJECTS_TO_ONBOARD
do
	sink=$(gcloud logging sinks list --project="$PROJECT_ID" --filter="name.scope(sink):"$SINK_NAME"" 2>&1)
	if [[ ! "$sink" =~ "0 items" ]]; then
		sink=$(gcloud logging sinks delete "$SINK_NAME" --project="$PROJECT_ID" --quiet)
		if [[ "$sink" =~ "ERROR" ]]; then
			echo "could not delete existing sink "$SINK_NAME", EXITING WITHOUT DEPLOYMENT!"
			exit 1
		fi
	fi
done

echo ""
echo "Cleanup completed, starting onboarding process..."
echo ""

# service account creation
serviceAccount=$(gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME"@"$CENTRALIZED_PROJECT".iam.gserviceaccount.com --format="value(email)" 2>&1)
if [[ ! $? -eq 0 ]]; then
  serviceAccount=$(gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME --display-name="$SERVICE_ACCOUNT_NAME" 2>&1)
    if [[ "$serviceAccount" =~ "ERROR" ]]; then
        echo "could not create service account "$SERVICE_ACCOUNT_NAME", EXITING WITHOUT DEPLOYMENT!"
        exit 1
    fi
fi


# topic creation
topic=$(gcloud pubsub topics create "$TOPIC_NAME" 2>&1)
echo "$topic"
if [[ "$topic" =~ "ERROR" ]]; then
    echo "could not create topic "$TOPIC_NAME", EXITING WITHOUT DEPLOYMENT!"
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
    echo "could not create subscription "$SUBSCRIPTION_NAME", EXITING WITHOUT DEPLOYMENT!"
    exit 1
fi

# sink creation in each onboarded project
for PROJECT_ID in $PROJECTS_TO_ONBOARD
do
	sink=$(gcloud logging sinks create "$SINK_NAME" pubsub.googleapis.com/projects/"$CENTRALIZED_PROJECT"/topics/"$TOPIC_NAME" \
            --project="$PROJECT_ID" --log-filter="$LOG_FILTER" 2>&1)

	# granting write permissions to sink
	writerIdentity=$(gcloud logging sinks describe "$SINK_NAME" --project "$PROJECT_ID" --format="value(writerIdentity)")
  gcloud pubsub topics add-iam-policy-binding "$TOPIC_NAME" --member="$writerIdentity" --role="roles/pubsub.publisher"
	echo "$sink"
	if [[ "$sink" =~ "ERROR" ]]; then
		echo "could not create sink "$SINK_NAME" in project "$PROJECT_ID", EXITING WITHOUT DEPLOYMENT!"
		exit 1
	fi
done

echo ""
green='\033[0;32m'
clear='\033[0m'
bold=$(tput bold)
echo -e "${bold}${green}Onboarding Completed Successfully.${clear}"