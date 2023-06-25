#!/bin/bash

# Set the deployment name
deployment_name="deploymentYael"

# Set the YAML file name
yaml_file="test.yaml"

echo "Creating deployment..."
if gcloud deployment-manager deployments update $deployment_name --config $yaml_file; then
  echo "Deployment updated successfully."
else
  echo "Deployment failed."
fi
