# IAP TCP forwarding (gcloud compute ssh --tunnel-through-iap).

resource "google_project_service" "iap" {
  count = var.enable_iap_ssh ? 1 : 0

  project = var.project_id
  service = "iap.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_iam_member" "iap_tunnel" {
  for_each = var.enable_iap_ssh ? toset(distinct(compact(var.iap_ssh_tunnel_members))) : toset([])

  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = each.value
}
