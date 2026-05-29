# `config/` — Ansible

Ansible drives the GCP VM Terraform creates under **`infra/`**. With the default IAP-only stance (no public IP), **`gcloud`** must be on your **`PATH`** and **`gcloud auth login`** (or equivalent) must work — same expectation as **`gcloud compute ssh --tunnel-through-iap`**.

## How inventory lines up with Terraform

**Inventory is dynamic:** `inventory/terraform_inventory.py` runs **`terraform output -json`** against **`../infra/`** (configurable override below). It emits the **`gcp_lab`** group with:

- **`gcp_project_id`** from Terraform (**`project_id`** in **`infra/outputs.tf`**).
- One host per VM from **`instance_names`** (each host gets **`gcp_zone`** in host vars from **`instances`**).

Keep **`infra/` applied** at least once so those outputs exist. After you change **`instances`** / **`project_id`** / **`zone`** and **`terraform apply`**, Ansible picks up new hosts automatically — **no Ansible inventory edits.**

**Manual override:** if Terraform lives elsewhere:

```bash
export GCP_LAB_TERRAFORM_DIR=/absolute/path/to/infra
ansible-inventory --list    # cwd = config/
```

## One-time wiring

1. **OS Login + IAP SSH** — after **`terraform apply`** enables OS Login and grants **`roles/compute.osAdminLogin`**:

   ```bash
   gcloud compute os-login ssh-keys add --key-file=~/.ssh/google_compute_engine.pub
   gcloud compute os-login describe-profile --format='value(posixAccounts[0].username)'
   # Set ansible_user in iap_ssh.yml to that username (Gmail: typically you_gmail_com).
   ```

   **`~/.ssh/google_compute_engine`** is still the private key Ansible uses; the public half lives on your **OS Login profile**. Plain **`ssh`** through the IAP **`ProxyCommand`** without that key yields **`Permission denied (publickey)`**.

   If that fails, fix IAP / OS Login IAM / firewall before Ansible.

2. **`Remote user` + sudo:** The play uses **`become: true`**, so Ansible needs a user that can escalate to root (APT, **`tailscale`**, **`systemd`**). That is often the same OS Login / SSH user as **`gcloud compute ssh`** — set **`ansible_user`** in **`inventory/group_vars/gcp_lab/iap_ssh.yml`** or **`-u`** if needed. Use passwordless sudo on the VM, or **`ansible-playbook --ask-become-pass`**.

## Run

Working directory **`config/`** (loads **`ansible.cfg`**):

```bash
ansible-playbook site.yml   # picks up tailscale_secrets.yml automatically if that file exists
```

Quick check (`ansible.cfg` inventory is used):

```bash
ansible gcp_lab -m ping
```

Debug inventory:

```bash
ansible-inventory --list --yaml
```

### Inventory without Terraform on this laptop

Inventory still comes from **`terraform output`** (see **`GCP_LAB_TERRAFORM_DIR`** above). If you refuse to install Terraform locally, hand‑write **`inventory/group_vars`** + a small static inventory (**`-i`**) yourself; keep that out of repo if it’s noisy.

## Tailscale (optional join to your tailnet)

Outbound install requires the VM reach **`pkgs.tailscale.com`**. IAP-only VMs have **no public IP** unless you **`enable_external_public_ip`** — **`infra`** defaults **`enable_cloud_nat = true`** (Cloud Router/NAT module) after **`terraform apply`**. Without NAT or another egress path you see **`Network is unreachable`** during **`ansible.builtin.get_url`** / **`apt`**.

