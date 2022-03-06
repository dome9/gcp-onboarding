#!/bin/bash

echo "setting up default project $1"
gcloud config set project $1
echo "Enabling Deployment Manager APIs, which you will need for this deployment."
gcloud services enable deploymentmanager.googleapis.com
sh ../../onboardingFlowLogs.sh "central" $1
