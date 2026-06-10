#!/usr/bin/env bash
# Graceful runner restart. Prefer this over `docker compose restart`.
#
# With persisted registration (./data), DISABLE_AUTOMATIC_DEREGISTRATION must stay
# true — the container cannot auto-deregister on stop. A hard restart leaves a ghost
# session on GitHub until it times out. This script stops cleanly, waits, then starts.
set -euo pipefail

cd "$(dirname "$0")"

STOP_TIMEOUT="${STOP_TIMEOUT:-30}"
SESSION_COOLDOWN="${SESSION_COOLDOWN:-15}"

echo "Stopping runner (timeout ${STOP_TIMEOUT}s)..."
docker compose stop -t "${STOP_TIMEOUT}"

echo "Waiting ${SESSION_COOLDOWN}s for GitHub to drop the old session..."
sleep "${SESSION_COOLDOWN}"

echo "Starting runner..."
docker compose up -d

echo
docker compose ps
echo
echo "Tail logs until you see 'Listening for Jobs':"
docker compose logs -f --tail 15
