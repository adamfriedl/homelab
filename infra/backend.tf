terraform {
  backend "gcs" {
    bucket = "tech-study-gcp-lab-terraform-state"
    prefix = "dev"
  }
}
