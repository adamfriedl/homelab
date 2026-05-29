# OS Login: SSH Linux user + sudo via IAM (roles/compute.osAdminLogin) instead of project metadata keys.

resource "google_project_service" "oslogin" {
  count = var.enable_os_login ? 1 : 0

  project = var.project_id
  service = "oslogin.googleapis.com"

  disable_on_destroy = false
}

resource "google_compute_project_metadata_item" "enable_oslogin" {
  count = var.enable_os_login ? 1 : 0

  project = var.project_id
  key     = "enable-oslogin"
  value   = "TRUE"

  depends_on = [google_project_service.oslogin]
}

resource "google_project_iam_member" "os_login_admin" {
  for_each = var.enable_os_login ? toset(distinct(compact(var.os_login_admin_members))) : toset([])

  project = var.project_id
  role    = "roles/compute.osAdminLogin"
  member  = each.value
}
