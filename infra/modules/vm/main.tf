resource "google_compute_instance" "vm_instance" {
  for_each = var.instances

  name         = each.key
  machine_type = coalesce(each.value.machine_type, var.default_machine_type)
  zone         = coalesce(each.value.zone, var.default_zone)
  tags         = coalesce(each.value.ssh_target_tags, var.default_ssh_target_tags)

  boot_disk {
    initialize_params {
      image = coalesce(each.value.boot_disk_image, var.default_boot_disk_image)
    }
  }

  network_interface {
    network = var.network_name

    dynamic "access_config" {
      for_each = coalesce(each.value.enable_external_public_ip, var.default_enable_external_public_ip) ? [1] : []
      content {}
    }
  }
}
