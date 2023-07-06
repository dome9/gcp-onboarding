# main.tf

# Create the IAM role
  resource "google_project_iam_custom_role" "yaelRole3" {
  role_id      = "yaelRole2"
  title        = "yaelRole2"
  description  = "Custom role with specific permissions"
  permissions = [
  "cloudsql.instances.get",
  "cloudsql.instances.update",
  "compute.firewalls.delete",
  "compute.instances.get",
  "compute.instances.setLabels",
  "compute.instances.stop",
  "compute.instances.deleteAccessConfig",
  "compute.networks.updatePolicy",
  "compute.subnetworks.get",
  "compute.subnetworks.setPrivateIpGoogleAccess",
  "compute.subnetworks.update",
  "container.clusters.update",
  "gkemulticloud.awsNodePools.update",
  "storage.buckets.getIamPolicy",
  "storage.buckets.setIamPolicy",
  ]
  project = "chkp-gcp-yaelel-box"
}

  # Create the Cloud Storage bucket
  resource "google_storage_bucket" "yaelBucket3" {
  name     = "yael-test-3"
  project  = "chkp-gcp-yaelel-box"

  uniform_bucket_level_access {
  enabled = true
  }

  iam_configuration {
  bucket_policy_only = true
  }
}

  # Grant objectCreator role to allUsers on the bucket
  resource "google_storage_bucket_iam_member" "yaelBucket3AllUsers" {
  bucket = google_storage_bucket.yaelBucket3.name
  role   = "roles/storage.objectCreator"
  member = "allUsers"
}

  # Create the IAM service account
  resource "google_service_account" "yaelServiceAccount3" {
  account_id   = "yaelServiceAccount3"
  display_name = "yaelServiceAccount3"
}

  # Create the Cloud Function
  resource "google_cloudfunctions_function" "yaelFunction3" {
  name         = "yaelFunction3"
  runtime      = "python37"
  source_archive_bucket = google_storage_bucket.yaelBucket3.name
  source_archive_object = "yael.zip"
  project      = "chkp-gcp-yaelel-box"
  location     = "us-central1"
  entry_point  = "main"
  service_account_email = google_service_account.yaelServiceAccount1.email

  https_trigger {}
  ingress_settings = "ALLOW_ALL"

  environment_variables = {
  "SOURCE_ZIP_FILE" = "gs://${google_storage_bucket.yaelBucket3.name}/yael.zip"
  }
}
