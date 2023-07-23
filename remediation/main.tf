
variable "bucket_name" {
  description = "GCP bucket for temporary storing the function code"
  type        = string
}

variable "region" {
  description = "The region of the GCP resources"
  type        = string
}

data "google_project" "current" {}

resource "google_service_account" "CloudGuard-CloudBots-Remediation-ServiceAccount" {
  account_id   = "CloudGuard_CloudBots_Remediation_ServiceAccount"
  display_name = "CloudGuard-CloudBots-Remediation-ServiceAccount"
}

resource "google_project_iam_custom_role" "CloudBotsRemediationRole" {
  role_id      = "CloudBotsRemediationRole"
  title        = "CloudGuard-CloudBots-Remediation-Role"
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
        "storage.buckets.setIamPolicy",
        "cloudfunctions.functions.invoke"
  ]
}

resource "google_project_iam_binding" "service_role_binding" {
  project = data.google_project.current.project_id
  role    = "projects/${data.google_project.current.project_id}/roles/${google_project_iam_custom_role.CloudBotsRemediationRole.role_id}"

  members = [
    "serviceAccount:${google_service_account.CloudGuard-CloudBots-Remediation-ServiceAccount.email}",
  ]
}

resource "google_cloudfunctions_function" "CloudGuard-CloudBots-Remediation" {
  name                  = "CloudGuard-CloudBots-Remediation"
  runtime               = "python37"
  source_archive_bucket = var.bucket_name
  source_archive_object = "cloud-bots-gcp.zip"
  region                = var.region
  entry_point           = "main"
  service_account_email = google_service_account.CloudGuard-CloudBots-Remediation-ServiceAccount.email

  trigger_http = true

  ingress_settings = "ALLOW_ALL"
}

resource "google_cloudfunctions_function_iam_member" "CloudGuard-CloudBots-Remediation_iam_member" {
  project     = data.google_project.current.project_id
  region      = var.region
  cloud_function = google_cloudfunctions_function.CloudGuard-CloudBots-Remediation.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}









