resource "google_bigquery_dataset" "homelab" {
  project    = var.project_id
  dataset_id = var.dataset_id
  location   = var.location

  description = "Homelab analytics: NYC Open Data pipelines and observability tables."

  labels = {
    env     = "homelab"
    managed = "terraform"
  }
}

locals {
  raw_film_permits_schema = jsonencode([
    { name = "eventid", type = "STRING", mode = "REQUIRED" },
    { name = "eventtype", type = "STRING" },
    { name = "startdatetime", type = "TIMESTAMP" },
    { name = "enddatetime", type = "TIMESTAMP" },
    { name = "enteredon", type = "TIMESTAMP" },
    { name = "eventagency", type = "STRING" },
    { name = "parkingheld", type = "STRING" },
    { name = "borough", type = "STRING" },
    { name = "communityboard_s", type = "STRING" },
    { name = "policeprecinct_s", type = "STRING" },
    { name = "category", type = "STRING" },
    { name = "subcategoryname", type = "STRING" },
    { name = "country", type = "STRING" },
    { name = "zipcode_s", type = "STRING" },
    { name = "loaded_at", type = "TIMESTAMP", mode = "REQUIRED" },
  ])
}

resource "google_bigquery_table" "raw_film_permits" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.homelab.dataset_id
  table_id   = "raw_film_permits"

  description = "Film permits loaded from NYC Open Data (SODA tg4x-b46p)."

  time_partitioning {
    type  = "DAY"
    field = "startdatetime"
  }

  clustering = ["borough", "category"]

  schema = local.raw_film_permits_schema

  deletion_protection = false
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
