#!/bin/bash


# Set the deployment name
deployment_name="yael-deployment"

# Set the YAML file name
yaml_file="test.yaml"


echo "Enabling Deployment Manager APIs, which you will need for this deployment."
gcloud services enable deploymentmanager.googleapis.com

echo "Creating deployment..."
gcloud deployment-manager deployments create $deployment_name --config $yaml_file

echo "Deployment created successfully."

