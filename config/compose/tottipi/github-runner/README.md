# GitHub Actions runner on `tottipi`

Docker runner with **`network_mode: host`** so CI jobs use the Pi's Tailscale routes to SSH to **`gcp-lab-1`**.

## One-time registration

1. GitHub → **Settings → Actions → Runners → New self-hosted runner** → copy the registration token.
2. Create `.env` from `.env.example` and set **`RUNNER_TOKEN`** (gitignored locally).
3. Deploy from your laptop:

   ```bash
   cd config
   ansible-playbook site.yml --limit home_lab
   ```

   Ansible copies a local `.env` if present, or uses `.env` already on `tottipi`.

4. After the runner appears online in GitHub, remove **`RUNNER_TOKEN`** from `.env` on `tottipi` (state lives in **`./data`**, including hidden files like **`.runner`**).

## Verify

```bash
sudo docker ps --filter name=homelab-github-runner
sudo docker logs homelab-github-runner --tail 20
```

Logs should show **Listening for Jobs**. GitHub → **Settings → Actions → Runners** → **Idle**.

## Re-register (recovery)

Use when GitHub removed the runner, you see **session already exists**, or **registration has been deleted from the server**.

1. GitHub → **Settings → Actions → Runners** → remove **tottipi**.
2. GitHub → **New self-hosted runner** → copy a fresh **`RUNNER_TOKEN`** (expires quickly).
3. On **`tottipi`**:

   ```bash
   cd /opt/homelab/github-runner
   sudo docker compose down
   sudo rm -rf data/          # not data/* — dotfiles (.runner) survive data/*
   sudo mkdir data
   sudo nano .env             # set RUNNER_TOKEN=…
   sudo docker compose up -d
   sudo docker logs homelab-github-runner --tail 30 -f
   ```

4. After **Listening for Jobs**, clear the token and restart:

   ```bash
   sudo sed -i 's/^RUNNER_TOKEN=.*/RUNNER_TOKEN=/' .env
   sudo docker compose up -d
   ```

Use **`sudo docker compose`** — Ansible deploys **`.env`** as root-owned `0600`.

## Related

- **`docs/ci-self-hosted-runner.md`** — CI workflow and tailnet SSH
- **`docs/tottipi-services.md`** — service catalog
