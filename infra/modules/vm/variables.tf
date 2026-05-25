variable "network_name" {
  description = "Name of an existing VPC network to attach this instance to."
  type        = string
}

variable "zone" {
  description = "GCP zone for the Compute Engine instance."
  type        = string
}

variable "instance_name" {
  description = "Name of the Compute Engine VM."
  type        = string
  default     = "terraform-instance"
}

variable "machine_type" {
  description = "GCP machine type for the VM."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_image" {
  description = "Boot disk image family or image self link."
  type        = string
  default     = "debian-cloud/debian-11"
}

variable "ssh_target_tags" {
  description = "Network tags for the instance (matched by firewall rules in the VPC)."
  type        = list(string)
  default     = ["ssh-access"]
}

variable "enable_external_public_ip" {
  description = "If true, allocate an ephemeral public IPv4 (not needed for gcloud --tunnel-through-iap)."
  type        = bool
  default     = false
}
