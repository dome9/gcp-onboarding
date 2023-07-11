#!/bin/bash

cat requirements.txt
echo "Running with Python: $(which python)"
echo "Python version: $(python --version)"
echo "PIP version: $(pip --version)"

# Create a virtual environment with Python 3.7
python3.7 -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Install the dependencies from requirements.txt
pip install -r requirements.txt
echo "Python version: $(python --version)"

# Get the bucket name and region from command line arguments or environment variables
if [ $# -eq 2 ]; then
  BUCKET_NAME=$1
  REGION=$2
elif [ -n "$TF_BUCKET_NAME" ] && [ -n "$TF_REGION" ]; then
  BUCKET_NAME=$TF_BUCKET_NAME
  REGION=$TF_REGION
else
  echo "Please provide the bucket name and region as command line arguments or set the 'TF_BUCKET_NAME' and 'TF_REGION' environment variables."
  exit 1
fi

# Check if the bucket already exists
if gsutil ls -b gs://${BUCKET_NAME} >/dev/null 2>&1; then
  echo "Bucket ${BUCKET_NAME} already exists."
else
  # Create the bucket
  if gsutil mb -l ${REGION} gs://${BUCKET_NAME} >/dev/null 2>&1; then
    echo "Bucket ${BUCKET_NAME} created successfully."
  else
    echo "Failed to create bucket ${BUCKET_NAME}. Error: $(gsutil mb -l ${REGION} gs://${BUCKET_NAME} 2>&1). Exiting."
    exit 1
  fi
fi

# Download the zip file from AWS S3
ZIP_URL="https://yael-test-1.s3.amazonaws.com/yael.zip"
if wget -q ${ZIP_URL} -O yael.zip; then
  echo "Zip file downloaded successfully."
else
  echo "Failed to download the zip file from ${ZIP_URL}. Error: $(wget -S ${ZIP_URL} -O yael.zip 2>&1). Exiting."
  exit 1
fi

# Upload the zip file to the GCP bucket
if gsutil cp yael.zip gs://${BUCKET_NAME}/yael.zip >/dev/null 2>&1; then
  echo "Zip file uploaded to GCP bucket successfully."
else
  echo "Failed to upload the zip file to the GCP bucket. Error: $(gsutil cp yael.zip gs://${BUCKET_NAME}/yael.zip 2>&1). Exiting."
  exit 1
fi

# Clean up the downloaded zip file
rm yael.zip

# Run Terraform commands
terraform init
plan_output_file="terraform_plan.tfplan"
terraform plan -var="bucket_name=${BUCKET_NAME}" -var="region=${REGION}" -out="${plan_output_file}"
plan_exit_code=$?
if [ $plan_exit_code -ne 0 ]; then
  echo "Error occurred during 'terraform plan'. Exiting."
  exit 1
fi

terraform apply "${plan_output_file}"
apply_exit_code=$?
if [ $apply_exit_code -ne 0 ]; then
  echo "Error occurred during 'terraform apply'. Exiting."
  exit 1
fi

echo "Script completed successfully."
