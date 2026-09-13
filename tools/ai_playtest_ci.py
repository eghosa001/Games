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


def wait_for_game_frame(package: str, timeout: float = 12.0, stable_for: float = 0.75) -> bool:
    """Wait until RENEW has continuously rendered usable frames for ``stable_for``."""
    deadline = time.monotonic() + timeout
    stable_since = None
    while time.monotonic() < deadline:
        now = time.monotonic()
        if captured_frame_ready(package):
            if stable_since is None:
                stable_since = now
            elif now - stable_since >= stable_for:
                return True
        else:
            stable_since = None
        time.sleep(0.25)
    return False


def settle_after_back(
    package: str,
    timeout: float = 24.0,
    minimum_observe: float = 12.0,
    stable_for: float = 2.0,
) -> bool:
    """Recover a root Back and return only after the game surface is truly stable.

    On the API-34 swangle runner Android can continue reporting the Godot activity as
    focused for several seconds after KEYCODE_BACK, then tear down its process/surface.
    A foreground-only check therefore races the compositor: the core AI can capture a
    black ColorBuffer transition even though the game neither crashed nor rendered a
    black game state. Observe the full delayed-finish window, relaunch whenever another
    package really becomes foreground, and require continuously usable RENEW frames
    before letting the core tester sample feedback.

    This does not suppress a persistent in-game black screen: if RENEW remains focused
    but fails to render usable frames, this function times out and the unchanged core
    blank-screen gate sees that frame normally.
    """
    started = time.monotonic()
    deadline = started + timeout
    stable_since = None

    while time.monotonic() < deadline:
        now = time.monotonic()
        foreground = top_package()

        if foreground and foreground != package:
            relaunch(package)
            stable_since = None
            time.sleep(0.4)
            continue

        if captured_frame_ready(package):
            if now - started < minimum_observe:
                stable_since = None
            elif stable_since is None:
                stable_since = now
            elif now - stable_since >= stable_for:
                return True
        else:
            stable_since = None

        time.sleep(0.25)

    return False


def install_synchronous_back_recovery(package: str) -> None:
    """Keep intentional root-Back exploration inside the game test boundary."""
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
            wait_for_game_frame(package, timeout=20.0, stable_for=1.0)
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

        settle_after_back(package)
        return result

    agent.adb = ci_adb


def prominent_cta_targets(path, width: int, height: int):
    """Find broad, bright action surfaces that the coarse vision grid can miss.

    Godot's custom-drawn controls are mostly invisible to Android UIAutomator. A
    prominent full-width CTA can therefore be visually obvious to a player while the
    generic 6x10 saliency grid repeatedly samples decorative cells. Detect only broad
    bright horizontal regions and target their center; this strengthens exploration
    without suppressing or reclassifying any finding.
    """
    try:
        with Image.open(path) as image:
            gray = image.convert("L").resize((240, 108))
            pixels = gray.load()
            qualifying_rows = []
            for y in range(4, 104):
                bright = sum(1 for x in range(240) if pixels[x, y] >= 145)
                if bright >= 72:  # at least 30% of the screen width
                    qualifying_rows.append(y)

            groups = []
            for y in qualifying_rows:
                if not groups or y > groups[-1][-1] + 1:
                    groups.append([y])
                else:
                    groups[-1].append(y)

            targets = []
            for rows in groups:
                if len(rows) < 5:
                    continue
                y1, y2 = rows[0], rows[-1]
                xs = [
                    x
                    for x in range(240)
                    if sum(1 for y in rows if pixels[x, y] >= 145) >= max(3, len(rows) // 2)
                ]
                if not xs or xs[-1] - xs[0] < 60:
                    continue
                cx = int(((xs[0] + xs[-1]) / 2.0) * width / 240.0)
                cy = int(((y1 + y2) / 2.0) * height / 108.0)
                targets.append(agent.Target(cx, cy, 50.0, "vision-cta"))
            return targets
    except Exception:
        return []


def install_prominent_cta_targeting() -> None:
    """Augment, rather than replace, the existing screenshot-guided explorer."""
    original_visual_targets = agent.visual_targets

    def ci_visual_targets(path, width, height, *args, **kwargs):
        base = original_visual_targets(path, width, height, *args, **kwargs)
        ctas = prominent_cta_targets(path, width, height)
        return ctas + base

    agent.visual_targets = ci_visual_targets


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
    install_prominent_cta_targeting()
    agent.main()


if __name__ == "__main__":
    main()
