variable "network_name" {
  description = "Name of the VPC network."
  type        = string
  default     = "terraform-network"
}

variable "firewall_name" {
  description = "Name of the SSH ingress firewall rule."
  type        = string
  default     = "terraform-allow-ssh-ingress"
}

variable "ssh_source_ranges" {
  description = "CIDR blocks allowed to reach SSH on instances over the public Internet. Leave empty [] to omit this rule (IAP-only is common)."
  type        = list(string)
}

variable "ssh_target_tags" {
  description = "Network tags that receive SSH from ssh_source_ranges."
  type        = list(string)
  default     = ["ssh-access"]
}

variable "enable_iap_ssh" {
  description = "If true, create a firewall permitting SSH via Identity-Aware Proxy TCP forwarding."
  type        = bool
  default     = true
}

variable "iap_ssh_firewall_name" {
  description = "Name of the SSH firewall rule permitting IAP ingress."
  type        = string
  default     = "terraform-allow-ssh-iap"
}

variable "iap_forwarding_ipv4_range" {
  description = "IP range Google's IAP forwarding path uses for TCP (documented GCP range)."
  type        = string
  default     = "35.235.240.0/20"
}
