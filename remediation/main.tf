# Define the bucket name as a variable
variable "bucket_name" {
  description = "The name of the GCP bucket"
  type        = string
}

data "google_project" "current" {}

data "google_region" "current_region" {}

resource "google_service_account" "yael_service_account" {
  account_id   = "yael-service-account"
  display_name = "Yael Service Account"
}

resource "google_project_iam_custom_role" "yaelRole2" {
  role_id      = "yaelRole2"
  title        = "yaelRole2"
  description  = "Custom role with specific permissions"
  permissions  = [
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
        "storage.buckets.setIamPolicy"
  ]
}

resource "google_project_iam_binding" "service_role_binding" {
  project = data.google_project.current.project_id
  role    = "projects/${data.google_project.current.project_id}/roles/${google_project_iam_custom_role.yaelRole2.role_id}"

  members = [
    "serviceAccount:${google_service_account.yael_service_account.email}",
  ]
}

resource "google_cloudfunctions_function" "yaelFunction2" {
  name                  = "yaelFunction2"
  runtime               = "python37"
  source_archive_bucket = var.bucket_name
  source_archive_object = "yael.zip"
  region                = google_project.current.region
  entry_point           = "main"
  service_account_email = google_service_account.yael_service_account.email

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = var.bucket_name
  }

  ingress_settings = "ALLOW_ALL"
}
