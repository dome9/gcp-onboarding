#!/bin/bash

# Set the deployment name
deployment_name="deploymentyael123"

# Set the YAML file name
yaml_file="test.yaml"

echo "Enabling Deployment Manager APIs, which you will need for this deployment."
gcloud services enable deploymentmanager.googleapis.com cloudfunctions.googleapis.com iam.googleapis.com storage-component.googleapis.com
sleep 3
echo "Creating or updating deployment..."
if gcloud deployment-manager deployments describe $deployment_name --format="value(name)" &> /dev/null; then
  echo "Deployment exists. Updating..."
  if gcloud deployment-manager deployments update $deployment_name --config $yaml_file; then
    echo "Deployment updated successfully."
  else
    echo "Deployment update failed."
    exit 1
  fi
else
  echo "Deployment does not exist. Creating..."
  if gcloud deployment-manager deployments create $deployment_name --config $yaml_file; then
    echo "Deployment created successfully."
  else
    echo "Deployment creation failed."
    exit 1
  fi
fi
