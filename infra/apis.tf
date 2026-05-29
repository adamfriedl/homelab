# APIs required for GitHub Actions (WIF) and Terraform IAM/project management via CI.
# Enable once manually if CI fails before the first local apply (chicken-and-egg).

resource "google_project_service" "cloudresourcemanager" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "iamcredentials" {
  project = var.project_id
  service = "iamcredentials.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "serviceusage" {
  project = var.project_id
  service = "serviceusage.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "sts" {
  project = var.project_id
  service = "sts.googleapis.com"

  disable_on_destroy = false
}
