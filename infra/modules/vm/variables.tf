variable "network_name" {
  description = "Name of an existing VPC network to attach instances to."
  type        = string
}

variable "default_zone" {
  description = "Default GCP zone when an instance omits zone."
  type        = string
}

variable "default_machine_type" {
  description = "Default machine type when an instance omits machine_type."
  type        = string
  default     = "e2-micro"
}

variable "default_boot_disk_image" {
  description = "Default boot disk image when an instance omits boot_disk_image."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "default_ssh_target_tags" {
  description = "Default network tags when an instance omits ssh_target_tags."
  type        = list(string)
  default     = ["ssh-access"]
}

variable "default_enable_external_public_ip" {
  description = "Default public IPv4 when an instance omits enable_external_public_ip."
  type        = bool
  default     = false
}

variable "instances" {
  description = "VMs to create. Map key = GCP instance name."
  type = map(object({
    zone                      = optional(string)
    machine_type              = optional(string)
    boot_disk_image           = optional(string)
    enable_external_public_ip = optional(bool)
    ssh_target_tags           = optional(list(string))
  }))
}
