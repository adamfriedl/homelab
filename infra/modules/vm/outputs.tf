output "instance_name" {
  description = "The Compute Engine VM name."
  value       = google_compute_instance.vm_instance.name
}

output "instance_external_ip" {
  description = "Ephemeral external IPv4 NAT address, if attached."
  value       = try(google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip, null)
}
