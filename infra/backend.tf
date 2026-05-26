terraform {
  # Bucket must exist in this GCP project (or wherever you host state). Name is globally unique.
  backend "gcs" {
    bucket = "gcp-lab-tf-state"
    prefix = "dev"
  }
}
