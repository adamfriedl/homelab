# GitHub Actions runner on `tottipi`

Docker runner with **`network_mode: host`** so CI jobs use the Pi's Tailscale routes to SSH to **`gcp-lab-1`**.

## Image

Built locally from **`Dockerfile`** on top of `myoung34/github-runner:ubuntu-jammy`. Pre-installs **gcloud**, **Node 20**, **Terraform**, and **Ansible** so CI jobs do not bootstrap tools each run.

Ansible runs **`docker compose up -d --build`**. Rebuild after changing **`Dockerfile`**:

```bash
cd /opt/homelab/github-runner
sudo docker compose build --no-cache
sudo docker compose up -d
```

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

## Restart (routine)

Persisted registration requires `DISABLE_AUTOMATIC_DEREGISTRATION=true` — the runner keeps `./data` but cannot tell GitHub it left on a hard stop. **`docker compose restart` often causes "session already exists"** and jobs stuck queued.

Use the restart script instead:

```bash
cd /opt/homelab/github-runner
sudo ./restart.sh
```

Or manually: `docker compose stop -t 30`, wait ~15s, `docker compose up -d`.

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
   sudo docker compose up -d --build
   sudo docker logs homelab-github-runner --tail 30 -f
   ```

4. After **Listening for Jobs**, clear the token and restart:

   ```bash
   sudo sed -i 's/^RUNNER_TOKEN=.*/RUNNER_TOKEN=/' .env
   sudo docker compose up -d --build
   ```

Use **`sudo docker compose`** — Ansible deploys **`.env`** as root-owned `0600`.

## Related

- **`docs/ci-self-hosted-runner.md`** — CI workflow and tailnet SSH
- **`docs/tottipi-services.md`** — service catalog
