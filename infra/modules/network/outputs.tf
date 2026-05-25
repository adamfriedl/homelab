output "network_id" {
  description = "The VPC network identifier."
  value       = google_compute_network.vpc_network.id
}

output "network_name" {
  description = "The VPC network name."
  value       = google_compute_network.vpc_network.name
}

output "network_self_link" {
  description = "The VPC network self_link."
  value       = google_compute_network.vpc_network.self_link
}
