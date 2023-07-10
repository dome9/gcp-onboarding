#!/bin/bash

# Get the bucket name from command line argument or environment variable
if [ $# -eq 1 ]; then
  BUCKET_NAME=$1
elif [ -n "$TF_BUCKET_NAME" ]; then
  BUCKET_NAME=$TF_BUCKET_NAME
else
  echo "Please provide the bucket name as a command line argument or set the 'TF_BUCKET_NAME' environment variable."
  exit 1
fi

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
#terraform validate
#terraform refresh
terraform state rm google_project_iam_custom_role.yaelRole2
terraform import google_project_iam_custom_role.yaelRole2 projects/$(terraform show -json | jq -r '.values.root_module.resources[] | select(.type == "google_project").values.project_id')/roles/yaelRole2

# Execute terraform plan and capture errors
plan_output_file="terraform_plan.tfplan"
terraform plan -var="bucket_name=${BUCKET_NAME}" -out="${plan_output_file}"
if [ $? -ne 0 ]; then
  echo "Error occurred during 'terraform plan':"
  echo "$plan_output"
  exit 1
fi

# Execute terraform apply and capture errors
apply_output=$(terraform apply "${plan_output_file}" 2>&1)
if [ $? -ne 0 ]; then
  echo "Error occurred during 'terraform apply':"
  echo "$apply_output"
  exit 1
fi


echo "Script completed successfully."
