resource "google_bigquery_dataset" "homelab" {
  project    = var.project_id
  dataset_id = var.dataset_id
  location   = var.location

  description = "Homelab analytics: observability tables and future pipeline marts."

  labels = {
    env     = "homelab"
    managed = "terraform"
  }
}

resource "google_bigquery_dataset_iam_member" "data_editor" {
  for_each = toset(distinct(compact(var.data_editor_members)))

  project    = var.project_id
  dataset_id = google_bigquery_dataset.homelab.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = each.value
}

resource "google_project_iam_member" "job_user" {
  for_each = toset(distinct(compact(var.job_user_members)))

  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = each.value
}
