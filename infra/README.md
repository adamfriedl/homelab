# Terraform (`infra/`)

Run Terraform **from this directory**:

```bash
cd infra
terraform init
terraform plan
```

## Networking defaults

| Variable | Typical value | Meaning |
|----------|---------------|---------|
| **`enable_external_public_ip`** | `false` | VM has private IP only |
| **`enable_cloud_nat`** | `false` (steady state) | No ~$30/mo NAT gateway |

With both false, the VM has **no general internet egress**. Tailscale mesh and IAP admin still work.

**Bootstrap a fresh VM:** set **`enable_cloud_nat = true`**, **`terraform apply`**, run Ansible (**`config/`**), join Tailscale, then set **`enable_cloud_nat = false`** and apply again.

**IAM in `terraform.tfvars`:** include both your user and the CI service account in **`iap_ssh_tunnel_members`** and **`os_login_admin_members`** so Terraform does not remove bindings on apply.

**GitHub Actions WIF:** CI impersonates **`terraform-ci@PROJECT.iam.gserviceaccount.com`** via Workload Identity Federation. After changing the GitHub repo name, apply **`github_wif.tf`** once from your laptop:

```bash
cd infra
# Pool id = segment after workloadIdentityPools/ in GCP_WORKLOAD_IDENTITY_PROVIDER
# (the next CI run also prints this as "Parsed WIF pool id ...")
terraform apply -var='github_wif_pool_id=YOUR-POOL-ID'
terraform output github_actions_wif_subject_principals
gcloud iam service-accounts get-iam-policy "$(terraform output -raw github_actions_ci_service_account)"
```

**Common gotcha:** the default **`github_wif_pool_id = "github"`** is often wrong. If local apply "succeeds" but CI still fails, you created bindings on the wrong pool. Re-apply with the pool id from your **`GCP_WORKLOAD_IDENTITY_PROVIDER`** secret or from the CI log line **`Parsed WIF pool id`**.

**PR vs push:** pull request workflows use OIDC subject **`repo:owner/name:pull_request`**, not the same as push-to-main. **`github_wif.tf`** includes explicit subject bindings for both.

Use **`terraform.tfvars.example`** as the template (**`terraform.tfvars`** is gitignored).

See repository **`README.md`** for the full homelab layout.
