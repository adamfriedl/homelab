output "instance_name" {
  description = "Compute Engine VM name — use this as the Ansible inventory hostname when using IAP."
  value       = module.vm.instance_name
}

output "project_id" {
  description = "GCP project ID passed into Terraform — consumed by Ansible dynamic inventory among other tooling."
  value       = var.project_id
}

output "zone" {
  description = "Compute Engine zone for the VM — consumed by Ansible dynamic inventory among other tooling."
  value       = var.zone
}

output "instance_external_ip" {
  description = "Ephemeral IPv4 when enable_external_public_ip is true."
  value       = module.vm.instance_external_ip
}

output "vpc_network_self_link" {
  description = "Self link for the VPC used by the VM."
  value       = module.network.network_self_link
}

output "ssh_via_iap_gcloud" {
  description = "Example IAP tunneled SSH using your active gcloud account (not ADC)."
  value       = format("gcloud compute ssh %s --zone=%s --project=%s --tunnel-through-iap", module.vm.instance_name, var.zone, var.project_id)
}
