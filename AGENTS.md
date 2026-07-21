# AGENTS.md

Repo-specific guidance for AI coding agents. Cross-repo Definition of Done: Cursor rule `forge-agent-dod` + `verify` skill.

## What this repo is

Personal GCP lab: **platform** (Terraform + Ansible) and **applications** (Airflow pipelines → BigQuery). See `docs/repo-layout.md`.

## Stack conventions

- `infra/` — Terraform (VPC, VM, BigQuery, IAM). Local `terraform.tfvars` is gitignored; CI writes its own.
- `config/` — Ansible converge on VMs.
- `pipelines/` — Airflow DAGs + SQL; use curated BQ layers, not ad-hoc prod inventiveness.
- Boundary: `infra/` = where data lives; `pipelines/` = what you do with it.

## Verify

```bash
# Terraform (from infra/)
terraform fmt -check && terraform validate
# Ansible (from config/)
ansible-playbook --syntax-check site.yml
# Prefer CI path on PRs: .github/workflows/plan-and-apply.yml
```

## Gotchas

- CI only applies on `main` (and plans on PRs touching `infra/**` / `config/**`) — see `docs/ci.md`.
- Don't commit `terraform.tfvars`, credentials, or state.
