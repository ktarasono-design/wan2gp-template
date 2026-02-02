#!/usr/bin/env python3
"""Clone Wan2GP repository and apply patches"""

import os
import subprocess
import sys

WAN2GP_REPO = os.getenv("WAN2GP_REPO", "https://github.com/deepbeepmeep/Wan2GP.git")
WAN2GP_DIR = "/opt/Wan2GP"


def run_cmd(cmd, check=True):
    print(f"Running: {cmd}")
    subprocess.run(cmd, shell=True, check=check)


def main():
    os.makedirs(WAN2GP_DIR, exist_ok=True)

    if not os.listdir(WAN2GP_DIR):
        run_cmd(f"git clone {WAN2GP_REPO} {WAN2GP_DIR}")

    motion_encoder = os.path.join(WAN2GP_DIR, "models/wan/animate/motion_encoder.py")
    if os.path.exists(motion_encoder):
        with open(motion_encoder, "r") as f:
            content = f.read()
        content = content.replace(
            "torch.cuda.amp.autocast(", "torch.amp.autocast('cuda', "
        )
        with open(motion_encoder, "w") as f:
            f.write(content)
        print(f"Patched {motion_encoder}")


if __name__ == "__main__":
    main()
