#!/usr/bin/env python3
"""
Ansible dynamic inventory from Terraform JSON outputs (`terraform output -json`).

Repo layout assumed:
    <repo>/config/inventory/terraform_inventory.py
    <repo>/infra/

Hosts are grouped under **`gcp_lab`** (child of **`lab`**).

Override:
    export GCP_LAB_TERRAFORM_DIR=/absolute/path/to/infra
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


def infra_path() -> Path:
    explicit = os.environ.get("GCP_LAB_TERRAFORM_DIR")
    if explicit:
        return Path(explicit).expanduser().resolve()

    repo_root = Path(__file__).resolve().parents[2]
    return (repo_root / "infra").resolve()


def terraform_outputs(tf_dir: Path) -> dict:
    proc = subprocess.run(
        ["terraform", f"-chdir={tf_dir}", "output", "-json"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr or proc.stdout or "terraform output failed\n")
        sys.exit(1)

    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"Invalid terraform JSON output: {exc}\n")
        sys.exit(1)


def output_value(outputs: dict, key: str):
    blob = outputs.get(key)
    if blob is None or not isinstance(blob, dict):
        return None
    return blob.get("value")


def instance_hosts(outputs: dict) -> list[str]:
    names = output_value(outputs, "instance_names")
    if isinstance(names, list) and names:
        return [str(n) for n in names]

    # Legacy single-VM output (pre instance_names).
    single = output_value(outputs, "instance_name")
    if single:
        return [str(single)]

    return []


def instance_zones(outputs: dict, hosts: list[str], default_zone: str | None) -> dict[str, str]:
    instances = output_value(outputs, "instances")
    hostvars: dict[str, str] = {}

    if isinstance(instances, dict):
        for name, meta in instances.items():
            if not isinstance(meta, dict):
                continue
            zone = meta.get("zone")
            if zone:
                hostvars[str(name)] = str(zone)

    if default_zone:
        for host in hosts:
            hostvars.setdefault(host, default_zone)

    return hostvars


def build_inventory(outputs: dict) -> dict:
    project_id = output_value(outputs, "project_id")
    default_zone = output_value(outputs, "zone")
    hosts = instance_hosts(outputs)

    missing: list[str] = []
    if not project_id:
        missing.append("project_id")
    if not hosts:
        missing.append("instance_names (or legacy instance_name)")

    if missing:
        sys.stderr.write(
            f"Terraform outputs missing ({', '.join(missing)}).\n"
            "Ensure infra has been applied and outputs exist (see infra/outputs.tf).\n"
        )
        sys.exit(1)

    zone_by_host = instance_zones(outputs, hosts, str(default_zone) if default_zone else None)

    hostvars = {
        host: {"gcp_zone": zone_by_host[host]}
        for host in hosts
        if host in zone_by_host
    }

    return {
        "lab": {
            "children": ["gcp_lab"],
        },
        "gcp_lab": {
            "hosts": hosts,
            "vars": {
                "gcp_project_id": str(project_id),
            },
        },
        "_meta": {"hostvars": hostvars},
    }


def main() -> None:
    # Ansible calls: --list  or  --host <hostname>
    if "--host" in sys.argv:
        idx = sys.argv.index("--host")
        hostname = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else None
        inv = build_inventory(terraform_outputs(infra_path()))
        hostvars = inv.get("_meta", {}).get("hostvars", {})
        payload = hostvars.get(hostname, {}) if hostname else {}
        json.dump(payload, sys.stdout)
        sys.stdout.write("\n")
        return

    if "--list" in sys.argv:
        inv = build_inventory(terraform_outputs(infra_path()))
        json.dump(inv, sys.stdout)
        sys.stdout.write("\n")
        return

    sys.stderr.write("Usage:terraform_inventory.py --list | terraform_inventory.py --host <name>\n")
    sys.exit(64)


if __name__ == "__main__":
    main()
