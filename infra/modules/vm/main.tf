resource "google_compute_instance" "vm_instance" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.ssh_target_tags

  boot_disk {
    initialize_params {
      image = var.boot_disk_image
    }
  }

  network_interface {
    network = var.network_name

    dynamic "access_config" {
      for_each = var.enable_external_public_ip ? [1] : []
      content {}
    }
  }
}
