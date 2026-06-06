# WIF bindings are one-time bootstrap (local apply / gcloud), not CI-managed.
# Dropped from config after merge; keep existing GCP bindings out of Terraform state.

removed {
  from = google_service_account_iam_member.github_actions_wif_repository

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_service_account_iam_member.github_actions_wif_subject

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_service_account_iam_member.github_actions_wif

  lifecycle {
    destroy = false
  }
}
