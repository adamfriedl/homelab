resource "google_compute_network" "vpc_network" {
  name = var.network_name
}

resource "google_compute_firewall" "allow_ssh_ingress" {
  count = length(var.ssh_source_ranges) > 0 ? 1 : 0

  name    = var.firewall_name
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = var.ssh_target_tags
}

# IAP TCP forwarding to tagged instances (SSH). See:
# https://cloud.google.com/iap/docs/using-tcp-forwarding
resource "google_compute_firewall" "allow_ssh_via_iap" {
  count = var.enable_iap_ssh ? 1 : 0

  name    = var.iap_ssh_firewall_name
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.iap_forwarding_ipv4_range]
  target_tags   = var.ssh_target_tags
}
