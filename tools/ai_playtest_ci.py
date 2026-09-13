#!/usr/bin/env python3
"""CI adapter for the RENEW Android AI playtester.

The Android emulator can report physical dimensions and foreground activity state
in forms that differ from the rendered Godot surface and from older Android API
levels. This adapter removes emulator-only sources of noise without weakening any
AI findings or thresholds.
"""

from __future__ import annotations

import io
import re
import subprocess
import sys
import time

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


def robust_text_run(cmd, check=True, capture=True, timeout=120):
    """Run text-producing commands without crashing on malformed logcat bytes."""
    kwargs = {
        "text": True,
        "encoding": "utf-8",
        "errors": "replace",
        "timeout": timeout,
        "check": check,
    }
    if capture:
        kwargs.update(stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    proc = subprocess.run(cmd, **kwargs)
    return proc.stdout.strip() if capture else ""


def requested_package() -> str:
    try:
        return sys.argv[sys.argv.index("--package") + 1]
    except (ValueError, IndexError):
        return "com.eghosa.renew"


def top_package() -> str:
    """Resolve the actually focused/resumed package across Android dump formats."""
    # Android 14's window record is the most reliable source on the API-34
    # emulator. Example:
    # mCurrentFocus=Window{... u0 com.google.android.apps.nexuslauncher/...}
    out = robust_text_run(
        ["adb", "shell", "dumpsys", "window", "windows"],
        check=False,
        timeout=20,
    )
    patterns = (
        r"mCurrentFocus=Window\{[^}]*?\s(?:u\d+\s+)?([\w.]+)/",
        r"mFocusedApp=.*?\s(?:u\d+\s+)?([\w.]+)/",
    )
    for pattern in patterns:
        match = re.search(pattern, out)
        if match:
            return match.group(1)

    out = robust_text_run(
        ["adb", "shell", "dumpsys", "activity", "activities"],
        check=False,
        timeout=20,
    )
    patterns = (
        r"topResumedActivity=.*?\s(?:u\d+\s+)?([\w.]+)/",
        r"mResumedActivity:.*?\s(?:u\d+\s+)?([\w.]+)/",
        r"ResumedActivity:.*?\s(?:u\d+\s+)?([\w.]+)/",
    )
    for pattern in patterns:
        match = re.search(pattern, out)
        if match:
            return match.group(1)

    out = robust_text_run(
        ["adb", "shell", "dumpsys", "activity", "top"],
        check=False,
        timeout=20,
    )
    match = re.search(r"^ACTIVITY\s+([\w.]+)/", out, re.MULTILINE)
    return match.group(1) if match else ""


def relaunch(package: str) -> None:
    robust_text_run(
        [
            "adb", "shell", "monkey", "-p", package,
            "-c", "android.intent.category.LAUNCHER", "1",
        ],
        check=False,
        timeout=30,
    )


def captured_frame_ready(package: str) -> bool:
    """Require RENEW to be focused with a nonblank landscape frame."""
    if top_package() != package:
        return False
    try:
        proc = subprocess.run(
            ["adb", "exec-out", "screencap", "-p"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
            timeout=30,
        )
        with Image.open(io.BytesIO(proc.stdout)) as image:
            rgb = image.convert("RGB")
            # RENEW is landscape. Android briefly rotates through portrait while a
            # killed root activity is recreated, and gfxstream can emit a pure-black
            # transition frame during that rotation. Neither is a playable frame.
            if rgb.width <= rgb.height:
                return False
            sample = rgb.resize((32, 18))
            extrema = sample.getextrema()
            dynamic_range = max(high for _, high in extrema) - min(low for low, _ in extrema)
            brightness = sum(sum(channel) for channel in sample.getdata()) / (32 * 18 * 3)
            return brightness >= 3.0 and dynamic_range > 2
    except Exception:
        return False


def wait_for_game_frame(package: str, timeout: float = 12.0) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if captured_frame_ready(package):
            # One extra compositor beat prevents sampling the first just-created
            # buffer while orientation settles on the headless emulator.
            time.sleep(0.35)
            return True
        time.sleep(0.25)
    return False


def install_synchronous_back_recovery(package: str) -> None:
    """Keep intentional root-Back exploration inside the game test boundary.

    Android normally finishes a root activity when Back is pressed. That is not a
    RENEW crash, but an asynchronous watchdog lets the next screenshot catch Pixel
    Launcher or gfxstream's black/portrait transition while the activity is being
    recreated. Intercept only the AI's explicit Back keyevent: if it actually leaves
    RENEW, relaunch and wait for a real rendered frame before the core tester samples
    feedback. Back actions that remain inside RENEW are untouched. Taps/swipes that
    unexpectedly leave the game still hit the existing foreground-loss gate.
    """
    original_adb = agent.adb

    def ci_adb(*args, **kwargs):
        result = original_adb(*args, **kwargs)
        is_back = (
            len(args) >= 4
            and args[0] == "shell"
            and args[1] == "input"
            and args[2] == "keyevent"
            and str(args[3]) in {"4", "KEYCODE_BACK"}
        )
        if not is_back:
            return result

        time.sleep(0.30)
        foreground = top_package()
        if foreground and foreground != package:
            relaunch(package)
            wait_for_game_frame(package)
        return result

    agent.adb = ci_adb


def main() -> None:
    # A fresh emulator otherwise puts a system-owned "Viewing full screen"
    # education dialog over the game and the vision agent tests that dialog.
    agent.wait_for_device()
    agent.adb(
        "shell", "settings", "put", "secure",
        "immersive_mode_confirmations", "confirmed",
        check=False,
    )

    package = requested_package()

    # Use the currently rendered orientation for generated input coordinates.
    agent.display_size = rendered_display_size

    # Use the API-34-aware detector for report evidence.
    agent.foreground_package = top_package

    # Some Android/emulator logcat records contain malformed UTF-8. Preserve every
    # byte as replacement text instead of aborting the entire test harness while
    # leaving all AI detection logic and thresholds unchanged.
    agent.run = robust_text_run

    # Root Back is an intentional exploration action. Recover synchronously only
    # when that Back truly exits the root activity, so screenshots are never taken
    # from Pixel Launcher or from the compositor's relaunch transition.
    install_synchronous_back_recovery(package)

    agent.main()


if __name__ == "__main__":
    main()
