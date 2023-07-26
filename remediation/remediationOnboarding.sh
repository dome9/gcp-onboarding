#!/bin/bash

TEMP_BUCKET_NAME="temp-gcp-bucket"
REGION="us-central1"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <FUNCTION_NAME>"
  exit 1
fi

FUNCTION_NAME=$1

if gsutil ls -b gs://${TEMP_BUCKET_NAME} >/dev/null 2>&1; then
  echo "Bucket ${TEMP_BUCKET_NAME} exists."
else
  echo "Bucket ${TEMP_BUCKET_NAME} does not exist."
  if gsutil mb -l ${REGION} gs://${TEMP_BUCKET_NAME} >/dev/null 2>&1; then
    echo "Bucket ${TEMP_BUCKET_NAME} created successfully."
  else
    echo "Failed to create bucket ${TEMP_BUCKET_NAME}. Error:"
    gsutil mb -l ${REGION} gs://${TEMP_BUCKET_NAME} 2>&1
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

if gsutil -m rm -f gs://${TEMP_BUCKET_NAME}/cloud-bots-gcp.zip >/dev/null 2>&1; then
  echo "Previous zip file removed from the GCP bucket."
fi

if gsutil cp cloud-bots-gcp.zip gs://${TEMP_BUCKET_NAME}/cloud-bots-gcp.zip >/dev/null 2>&1; then
  echo "Zip file uploaded to GCP bucket successfully."
else
  echo "Failed to upload the zip file to GCP bucket. Error:"
  gsutil cp cloud-bots-gcp.zip gs://${TEMP_BUCKET_NAME}/cloud-bots-gcp.zip 2>&1
  exit 1
fi

rm cloud-bots-gcp.zip

terraform init
plan_output_file="terraform_plan.tfplan"
terraform plan -var="function_name=${FUNCTION_NAME}" -var="region=${REGION}" -var="bucket_name=${TEMP_BUCKET_NAME}" -out="${plan_output_file}"
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

gsutil -m rm -r gs://${TEMP_BUCKET_NAME}
echo "Bucket ${TEMP_BUCKET_NAME} deleted successfully."

echo "Script completed successfully."