The **`tailscale`** role installs from Tailscale’s APT repo on Debian/Ubuntu and joins using **`tailscale up --auth-key=…`** ([auth key docs](https://tailscale.com/docs/features/access-control/auth-keys#register-a-node-with-the-auth-key)). The join task uses **`no_log`** so Ansible omits output; if **`tailscale_auth_key`** is empty or unset, the role is skipped and **`site.yml`** still succeeds.

**Vars load automatically:** put Tailscale overrides in **`inventory/group_vars/gcp_lab/tailscale_secrets.yml`** (gitignored). Ansible merges **`inventory/group_vars/gcp_lab/*.yml`** for group **`gcp_lab`** whenever you **`ansible-playbook site.yml`** — nothing to pass **`-e @...`** unless you prefer it.

Copy the example:

```bash
cp inventory/group_vars/gcp_lab/tailscale_secrets.yml.example \
   inventory/group_vars/gcp_lab/tailscale_secrets.yml
```

1. In [Tailscale admin → Keys](https://login.tailscale.com/admin/settings/keys), create a **reusable** auth key tagged how your ACL expects (or untagged for simple labs). Paste **`tskey-auth-…`** into **`tailscale_secrets.yml`**.

2. If you use **`tailscale_advertise_tags`**, your Tailscale ACL must **allow tags** such as **`tag:gcp-lab`** for that key/device.

You can instead pass **`-e @path/to/secrets.yml`** or **`-e tailscale_auth_key=…`**; that overrides merges at higher precedence — handy for CI.

Re-runs **`tailscale up`** when already authenticated to apply prefs so flags like **`tailscale_enable_ssh_server`** (**`--ssh`**) take effect on machines that were already enrolled.

### Exit node (optional — off by default)

**Default is no exit node** — outbound internet uses **Cloud NAT** (Terraform). Set **`tailscale_exit_node`** (e.g. **`apple-tv`**) only if you want egress via home; that **breaks IAP/gcloud SSH** on the VM (use **`tailscale ssh`** instead).

After the VM joins, the role optionally **resolves the hostname** from **`tailscale status --json`** (same peer list the CLI uses) and runs **`tailscale set --exit-node=…`**. **`accept-routes`** is turned on automatically when an exit node is configured.

Manual lookup from any machine on your tailnet (e.g. your Mac):

```bash
tailscale status --json | jq -r '.Peer[] | select(.HostName=="apple-tv") | .TailscaleIPs[0]'
# → 100.119.241.51
```

Or pin the IP and skip lookup: **`tailscale_exit_node: "100.119.241.51"`** and **`tailscale_exit_node_resolve: false`**.

**IAP + exit node:** turning on an exit node changes the VM’s default route. That can **drop an in-flight Ansible SSH session** (you may see **`unreachable`** on the last task even though join succeeded). The role **defers** **`tailscale set --exit-node=…`** by a few seconds so the play can finish; re-run **`ansible gcp_lab -m ping`** afterward to confirm IAP still works.

### Tailscale SSH (`tailscale ssh`)

With **`tailscale_enable_ssh_server: true`** (default in **`roles/tailscale/defaults/main.yml`**), Ansible adds **`tailscale up --ssh`** (first enroll) or applies **`tailscale up ... --ssh`** on nodes already logged in, so you can use:

```bash
tailscale ssh your_linux_user@<tailscale-hostname-or-magicdns-name>
```

from any node signed into the same tailnet (your laptop qualifies once Tailscale runs there). The Linux account you SSH as is still whatever exists on the VM (often the same **`ansible_user`** you use over IAP/OpenSSH).

You must **[allow Tailscale SSH in ACLs]** per [Tailscale SSH doc](https://tailscale.com/kb/1193/tailscale-ssh) (**`grant`** **`ssh`** rules). Without that, **`tailscale ssh`** is rejected even though the daemon is listening.

Disable with **`tailscale_enable_ssh_server: false`**: the role runs **`tailscale set --ssh=false`** on nodes already logged in (**`tailscale up`** alone may keep SSH on).

## Layout

| Path | Role |
|------|------|
| **`ansible.cfg`** | **`inventory`** = Terraform-backed script |
| **`inventory/terraform_inventory.py`** | Executable: **`terraform output -json`** → Ansible JSON |
| **`inventory/group_vars/gcp_lab/iap_ssh.yml`** | IAP `ProxyCommand`; optional **`ansible_user`** |
| **`inventory/group_vars/gcp_lab/tailscale_secrets.yml.example`** | Copied → **`tailscale_secrets.yml`** next to it (ignored by Git); auto-loaded when present |
| **`site.yml`** | Entry playbook |
| **`roles/common`** | Starter role (baseline sanity tasks) |
| **`roles/tailscale`** | Optional install + join (needs **`tailscale_auth_key`** from **`tailscale_secrets.yml`** or **`--extra-vars`**) |

## Secrets / Vault

Keep **`tskey`** out of Git: **`inventory/group_vars/gcp_lab/tailscale_secrets.yml`** is ignored — Ansible merges it alongside **`iap_ssh.yml`** for **`gcp_lab`**. Optionally Ansible Vault‑encrypt **`tailscale_secrets.yml`** for defense in depth.
