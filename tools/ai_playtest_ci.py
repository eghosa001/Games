#!/usr/bin/env python3
"""CI adapter for the RENEW Android AI playtester.

The Android emulator reports its physical display as portrait even when the Godot
activity is locked to landscape. The core playtester historically used that
physical size for input coordinates, which can put taps outside the rendered
2400x1080 surface. CI also shows Android's one-time immersive-mode education
overlay on a fresh emulator. This adapter removes both emulator-only sources of
noise without weakening any AI findings or thresholds.
"""

from __future__ import annotations

import io
import subprocess

from PIL import Image

import ai_playtest as agent


def rendered_display_size() -> tuple[int, int]:
    """Return the dimensions of the surface ADB actually captures."""
    proc = subprocess.run(
        ["adb", "exec-out", "screencap", "-p"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
        timeout=30,
    )
    with Image.open(io.BytesIO(proc.stdout)) as image:
        return image.size


def main() -> None:
    # A fresh emulator otherwise puts a system-owned "Viewing full screen"
    # education dialog over the game and the vision agent tests that dialog.
    agent.wait_for_device()
    agent.adb(
        "shell", "settings", "put", "secure",
        "immersive_mode_confirmations", "confirmed",
        check=False,
    )

    # Use the currently rendered orientation for all generated input coordinates.
    # The underlying playtester still performs every visual/runtime gate unchanged.
    agent.display_size = rendered_display_size
    agent.main()


if __name__ == "__main__":
    main()
