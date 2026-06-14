variable "project_id" {
  description = "GCP project ID used by the Google provider."
  type        = string

  validation {
    condition     = length(var.project_id) > 0 && !can(regex("^\\s*$", var.project_id))
    error_message = "project_id must be a non-empty string."
  }
}

variable "region" {
  description = "Default GCP region for regional resources."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Default GCP zone for zonal resources (e.g. compute instances)."
  type        = string
  default     = "us-central1-c"

  validation {
    condition     = strcontains(var.zone, var.region)
    error_message = "zone must be in the same region as var.region (e.g. region us-central1 -> zone us-central1-c)."
  }
}

variable "network_name" {
  description = "VPC name created by module.network."
  type        = string
  default     = "gcp-lab-network"
}

variable "firewall_name" {
  description = "Public Internet SSH ingress firewall rule name (skipped when ssh_source_ranges is empty)."
  type        = string
  default     = "gcp-lab-allow-ssh-ingress"
}

variable "ssh_source_ranges" {
  description = "CIDR blocks allowed to SSH VMs from the public Internet. Use [] for IAP-only private VMs."
  type        = list(string)
  default     = []
}

variable "enable_cloud_nat" {
  description = "Regional Cloud NAT for outbound internet from private VMs. Steady state: true. See docs/networking.md#terraform-knobs."
  type        = bool
  default     = true
}

variable "enable_iap_ssh" {
  description = "Creates a VPC firewall permitting SSH TCP from IAP's forwarding range."
  type        = bool
  default     = true
}

variable "iap_ssh_firewall_name" {
  description = "Name of the SSH firewall permitting IAP ingress."
  type        = string
  default     = "gcp-lab-allow-ssh-iap"
}

variable "iap_forwarding_ipv4_range" {
  description = "IAP TCP forwarding IPv4 range (GCP documented default)."
  type        = string
  default     = "35.235.240.0/20"
}

variable "iap_ssh_tunnel_members" {
  description = "IAM members granted roles/iap.tunnelResourceAccessor (e.g. user:you@example.com). Empty skips Terraform IAM (you can grant manually)."
  type        = list(string)
  default     = []
}

variable "enable_os_login" {
  description = "Enable OS Login project-wide and grant os_login_admin_members roles/compute.osAdminLogin (SSH + sudo)."
  type        = bool
  default     = true
}

variable "os_login_admin_members" {
  description = "IAM members granted roles/compute.osAdminLogin (SSH as a Linux user with sudo). Include CI service accounts used for Ansible."
  type        = list(string)
  default     = []
}

variable "enable_external_public_ip" {
  description = "Default ephemeral public IPv4 for instances that do not override it. Not required for gcloud compute ssh --tunnel-through-iap."
  type        = bool
  default     = false
}

variable "machine_type" {
  description = "Default Compute Engine machine type for instances that do not override it."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_image" {
  description = "Default boot disk image for instances that do not override it."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "instances" {
  description = "Compute Engine VMs to create. Map key = GCP instance name; unset fields inherit machine_type, boot_disk_image, enable_external_public_ip, and zone above."
  type = map(object({
    zone                      = optional(string)
    machine_type              = optional(string)
    boot_disk_image           = optional(string)
    enable_external_public_ip = optional(bool)
    ssh_target_tags           = optional(list(string))
  }))
  default = {
    "gcp-lab-1" = {}
  }
}
