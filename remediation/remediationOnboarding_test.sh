#!/bin/bash


# Create bucket if it does not exist
BUCKET_NAME="yaelCloudBucket"
BUCKET_EXISTS=$(gsutil ls -b gs://${BUCKET_NAME} 2>/dev/null)

if [[ -z "${BUCKET_EXISTS}" ]]; then
  gsutil mb gs://${BUCKET_NAME}
fi

# Download zip file from AWS S3
S3_URL="https://yael-test-1.s3.amazonaws.com/yael.zip"
wget ${S3_URL} -O yael.zip

# Upload zip file to GCP bucket
gsutil cp yael.zip gs://${BUCKET_NAME}/yael.zip


