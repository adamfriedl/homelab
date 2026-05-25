variable "project_id" {
  description = "GCP project ID used by the Google provider."
  type        = string
  default     = "tech-study-497214"

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
  default     = "tech-study-network"
}

variable "firewall_name" {
  description = "Public Internet SSH ingress firewall rule name (skipped when ssh_source_ranges is empty)."
  type        = string
  default     = "tech-study-allow-ssh-ingress"
}

variable "ssh_source_ranges" {
  description = "CIDR blocks allowed to SSH VMs from the public Internet. Use [] together with IAP (private IP VMs require IAP or Tailscale)."
  type        = list(string)
  default     = []
}

variable "enable_iap_ssh" {
  description = "Creates a VPC firewall permitting SSH TCP from IAP's forwarding range."
  type        = bool
  default     = true
}

variable "iap_ssh_firewall_name" {
  description = "Name of the SSH firewall permitting IAP ingress."
  type        = string
  default     = "tech-study-allow-ssh-iap"
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

variable "enable_external_public_ip" {
  description = "Ephemeral public IPv4 on the VM. Not required for gcloud compute ssh --tunnel-through-iap."
  type        = bool
  default     = false
}

variable "instance_name" {
  description = "Compute Engine VM name."
  type        = string
  default     = "tech-study-instance"
}

variable "machine_type" {
  description = "Compute Engine machine type."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_image" {
  description = "Boot disk image."
  type        = string
  default     = "debian-cloud/debian-11"
}
