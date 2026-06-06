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

output "github_actions_wif_owner_principal" {
  description = "WIF principal for GitHub Actions (owner scope). Verify with: gcloud iam service-accounts get-iam-policy CI_SA"
  value       = var.enable_github_actions_wif ? "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.github_wif_pool_id}/attribute.repository_owner/${var.github_repository_owner}" : null
}

output "github_actions_wif_repository_principal" {
  description = "WIF principal for GitHub Actions (single-repo scope)."
  value       = var.enable_github_actions_wif && var.github_repository != "" ? "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.github_wif_pool_id}/attribute.repository/${var.github_repository}" : null
}

output "github_actions_wif_subject_principals" {
  description = "WIF subject principals (pull_request + main push)."
  value = [
    for subject in local.github_wif_subjects :
    "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.github_wif_pool_id}/subject/${subject}"
  ]
}

output "github_actions_ci_service_account" {
  description = "Service account email GitHub Actions impersonates."
  value       = var.enable_github_actions_wif ? coalesce(var.ci_service_account_email, "terraform-ci@${var.project_id}.iam.gserviceaccount.com") : null
}
