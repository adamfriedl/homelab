# GitHub Actions Workload Identity Federation — lets CI impersonate terraform-ci without keys.
#
# After renaming the GitHub repo, update github_repository and terraform apply locally once.
# The OIDC token carries assertion.repository (owner/name); the SA binding must match.

data "google_project" "current" {}

locals {
  ci_service_account_email = coalesce(
    var.ci_service_account_email,
    "terraform-ci@${var.project_id}.iam.gserviceaccount.com",
  )

  github_wif_pool_name = "projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.github_wif_pool_id}"
}

resource "google_iam_workload_identity_pool" "github" {
  count = var.manage_github_wif ? 1 : 0

  project                   = var.project_id
  workload_identity_pool_id = var.github_wif_pool_id
  display_name              = "GitHub Actions"
  description               = "OIDC federation for GitHub Actions"
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.manage_github_wif ? 1 : 0

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.github_wif_provider_id
  display_name                       = "GitHub"
  description                        = "GitHub Actions OIDC provider"
  disabled                           = false

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_repository_owner}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "terraform_ci" {
  count = var.manage_github_wif ? 1 : 0

  project      = var.project_id
  account_id   = "terraform-ci"
  display_name = "Terraform / Ansible CI"
}

locals {
  github_wif_service_account = var.manage_github_wif ? google_service_account.terraform_ci[0].name : "projects/${data.google_project.current.project_id}/serviceAccounts/${local.ci_service_account_email}"

  # pull_request and push use different OIDC subjects; attribute.* bindings alone miss PR runs
  # when the pool/provider only maps google.subject, or when ref-scoped conditions apply.
  github_wif_subjects = var.enable_github_actions_wif && var.github_repository != "" ? [
    "repo:${var.github_repository}:pull_request",
    "repo:${var.github_repository}:ref:refs/heads/main",
  ] : []
}

moved {
  from = google_service_account_iam_member.github_actions_wif
  to   = google_service_account_iam_member.github_actions_wif_repository
}

# Subject bindings — required for pull_request workflows (and always mapped as google.subject).
resource "google_service_account_iam_member" "github_actions_wif_subject" {
  for_each = toset(local.github_wif_subjects)

  service_account_id = local.github_wif_service_account
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${local.github_wif_pool_name}/subject/${each.value}"
}

# Owner-level binding survives repo renames (when attribute.repository_owner is mapped).
resource "google_service_account_iam_member" "github_actions_wif_owner" {
  count = var.enable_github_actions_wif ? 1 : 0

  service_account_id = local.github_wif_service_account
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.github_wif_pool_name}/attribute.repository_owner/${var.github_repository_owner}"
}

# Optional tighter binding for a single repository (in addition to owner binding).
resource "google_service_account_iam_member" "github_actions_wif_repository" {
  count = var.enable_github_actions_wif && var.github_repository != "" ? 1 : 0

  service_account_id = local.github_wif_service_account
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.github_wif_pool_name}/attribute.repository/${var.github_repository}"
}
