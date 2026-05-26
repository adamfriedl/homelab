# Required before VPC, firewall, NAT, and Compute Engine instances.

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}
