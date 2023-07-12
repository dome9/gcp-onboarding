# Define the bucket name as a variable
variable "bucket_name" {
  description = "The name of the GCP bucket"
  type        = string
}

# Define the region as a variable
variable "region" {
  description = "The region for the GCP resources"
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

resource "google_project_iam_binding" "service_role_binding" {
  project = data.google_project.current.project_id
  role    = "projects/${data.google_project.current.project_id}/roles/${google_project_iam_custom_role.yaelRole2.role_id}"

  members = [
    "serviceAccount:${google_service_account.yael_service_account.email}",
  ]
}

resource "google_cloudfunctions_function" "yaelFunction12" {
  name                  = "yaelFunction12"
  runtime               = "python37"
  source_archive_bucket = var.bucket_name
  source_archive_object = "yael.zip"
  region                = var.region
  entry_point           = "main"
  service_account_email = google_service_account.yael_service_account.email

  trigger_http = true

  ingress_settings = "ALLOW_ALL"
}

resource "google_cloudfunctions_function_iam_policy" "yaelFunction12_iam_policy" {
  function_id = google_cloudfunctions_function.yaelFunction12.id

  policy_data = <<-EOF
    {
      "bindings": [
        {
          "role": "roles/cloudfunctions.invoker",
          "members": [
            "allAuthenticatedUsers"
          ]
        }
      ]
    }
  EOF
}







