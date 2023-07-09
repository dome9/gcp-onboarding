data "google_storage_bucket" "existing_yaelBucket1" {
  name = "yael-test-1"
}

resource "google_project_iam_custom_role" "yaelRole2" {
  count       = data.google_storage_bucket.existing_yaelBucket1 == null ? 1 : 0
  role_id     = "yaelRole2"
  title       = "yaelRole2"
  description = "Custom role with specific permissions"
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
}

resource "google_storage_bucket" "yaelBucket1" {
  count    = data.google_storage_bucket.existing_yaelBucket1 == null ? 1 : 0
  name     = "yael-test-1"
  location = "us-central1"  # Specify the desired location for the bucket

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_binding" "yaelBucket1AllUsers" {
  count   = data.google_storage_bucket.existing_yaelBucket1 == null ? 1 : 0
  bucket  = google_storage_bucket.yaelBucket1[0].name
  role    = "roles/storage.objectCreator"
  members = ["allUsers"]
}

resource "google_service_account" "yaelServiceAccount1" {
  account_id   = "yael-service-account-1"
  display_name = "yaelServiceAccount1"
}

resource "google_cloudfunctions_function" "yaelFunction1" {
  count                 = data.google_storage_bucket.existing_yaelBucket1 == null ? 1 : 0
  name                  = "yaelFunction1"
  runtime               = "python37"
  source_archive_bucket = google_storage_bucket.yaelBucket1[0].name
  source_archive_object = "yael.zip"
  region                = "us-central1"  # Specify the desired region for the Cloud Function
  entry_point           = "main"
  service_account_email = google_service_account.yaelServiceAccount1.email

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.yaelBucket1[0].name
  }

  ingress_settings = "ALLOW_ALL"

  environment_variables = {
    "SOURCE_ZIP_FILE" = "gs://${google_storage_bucket.yaelBucket1[0].name}/yael.zip"
  }
}
