#!/usr/bin/env python3
"""
Ansible dynamic inventory from Terraform JSON outputs (`terraform output -json`).

Repo layout assumed:
    <repo>/config/inventory/terraform_inventory.py
    <repo>/infra/

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


def output_value(outputs: dict, key: str) -> str | None:
    blob = outputs.get(key)
    if blob is None or not isinstance(blob, dict):
        return None
    val = blob.get("value")
    if val is None or val == "":
        return None
    return str(val)


def build_inventory(outputs: dict) -> dict:
    keys = ("instance_name", "project_id", "zone")
    values: dict[str, str | None] = {k: output_value(outputs, k) for k in keys}
    missing = [k for k, v in values.items() if not v]

    if missing:
        sys.stderr.write(
            f"Terraform outputs missing ({', '.join(missing)}).\n"
            "Ensure infra has been applied and outputs exist (see infra/outputs.tf).\n"
        )
        sys.exit(1)

    host = values["instance_name"]
    assert host is not None  # narrowed by missing check

    return {
        "gcp_lab": {
            "hosts": [host],
            "vars": {
                "gcp_project_id": values["project_id"],
                "gcp_zone": values["zone"],
            },
        },
        "_meta": {"hostvars": {}},
    }


def main() -> None:
    # Ansible calls: --list  or  --host <hostname>
    if "--host" in sys.argv:
        json.dump({}, sys.stdout)
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
