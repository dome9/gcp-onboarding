# Define the bucket name as a variable
variable "bucket_name" {
  description = "The name of the GCP bucket"
  type        = string
}

data "google_project" "current" {}

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

/* resource "google_project_iam_member" "service_role_binding" {
  project = data.google_project.current.project_id
  role    = "projects/${data.google_project.current.project_id}/roles/${google_project_iam_custom_role.yaelRole2.role_id}"
  member  = "serviceAccount:${google_service_account.yael_service_account.email}"
} */
resource "google_project_iam_binding" "service_role_binding" {
  project = data.google_project.current.project_id
  role    = "projects/${data.google_project.current.project_id}/roles/${google_project_iam_custom_role.yaelRole2.role_id}"

  members = [
    "serviceAccount:${google_service_account.yael_service_account.email}",
  ]
}

/*
# Define the IAM binding for allUsers
resource "google_storage_bucket_iam_binding" "yaelBucket1AllUsers" {
  bucket  = var.bucket_name
  role    = "roles/storage.objectCreator"
  members = ["allUsers"]
}

data "google_service_account" "existing_service_account" {
  account_id = "yael-service-account-1"
}


# Check if the service account already exists
data "google_service_account" "yaelServiceAccount1" {
  account_id = "yael-service-account-1"
}

# Create the service account if it doesn't exist
resource "google_service_account" "create_yaelServiceAccount1" {
  count        = length(data.google_service_account.yaelServiceAccount1) > 0 ? 0 : 1
  account_id   = "yael-service-account-1"
  display_name = "yaelServiceAccount1"
}

# Retrieve the current project ID
data "google_project" "current" {}

# Connect the custom role to the service account
resource "google_project_iam_member" "yaelRole2Binding" {
  project = data.google_project.current.project_id
  role    = google_project_iam_custom_role.yaelRole2.role_id
  member  = length(google_service_account.create_yaelServiceAccount1) > 0 ? "serviceAccount:${google_service_account.create_yaelServiceAccount1[0].email}" : null
} */





















/*
# Define the existing Cloud Function
data "google_cloudfunctions_function" "existing_function" {
  name   = "yaelFunction1"
  region = data.google_region.current.name
}

resource "google_cloudfunctions_function" "yaelFunction1" {
  count                 = data.google_cloudfunctions_function.existing_function ? 0 : 1
  name                  = "yaelFunction1"
  runtime               = "python37"
  source_archive_bucket = var.bucket_name
  source_archive_object = "yael.zip"
  region                = data.google_region.current.name
  entry_point           = "main"
  service_account_email = google_service_account.yaelServiceAccount1[0].email

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = var.bucket_name
  }

  ingress_settings = "ALLOW_ALL"
}

# Define the IAM binding for the Cloud Function and the custom role
resource "google_cloudfunctions_function_iam_binding" "yaelFunction1Binding" {
  function_name = google_cloudfunctions_function.yaelFunction1[0].name
  members       = ["serviceAccount:${google_service_account.yaelServiceAccount1[0].email}"]
}

*/