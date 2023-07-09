#!/bin/bash

# Get the bucket name from command line argument
if [ $# -ne 1 ]; then
  echo "Please provide the bucket name as a command line argument."
  exit 1
fi

BUCKET_NAME=$1

# Check if the bucket already exists
if gsutil ls -b gs://${BUCKET_NAME} >/dev/null 2>&1; then
  echo "Bucket ${BUCKET_NAME} already exists."
else
  # Create the bucket
  if gsutil mb gs://${BUCKET_NAME} >/dev/null 2>&1; then
    echo "Bucket ${BUCKET_NAME} created successfully."
  else
    echo "Failed to create bucket ${BUCKET_NAME}. Error: $(gsutil mb gs://${BUCKET_NAME} 2>&1). Exiting."
    exit 1
  fi
fi

# Download the zip file from AWS S3
ZIP_URL="https://yael-test-1.s3.amazonaws.com/yael.zip"
if wget -q ${ZIP_URL} -O yael.zip; then
  echo "Zip file downloaded successfully."
else
  echo "Failed to create bucket ${BUCKET_NAME}. Error: $(gsutil mb gs://${BUCKET_NAME} 2>&1). Exiting."
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


echo "Script completed successfully."
