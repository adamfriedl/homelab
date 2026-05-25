# `gcp-lab`

Personal GCP lab repo: **`infra/`** (Terraform today) + **`config/`** (Ansible/playbooks soon). **Git root is this folder**, so commits include both trees.

## Layout

| Path        | Purpose |
|------------|---------|
| **`infra/`** | Terraform provider, modules (`network`, `vm`), IAP project bits, **`terraform init|plan|apply` run here**. |
| **`config/`** | Ansible and related bootstrap (see **`config/README.md`**). |

## Terraform quick start

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # edit project / IAP principals
terraform init
terraform plan
```

## Repo layout vs “nested git inside `infra/` only”

**`.git` lives at `gcp-lab/`** so Ansible under **`config/`** is tracked in one place. Keeping a **separate** repo only inside **`infra/`** would exclude **`config/`** unless you submodule or symlink—fine for enterprises, clumsy for a small lab.

## Shared VPC snapshot (advanced)

Older two-project layouts may still exist only on **`lab/shared-vpc`** in Git history — paths there may not match this `infra/` tree until rebased/cherry-picked. Default **`main`** is single-project Terraform under **`infra/`**.

## Move-in checklist (from `~/forge/tech-study/infra/`)

If you still had an older folder with `.git`:

```bash
# One-time: lift git to monorepo root (from parent of infra)
mv ~/forge/tech-study/infra/.git ~/forge/tech-study/gcp-lab/.git
rm -rf ~/forge/tech-study/infra   # only after confirming gcp-lab tracks everything you need
cd ~/forge/tech-study/gcp-lab
git status
```

If **`gcp-lab`** already has **`infra/`** and no `.git` yet, **`git clone`** your remote into **`gcp-lab`** instead, or run **`git init`** here.
