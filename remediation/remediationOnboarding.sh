#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: $0 <BUCKET_NAME>"
  exit 1
fi

BUCKET_NAME=$1
REGION="us-central1"

if gsutil ls -b gs://${BUCKET_NAME} >/dev/null 2>&1; then
  echo "Bucket ${BUCKET_NAME} exists."
else
  echo "Bucket ${BUCKET_NAME} does not exist."
  if gsutil mb -l ${REGION} gs://${BUCKET_NAME} >/dev/null 2>&1; then
    echo "Bucket ${BUCKET_NAME} created successfully."
  else
    echo "Failed to create bucket ${BUCKET_NAME}. Error:"
    gsutil mb -l ${REGION} gs://${BUCKET_NAME} 2>&1
    exit 1
  fi
fi

ZIP_URL="https://dome9-backend-artifacts.s3.amazonaws.com/gcpcloudbots/cloud-bots-gcp.zip"
if wget -q ${ZIP_URL} -O cloud-bots-gcp.zip; then
  echo "Zip file downloaded successfully."
else
  echo "Failed to download the zip file from ${ZIP_URL}. Error:"
  wget -S ${ZIP_URL} -O cloud-bots-gcp.zip 2>&1
  exit 1
fi

if gsutil -m rm -f gs://${BUCKET_NAME}/cloud-bots-gcp.zip >/dev/null 2>&1; then
  echo "Previous zip file removed from the GCP bucket."
fi

if gsutil cp cloud-bots-gcp.zip gs://${BUCKET_NAME}/cloud-bots-gcp.zip >/dev/null 2>&1; then
  echo "Zip file uploaded to GCP bucket successfully."
else
  echo "Failed to upload the zip file to the GCP bucket. Error:"
  gsutil cp cloud-bots-gcp.zip gs://${BUCKET_NAME}/cloud-bots-gcp.zip 2>&1
  exit 1
fi

rm cloud-bots-gcp.zip


terraform init
plan_output_file="terraform_plan.tfplan"
terraform plan -var="bucket_name=${BUCKET_NAME}" -var="region=${REGION}" -out="${plan_output_file}"
plan_exit_code=$?
if [ $plan_exit_code -ne 0 ]; then
  echo "Error occurred during 'terraform plan'."
  exit 1
fi

terraform apply "${plan_output_file}"
apply_exit_code=$?
if [ $apply_exit_code -ne 0 ]; then
  echo "Error occurred during 'terraform apply'."
  exit 1
fi

echo "Script completed successfully."
