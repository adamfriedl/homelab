output "dataset_id" {
  description = "BigQuery dataset ID."
  value       = google_bigquery_dataset.homelab.dataset_id
}

output "dataset_full_id" {
  description = "Project-qualified dataset ID (project:dataset)."
  value       = "${var.project_id}.${google_bigquery_dataset.homelab.dataset_id}"
}
