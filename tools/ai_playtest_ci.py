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
            time.sleep(0.35)
            return True
        time.sleep(0.25)
    return False


def wait_for_back_settle(package: str, timeout: float = 8.0) -> bool:
    """Return True if Back actually leaves RENEW after Android has settled.

    Root-activity completion on the API-34 swangle emulator can be delayed well
    after KEYCODE_BACK while RENEW still appears focused. Observe the entire settle
    window before deciding that Back stayed in-game; returning early reintroduces
    the exact Launcher/black-frame race this adapter is meant to exclude.
    """
    deadline = time.monotonic() + timeout
    saw_other_foreground = False

    while time.monotonic() < deadline:
        foreground = top_package()
        if foreground and foreground != package:
            saw_other_foreground = True
            break
        time.sleep(0.15)

    if saw_other_foreground:
        return True

    # Only classify this as an in-game Back after the full settling interval and a
    # final API-34 foreground check. Unknown focus is not treated as a safe state.
    foreground = top_package()
    return bool(foreground and foreground != package)


def install_synchronous_back_recovery(package: str) -> None:
    """Keep intentional root-Back exploration inside the game test boundary.

    Android normally finishes a root activity when Back is pressed. That is not a
    RENEW crash, but an asynchronous watchdog lets the next screenshot catch Pixel
    Launcher or gfxstream's black/portrait transition while the activity is being
    recreated. Intercept only the AI's explicit Back keyevent: if it actually leaves
    RENEW, relaunch and wait for a real rendered frame before the core tester samples
    feedback. Back actions that remain inside RENEW are untouched. Taps/swipes that
    unexpectedly leave the game still hit the existing foreground-loss gate.

    Also wait for the first real frame after the harness launches the APK. The API-34
    software renderer can take longer than the core tester's fixed launch sleep on a
    cold emulator. A timeout still falls through to the unchanged blank-screen gate.
    """
    original_adb = agent.adb

    def ci_adb(*args, **kwargs):
        result = original_adb(*args, **kwargs)

        is_launch = (
            len(args) >= 2
            and args[0] == "shell"
            and args[1] == "monkey"
            and "-p" in args
            and package in args
        )
        if is_launch:
            wait_for_game_frame(package, timeout=20.0)
            return result

        is_back = (
            len(args) >= 4
            and args[0] == "shell"
            and args[1] == "input"
            and args[2] == "keyevent"
            and str(args[3]) in {"4", "KEYCODE_BACK"}
        )
        if not is_back:
            return result

        if wait_for_back_settle(package):
            relaunch(package)
            wait_for_game_frame(package, timeout=20.0)
        return result

    agent.adb = ci_adb


def main() -> None:
    agent.wait_for_device()
    agent.adb(
        "shell", "settings", "put", "secure",
        "immersive_mode_confirmations", "confirmed",
        check=False,
    )

    package = requested_package()
    agent.display_size = rendered_display_size
    agent.foreground_package = top_package
    agent.run = robust_text_run
    install_synchronous_back_recovery(package)
    agent.main()


if __name__ == "__main__":
    main()
