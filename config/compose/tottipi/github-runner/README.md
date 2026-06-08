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

4. After the runner appears online in GitHub, remove **`RUNNER_TOKEN`** from `.env` (state lives in **`./data`**).

## Verify

```bash
docker ps --filter name=homelab-github-runner
docker logs homelab-github-runner --tail 20
```

## Related

- **`docs/ci-self-hosted-runner.md`** — CI workflow and tailnet SSH
- **`docs/tottipi-services.md`** — service catalog
