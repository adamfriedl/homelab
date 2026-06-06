# GitHub Actions Workload Identity Federation — CI impersonates terraform-ci without keys.
# Bindings must match github.repository (and pull_request uses a distinct OIDC subject).

data "google_project" "current" {}

locals {
  ci_service_account_email = coalesce(
    var.ci_service_account_email,
    "terraform-ci@${var.project_id}.iam.gserviceaccount.com",
  )

  github_wif_pool = "projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.github_wif_pool_id}"
  github_wif_sa   = "projects/${data.google_project.current.project_id}/serviceAccounts/${local.ci_service_account_email}"

  github_wif_subjects = var.enable_github_actions_wif ? [
    "repo:${var.github_repository}:pull_request",
    "repo:${var.github_repository}:ref:refs/heads/main",
  ] : []
}

moved {
  from = google_service_account_iam_member.github_actions_wif
  to   = google_service_account_iam_member.github_actions_wif_repository
}

resource "google_service_account_iam_member" "github_actions_wif_repository" {
  count = var.enable_github_actions_wif ? 1 : 0

  service_account_id = local.github_wif_sa
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.github_wif_pool}/attribute.repository/${var.github_repository}"
}

resource "google_service_account_iam_member" "github_actions_wif_subject" {
  for_each = var.enable_github_actions_wif ? toset(local.github_wif_subjects) : toset([])

  service_account_id = local.github_wif_sa
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${local.github_wif_pool}/subject/${each.value}"
}
