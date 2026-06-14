variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "dataset_id" {
  description = "BigQuery dataset ID for homelab analytics tables."
  type        = string
}

variable "location" {
  description = "BigQuery dataset location (region or multi-region, e.g. US)."
  type        = string
  default     = "US"
}

variable "data_editor_members" {
  description = "IAM members granted roles/bigquery.dataEditor on the dataset (user:..., serviceAccount:...)."
  type        = list(string)
  default     = []
}

variable "job_user_members" {
  description = "IAM members granted roles/bigquery.jobUser at project scope (needed to run queries/loads)."
  type        = list(string)
  default     = []
}
