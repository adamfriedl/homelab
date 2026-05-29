output "instances" {
  description = "Created VMs keyed by instance name."
  value = {
    for name, inst in google_compute_instance.vm_instance : name => {
      name        = inst.name
      zone        = inst.zone
      external_ip = try(inst.network_interface[0].access_config[0].nat_ip, null)
      self_link   = inst.self_link
    }
  }
}

output "instance_names" {
  description = "GCP instance names (sorted)."
  value       = sort(keys(google_compute_instance.vm_instance))
}
