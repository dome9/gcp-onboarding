# main.tf

# Create the IAM role
resource "google_project_iam_custom_role" "yaelRole2" {
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
resource "google_storage_bucket" "yaelBucket1" {
  name     = "yael-test-1"
  project  = "chkp-gcp-yaelel-box"

  uniform_bucket_level_access = true
}

# Grant objectCreator role to allUsers on the bucket
resource "google_storage_bucket_iam_binding" "yaelBucket1AllUsers" {
  bucket = google_storage_bucket.yaelBucket1.name
  role   = "roles/storage.objectCreator"

  members = [
    "allUsers",
  ]
}

# Create the IAM service account
resource "google_service_account" "yaelServiceAccount1" {
  account_id   = "yael-service-account-1"
  display_name = "yaelServiceAccount1"
}

# Create the Cloud Function
resource "google_cloudfunctions_function" "yaelFunction1" {
  name         = "yaelFunction1"
  runtime      = "python37"
  source_archive_bucket = google_storage_bucket.yaelBucket1.name
  source_archive_object = "yael.zip"
  project      = "chkp-gcp-yaelel-box"
  location     = "us-central1"
  entry_point  = "main"
  service_account_email = google_service_account.yaelServiceAccount1.email

  https_trigger {}
  ingress_settings = "ALLOW_ALL"

  environment_variables = {
    "SOURCE_ZIP_FILE" = "gs://${google_storage_bucket.yaelBucket1.name}/yael.zip"
  }
}
