terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.33.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "network" {
  source = "./modules/network"

  network_name              = var.network_name
  region                    = var.region
  firewall_name             = var.firewall_name
  ssh_source_ranges         = var.ssh_source_ranges
  enable_iap_ssh            = var.enable_iap_ssh
  iap_ssh_firewall_name     = var.iap_ssh_firewall_name
  iap_forwarding_ipv4_range = var.iap_forwarding_ipv4_range
  enable_cloud_nat          = var.enable_cloud_nat

  depends_on = [google_project_service.compute]
}

module "vm" {
  source = "./modules/vm"

  network_name                      = module.network.network_name
  default_zone                      = var.zone
  default_machine_type              = var.machine_type
  default_boot_disk_image           = var.boot_disk_image
  default_enable_external_public_ip = var.enable_external_public_ip
  instances                         = var.instances
}
