# Outbound HTTPS (apt, Tailscale installer, curl) requires SNAT unless the VM has a public IP.
# https://cloud.google.com/nat/docs/overview

resource "google_compute_router" "nat_router" {
  count = var.enable_cloud_nat ? 1 : 0

  name    = "${var.network_name}-nat-router"
  region  = var.region
  network = google_compute_network.vpc_network.id
}

resource "google_compute_router_nat" "internet" {
  count = var.enable_cloud_nat ? 1 : 0

  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.nat_router[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
