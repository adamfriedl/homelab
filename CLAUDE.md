# CLAUDE.md

Personal GCP lab. `infra/` (Terraform) and `config/` (Ansible) are the platform; `pipelines/` (Airflow + SQL) is the application layer and is not built or deployed by CI. Start with `README.md` and `docs/repo-layout.md`.

## Merging to main changes real infrastructure

`plan-and-apply.yml` runs `terraform apply -auto-approve` and an Ansible converge on every push to `main` that touches `infra/`, `config/`, or the workflow itself. Treat any change there as a production change:

- Never run `terraform apply`, `terraform destroy`, or a non-`--syntax-check` `ansible-playbook` yourself.
- State in the PR what the change will create, modify, or destroy, and call out anything that replaces a resource.
- Don't edit IAM lists or WIF/bootstrap bindings unless the issue asks for it (see `docs/ci.md`).

## Verify

```bash
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra init -backend=false && terraform -chdir=infra validate
cd config && ansible-playbook site.yml --syntax-check
```

A real `terraform plan` needs GCP credentials. In `@claude` Actions runs there are none, so run the checks above and say the plan still needs to be reviewed.

PRs opened automatically by the Claude workflow don't trigger `plan-and-apply.yml` on open (GitHub doesn't fire workflows for PRs created with `github.token`); the plan runs on the next push to the PR branch.

## Secrets

`infra/terraform.tfvars`, state, and credentials stay out of git. CI auth is Workload Identity Federation — no keys in the repo.
