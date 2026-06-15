output "dataset_id" {
  description = "BigQuery dataset ID."
  value       = google_bigquery_dataset.homelab.dataset_id
}

output "dataset_full_id" {
  description = "Project-qualified dataset ID (project:dataset)."
  value       = "${var.project_id}.${google_bigquery_dataset.homelab.dataset_id}"
}

output "raw_film_permits_table_id" {
  description = "Fully qualified raw film permits table."
  value       = "${var.project_id}.${google_bigquery_dataset.homelab.dataset_id}.${google_bigquery_table.raw_film_permits.table_id}"
}
