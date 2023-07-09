resource "google_project_iam_custom_role" "yaelRole2" {
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

variable "bucket_name" {
  description = "The name of the GCP bucket"
  type        = string
}

resource "google_storage_bucket" "yaelBucket1" {
  name     = var.bucket_name
  location = "us-central1"  # Specify the desired location for the bucket

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_binding" "yaelBucket1AllUsers" {
  bucket  = google_storage_bucket.yaelBucket1.name
  role    = "roles/storage.objectCreator"
  members = ["allUsers"]
}

resource "google_service_account" "yaelServiceAccount1" {
  account_id   = "yael-service-account-1"
  display_name = "yaelServiceAccount1"
}

resource "google_project_iam_binding" "yaelRole2Binding" {
  project = google_project.project.project_id
  role    = google_project_iam_custom_role.yaelRole2.role_id
  members = [
    "serviceAccount:${google_service_account.yaelServiceAccount1.email}"
  ]
}

resource "google_cloudfunctions_function" "yaelFunction1" {
  name                  = "yaelFunction1"
  runtime               = "python37"
  source_archive_bucket = var.bucket_name
  source_archive_object = "yael.zip"
  region                = "us-central1"  # Specify the desired region for the Cloud Function
  entry_point           = "main"
  service_account_email = google_service_account.yaelServiceAccount1.email

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = var.bucket_name
  }

  ingress_settings = "ALLOW_ALL"
}
