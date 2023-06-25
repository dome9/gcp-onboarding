#!/bin/bash

# Set the deployment name
deployment_name="yael-deployment3"

# Set the YAML file name
yaml_file="test.yaml"

echo "Enabling Deployment Manager APIs, which you will need for this deployment."
gcloud services enable deploymentmanager.googleapis.com

echo "Creating deployment..."
if gcloud deployment-manager deployments create $deployment_name --config $yaml_file; then
  echo "Deployment created successfully."
else
  echo "Deployment failed."
fi
