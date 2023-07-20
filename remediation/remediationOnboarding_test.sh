#!/bin/bash

cat requirements.txt
echo "Running with Python: $(which python)"
echo "Python version: $(python --version)"
echo "PIP version: $(pip --version)"

if [ $# -eq 2 ]; then
  BUCKET_NAME=$1
  REGION=$2
elif [ -n "$TF_BUCKET_NAME" ] && [ -n "$TF_REGION" ]; then
  BUCKET_NAME=$TF_BUCKET_NAME
  REGION=$TF_REGION
else
  echo "Bucket name and/or region as missing."
  exit 1
fi


if gsutil ls -b gs://${BUCKET_NAME} >/dev/null 2>&1; then
  echo "Bucket ${BUCKET_NAME} already exists."
else
  # Create the bucket
  if gsutil mb -l ${REGION} gs://${BUCKET_NAME} >/dev/null 2>&1; then
    echo "Bucket ${BUCKET_NAME} created successfully."
  else
    echo "Failed to create bucket ${BUCKET_NAME}. Error: $(gsutil mb -l ${REGION} gs://${BUCKET_NAME} 2>&1)."
    exit 1
  fi
fi


ZIP_URL="https://dome9-backend-artifacts.s3.amazonaws.com/gcpcloudbots/cloud-bots-gcp.zip"
if wget -q ${ZIP_URL} -O yael.zip; then
  echo "Zip file downloaded successfully."
else
  echo "Failed to download the zip file from ${ZIP_URL}. Error: $(wget -S ${ZIP_URL} -O yael.zip 2>&1)."
  exit 1
fi


if gsutil cp yael.zip gs://${BUCKET_NAME}/yael.zip >/dev/null 2>&1; then
  echo "Zip file uploaded to GCP bucket successfully."
else
  echo "Failed to upload the zip file to the GCP bucket. Error: $(gsutil cp yael.zip gs://${BUCKET_NAME}/yael.zip 2>&1)."
  exit 1
fi


rm yael.zip

# Run Terraform
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
