#!/usr/bin/env python3
"""RENEW autonomous Android playtester.

Uses only Python stdlib + Pillow (installed by CI) and adb. It launches the game,
performs seeded exploratory input, captures screenshots/video/logcat, detects
crashes/ANRs/blank or visually-stuck screens, and emits Markdown + JSON reports.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import re
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


@dataclass
class Finding:
    severity: str
    kind: str
    title: str
    evidence: str
    reproduction: str


def run(cmd, check=True, capture=True, timeout=120):
    kwargs = {
        "text": True,
        "timeout": timeout,
        "check": check,
    }
    if capture:
        kwargs.update(stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    proc = subprocess.run(cmd, **kwargs)
    return proc.stdout.strip() if capture else ""


def adb(*args, check=True, timeout=120):
    return run(["adb", *args], check=check, timeout=timeout)


def wait_for_device():
    adb("wait-for-device", timeout=180)
    for _ in range(90):
        if adb("shell", "getprop", "sys.boot_completed", check=False) == "1":
            return
        time.sleep(2)
    raise RuntimeError("Android emulator did not finish booting")


def screencap(path: Path):
    with path.open("wb") as f:
        subprocess.run(["adb", "exec-out", "screencap", "-p"], stdout=f, check=True, timeout=30)


def image_metrics(path: Path):
    img = Image.open(path).convert("RGB")
    stat = ImageStat.Stat(img)
    means = stat.mean
    extrema = stat.extrema
    dynamic_range = max(v[1] for v in extrema) - min(v[0] for v in extrema)
    brightness = sum(means) / 3.0
    # Approximate visual complexity by downsampling and counting distinct RGB buckets.
    small = img.resize((64, 64))
    colors = small.quantize(colors=64).getcolors(maxcolors=64) or []
    occupied = len(colors)
    return {
        "width": img.width,
        "height": img.height,
        "brightness": round(brightness, 2),
        "dynamic_range": int(dynamic_range),
        "color_buckets": int(occupied),
    }


def image_difference(a: Path, b: Path):
    ia = Image.open(a).convert("RGB").resize((240, 135))
    ib = Image.open(b).convert("RGB").resize((240, 135))
    diff = ImageChops.difference(ia, ib)
    stat = ImageStat.Stat(diff)
    return round(sum(stat.mean) / (3.0 * 255.0), 5)


def foreground_package():
    out = adb("shell", "dumpsys", "window", "windows", check=False)
    matches = re.findall(r"mCurrentFocus=Window\{[^}]*\s([\w.]+)/", out)
    return matches[-1] if matches else ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", required=True)
    parser.add_argument("--package", default="com.eghosa.renew")
    parser.add_argument("--out", default="build/ai-playtest")
    parser.add_argument("--seed", type=int, default=20260912)
    parser.add_argument("--steps", type=int, default=70)
    parser.add_argument("--issue-threshold", choices=["critical", "high", "medium", "low"], default="high")
    args = parser.parse_args()

    out = Path(args.out)
    shots = out / "screenshots"
    out.mkdir(parents=True, exist_ok=True)
    shots.mkdir(parents=True, exist_ok=True)
    findings: list[Finding] = []
    timeline = []
    random.seed(args.seed)

    wait_for_device()
    adb("logcat", "-c", check=False)
    adb("install", "-r", args.apk, timeout=240)

    # Try to make the emulator deterministic and phone-like.
    adb("shell", "settings", "put", "system", "font_scale", "1.0", check=False)
    adb("shell", "settings", "put", "global", "window_animation_scale", "0", check=False)
    adb("shell", "settings", "put", "global", "transition_animation_scale", "0", check=False)
    adb("shell", "settings", "put", "global", "animator_duration_scale", "0", check=False)

    launch = adb("shell", "monkey", "-p", args.package, "-c", "android.intent.category.LAUNCHER", "1", check=False)
    time.sleep(6)
    if args.package not in foreground_package():
        findings.append(Finding("critical", "launch", "Game did not remain in foreground after launch", launch[-1000:], "Install APK and launch the RENEW app."))

    # Record the exploratory session. screenrecord stops itself at the duration limit.
    remote_video = "/sdcard/renew-ai-playtest.mp4"
    video_secs = min(180, max(45, args.steps * 2 + 15))
    video_proc = subprocess.Popen(["adb", "shell", "screenrecord", "--bit-rate", "4000000", "--time-limit", str(video_secs), remote_video], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    initial = shots / "000_initial.png"
    screencap(initial)
    initial_metrics = image_metrics(initial)
    if initial_metrics["brightness"] < 3 or initial_metrics["color_buckets"] <= 2:
        findings.append(Finding("critical", "visual", "Initial game screen appears blank/black", json.dumps(initial_metrics), "Launch the APK and wait 6 seconds."))

    width = int(adb("shell", "wm", "size").split("Physical size:")[-1].strip().split("x")[0])
    height = int(adb("shell", "wm", "size").split("Physical size:")[-1].strip().split("x")[1])

    # Bias inputs toward common mobile UI/game controls while retaining exploration.
    hotspots = [
        (0.50, 0.50), (0.50, 0.82), (0.50, 0.68), (0.20, 0.88), (0.80, 0.88),
        (0.12, 0.09), (0.88, 0.09), (0.25, 0.55), (0.75, 0.55), (0.50, 0.92),
    ]
    previous = initial
    stagnant = 0
    for step in range(1, args.steps + 1):
        action = random.random()
        desc = ""
        if action < 0.64:
            if random.random() < 0.70:
                fx, fy = random.choice(hotspots)
                x, y = int(width * fx), int(height * fy)
            else:
                x = random.randint(int(width * 0.08), int(width * 0.92))
                y = random.randint(int(height * 0.08), int(height * 0.94))
            adb("shell", "input", "tap", str(x), str(y), check=False)
            desc = f"tap({x},{y})"
        elif action < 0.90:
            x1 = random.randint(int(width * 0.2), int(width * 0.8))
            y1 = random.randint(int(height * 0.25), int(height * 0.85))
            direction = random.choice(["up", "down", "left", "right"])
            dx, dy = {"up": (0, -int(height*.35)), "down": (0, int(height*.35)), "left": (-int(width*.45), 0), "right": (int(width*.45), 0)}[direction]
            x2 = min(width-10, max(10, x1+dx)); y2 = min(height-10, max(10, y1+dy))
            adb("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), "280", check=False)
            desc = f"swipe-{direction}"
        else:
            adb("shell", "input", "keyevent", "4", check=False)
            desc = "back"
        time.sleep(0.65)

        if step % 5 == 0 or step == args.steps:
            shot = shots / f"{step:03d}.png"
            screencap(shot)
            metrics = image_metrics(shot)
            delta = image_difference(previous, shot)
            stagnant = stagnant + 1 if delta < 0.0025 else 0
            timeline.append({"step": step, "action": desc, "screenshot": str(shot), "metrics": metrics, "delta": delta, "foreground": foreground_package()})
            if metrics["brightness"] < 3 or metrics["color_buckets"] <= 2:
                findings.append(Finding("high", "visual", f"Screen appears blank near step {step}", json.dumps(metrics), f"Replay with seed {args.seed}; inspect around exploratory step {step}."))
            if stagnant >= 3:
                findings.append(Finding("medium", "softlock", f"Screen stayed visually unchanged across repeated interactions near step {step}", f"difference={delta}; screenshot={shot}", f"Replay with seed {args.seed}; inspect steps {max(1, step-15)}-{step}."))
                stagnant = 0
            previous = shot

        fg = foreground_package()
        if fg and fg != args.package and not fg.startswith("com.android"):
            findings.append(Finding("high", "navigation", f"Game lost foreground near step {step}", f"foreground={fg}", f"Replay with seed {args.seed}; inspect exploratory step {step}."))

    video_proc.wait(timeout=video_secs + 20)
    adb("pull", remote_video, str(out / "session.mp4"), check=False, timeout=120)

    logcat = adb("logcat", "-d", "-v", "threadtime", check=False, timeout=60)
    (out / "logcat.txt").write_text(logcat, encoding="utf-8", errors="replace")
    crash_lines = [line for line in logcat.splitlines() if re.search(r"FATAL EXCEPTION|ANR in |Fatal signal|SIGSEGV|SIGABRT|CRASH|Godot.*ERROR", line, re.I)]
    if crash_lines:
        findings.append(Finding("critical", "runtime", "Crash/ANR/fatal runtime evidence detected", "\n".join(crash_lines[-30:]), f"Replay automated session with seed {args.seed}."))

    # Collect Android rendering stats when available. Godot may not expose all frame metrics through gfxinfo.
    gfx = adb("shell", "dumpsys", "gfxinfo", args.package, check=False, timeout=60)
    (out / "gfxinfo.txt").write_text(gfx, encoding="utf-8", errors="replace")

    # Deduplicate findings by kind/title.
    unique = []
    seen = set()
    for f in findings:
        key = (f.kind, f.title)
        if key not in seen:
            unique.append(f); seen.add(key)
    findings = unique

    severity_rank = {"critical": 4, "high": 3, "medium": 2, "low": 1}
    worst = max((severity_rank[f.severity] for f in findings), default=0)
    threshold = severity_rank[args.issue_threshold]
    fingerprint = hashlib.sha1("\n".join(sorted(f"{f.kind}:{f.title}" for f in findings)).encode()).hexdigest()[:12] if findings else "clean"

    report = {
        "package": args.package,
        "seed": args.seed,
        "steps": args.steps,
        "initial_metrics": initial_metrics,
        "findings": [asdict(f) for f in findings],
        "timeline": timeline,
        "fingerprint": fingerprint,
        "should_open_issue": worst >= threshold,
    }
    (out / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")

    md = [
        "# RENEW Android AI Playtest Report",
        "",
        f"- Package: `{args.package}`",
        f"- Seed: `{args.seed}`",
        f"- Exploratory input steps: **{args.steps}**",
        f"- Findings: **{len(findings)}**",
        f"- Fingerprint: `{fingerprint}`",
        "",
    ]
    if findings:
        md += ["## Findings", ""]
        for i, f in enumerate(findings, 1):
            md += [f"### {i}. [{f.severity.upper()}] {f.title}", "", f"**Type:** `{f.kind}`", "", "**Evidence**", "```", f.evidence[:6000], "```", "", f"**Reproduction:** {f.reproduction}", ""]
    else:
        md += ["## Result", "", "No crash, ANR, blank-screen, foreground-loss, or repeated visual-stagnation failure was detected during this automated session.", ""]
    md += ["## Artifacts", "", "Review `session.mp4`, `screenshots/`, `logcat.txt`, `gfxinfo.txt`, and `report.json` for human/AI visual follow-up.", ""]
    (out / "report.md").write_text("\n".join(md), encoding="utf-8")

    print(json.dumps({"findings": len(findings), "fingerprint": fingerprint, "should_open_issue": worst >= threshold}))
    return 1 if worst >= severity_rank["critical"] else 0


if __name__ == "__main__":
    sys.exit(main())
