output "instance_names" {
  description = "Compute Engine VM names — Ansible inventory hostnames when using IAP."
  value       = module.vm.instance_names
}

output "instances" {
  description = "VM name, zone, and optional external IP per instance."
  value       = module.vm.instances
}

output "project_id" {
  description = "GCP project ID passed into Terraform — consumed by Ansible dynamic inventory among other tooling."
  value       = var.project_id
}

output "zone" {
  description = "Default Compute Engine zone — per-host zone may differ; see instances output."
  value       = var.zone
}

output "vpc_network_self_link" {
  description = "Self link for the VPC used by the VMs."
  value       = module.network.network_self_link
}

output "ssh_via_iap_gcloud" {
  description = "Example IAP tunneled SSH commands per VM (active gcloud account, not ADC)."
  value = {
    for name, inst in module.vm.instances :
    name => format(
      "gcloud compute ssh %s --zone=%s --project=%s --tunnel-through-iap",
      inst.name,
      inst.zone,
      var.project_id,
    )
  }
}
