#!/bin/bash

echo "setting up $1"
gcloud config set $1
echo "Enabling Deployment Manager APIs, which you will need for this deployment."
gcloud services enable deploymentmanager.googleapis.com
sh ../remediationOnboarding.sh "GCP Remediation Onboarding" $1
