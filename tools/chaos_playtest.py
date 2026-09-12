#!/usr/bin/env python3
"""RENEW destructive Android chaos playtester.

This agent is intentionally hostile. It does not try to play optimally; it tries to
break the running game while preserving a deterministic seed and evidence trail.
It mixes rapid taps, gesture spam, Back/Home/foreground cycles, app relaunches,
Android Monkey bursts, process/memory checks and logcat inspection.

The script exits non-zero when it detects a crash, ANR, fatal signal, package death
that cannot recover, or severe Godot/runtime errors. All actions are reproducible
from the seed recorded in report.json.
"""

from __future__ import annotations

import argparse
import json
import random
import re
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass
class Finding:
    severity: str
    kind: str
    title: str
    evidence: str
    step: int


def run(cmd, check=True, timeout=120):
    proc = subprocess.run(
        cmd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=check,
    )
    return proc.stdout.strip()


def adb(*args, check=True, timeout=120):
    return run(["adb", *args], check=check, timeout=timeout)


def wait_for_device():
    adb("wait-for-device", timeout=180)
    for _ in range(90):
        if adb("shell", "getprop", "sys.boot_completed", check=False) == "1":
            return
        time.sleep(2)
    raise RuntimeError("Android emulator did not finish booting")


def display_size():
    out = adb("shell", "wm", "size", check=False)
    matches = re.findall(r"(\d+)x(\d+)", out)
    if not matches:
        return 1080, 2400
    w, h = matches[-1]
    return int(w), int(h)


def pid_for(package):
    value = adb("shell", "pidof", package, check=False).strip()
    return value.split()[0] if value else ""


def launch(package):
    return adb(
        "shell", "monkey", "-p", package,
        "-c", "android.intent.category.LAUNCHER", "1", check=False, timeout=30,
    )


def memory_kb(package):
    out = adb("shell", "dumpsys", "meminfo", package, check=False, timeout=30)
    m = re.search(r"TOTAL\s+(\d+)", out)
    if not m:
        m = re.search(r"TOTAL PSS:\s*(\d+)", out)
    return int(m.group(1)) if m else -1


def foreground_package():
    out = adb("shell", "dumpsys", "activity", "activities", check=False, timeout=20)
    m = re.search(r"mResumedActivity:.*?\s([\w.]+)/", out)
    if m:
        return m.group(1)
    out = adb("shell", "dumpsys", "window", "windows", check=False, timeout=20)
    m = re.search(r"mCurrentFocus=Window\{[^}]*\s([\w.]+)/", out)
    return m.group(1) if m else ""


def screenshot(path: Path):
    with path.open("wb") as f:
        subprocess.run(["adb", "exec-out", "screencap", "-p"], stdout=f, check=False, timeout=30)


def logcat_text():
    return adb("logcat", "-d", "-v", "threadtime", check=False, timeout=60)


def fatal_lines(text):
    patterns = [
        r"FATAL EXCEPTION",
        r"ANR in ",
        r"Fatal signal",
        r"SIGSEGV",
        r"SIGABRT",
        r"DEBUG.*backtrace",
        r"Godot.*SCRIPT ERROR",
        r"Godot.*ERROR:.*(?:Invalid|Freed|null instance|out of bounds|stack|overflow)",
    ]
    rx = re.compile("|".join(patterns), re.I)
    return [line for line in text.splitlines() if rx.search(line)]


def do_action(rng, package, width, height, step):
    roll = rng.random()

    if roll < 0.22:
        # Rapid tap storm around random and edge coordinates.
        points = []
        for _ in range(rng.randint(4, 14)):
            if rng.random() < 0.25:
                x = rng.choice([2, 8, width - 8, width - 2, width // 2])
                y = rng.choice([2, 20, height - 20, height - 2, height // 2])
            else:
                x = rng.randint(1, width - 2)
                y = rng.randint(1, height - 2)
            adb("shell", "input", "tap", str(x), str(y), check=False, timeout=10)
            points.append([x, y])
        return {"kind": "tap-storm", "points": points}

    if roll < 0.38:
        # Extremely short/long swipes and diagonal gesture abuse.
        x1 = rng.randint(1, width - 2)
        y1 = rng.randint(1, height - 2)
        x2 = rng.randint(1, width - 2)
        y2 = rng.randint(1, height - 2)
        duration = rng.choice([1, 8, 25, 80, 250, 800, 1600])
        adb("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(duration), check=False, timeout=10)
        return {"kind": "swipe", "from": [x1, y1], "to": [x2, y2], "duration_ms": duration}

    if roll < 0.50:
        # Back spam catches modal/navigation stack corruption and exit edge cases.
        count = rng.randint(1, 6)
        for _ in range(count):
            adb("shell", "input", "keyevent", "4", check=False, timeout=10)
            time.sleep(0.04)
        return {"kind": "back-spam", "count": count}

    if roll < 0.60:
        # Home/background/foreground lifecycle stress.
        adb("shell", "input", "keyevent", "3", check=False, timeout=10)
        time.sleep(rng.uniform(0.05, 0.6))
        launch(package)
        return {"kind": "background-foreground"}

    if roll < 0.68:
        # Force-stop/relaunch tests persistence and cold-start resilience.
        adb("shell", "am", "force-stop", package, check=False, timeout=20)
        time.sleep(rng.uniform(0.05, 0.35))
        launch(package)
        return {"kind": "force-stop-relaunch"}

    if roll < 0.78:
        # Rotate repeatedly; restore portrait afterwards to avoid contaminating later actions.
        rotation = rng.choice([0, 1, 2, 3])
        adb("shell", "settings", "put", "system", "accelerometer_rotation", "0", check=False)
        adb("shell", "settings", "put", "system", "user_rotation", str(rotation), check=False)
        time.sleep(0.25)
        adb("shell", "settings", "put", "system", "user_rotation", "0", check=False)
        return {"kind": "rotation", "rotation": rotation}

    if roll < 0.88:
        # Android Monkey injects event combinations that a hand-authored explorer often misses.
        events = rng.randint(12, 60)
        seed = rng.randint(1, 2_147_483_647)
        out = adb(
            "shell", "monkey", "-p", package,
            "--pct-touch", "45", "--pct-motion", "25", "--pct-nav", "15",
            "--pct-majornav", "10", "--pct-appswitch", "5",
            "-s", str(seed), str(events), check=False, timeout=45,
        )
        return {"kind": "monkey-burst", "events": events, "seed": seed, "output_tail": out[-500:]}

    if roll < 0.95:
        # Long press can expose hidden press-state bugs or stuck controls.
        x = rng.randint(1, width - 2)
        y = rng.randint(1, height - 2)
        duration = rng.choice([700, 1500, 3000])
        adb("shell", "input", "swipe", str(x), str(y), str(x), str(y), str(duration), check=False, timeout=10)
        return {"kind": "long-press", "point": [x, y], "duration_ms": duration}

    # Volume/menu-ish keys should not crash or corrupt gameplay.
    key = rng.choice([24, 25, 82])
    adb("shell", "input", "keyevent", str(key), check=False, timeout=10)
    return {"kind": "keyevent", "key": key}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", required=True)
    parser.add_argument("--package", default="com.eghosa.renew")
    parser.add_argument("--out", default="build/chaos-playtest")
    parser.add_argument("--seed", type=int, default=20260912)
    parser.add_argument("--steps", type=int, default=500)
    parser.add_argument("--checkpoint-every", type=int, default=25)
    args = parser.parse_args()

    out = Path(args.out)
    shots = out / "screenshots"
    out.mkdir(parents=True, exist_ok=True)
    shots.mkdir(parents=True, exist_ok=True)

    rng = random.Random(args.seed)
    timeline = []
    findings = []
    memory_samples = []
    recoveries = 0
    unexpected_deaths = 0

    wait_for_device()
    adb("logcat", "-c", check=False)
    adb("install", "-r", args.apk, check=False, timeout=240)
    launch(args.package)
    time.sleep(4)

    width, height = display_size()
    start_pid = pid_for(args.package)
    if not start_pid:
        findings.append(Finding("critical", "launch", "Package did not start", "pidof returned empty", 0))

    previous_pid = start_pid
    for step in range(1, args.steps + 1):
        action = do_action(rng, args.package, width, height, step)
        time.sleep(rng.uniform(0.05, 0.30))

        pid = pid_for(args.package)
        fg = foreground_package()
        expected_restart = action["kind"] == "force-stop-relaunch"
        if not pid:
            unexpected_deaths += 1
            launch(args.package)
            time.sleep(1.0)
            pid = pid_for(args.package)
            if pid:
                recoveries += 1
            else:
                findings.append(Finding(
                    "critical", "process-death", "Game process died and would not recover",
                    f"action={json.dumps(action)} foreground={fg}", step,
                ))
                break
        elif previous_pid and pid != previous_pid and not expected_restart:
            # PID replacement may be Android lifecycle management, but during a tight hostile test
            # it is important evidence. Log as high unless fatal log evidence later upgrades it.
            findings.append(Finding(
                "high", "unexpected-restart", "Game process restarted during chaos input",
                f"previous_pid={previous_pid} new_pid={pid} action={json.dumps(action)}", step,
            ))

        previous_pid = pid or previous_pid

        checkpoint = step % max(1, args.checkpoint_every) == 0 or step == args.steps
        if checkpoint:
            mem = memory_kb(args.package)
            memory_samples.append({"step": step, "total_pss_kb": mem})
            shot = shots / f"{step:05d}.png"
            screenshot(shot)
            logs = logcat_text()
            fatals = fatal_lines(logs)
            if fatals:
                findings.append(Finding(
                    "critical", "runtime", "Fatal runtime evidence detected during chaos play",
                    "\n".join(fatals[-40:]), step,
                ))
                break

        timeline.append({
            "step": step,
            "action": action,
            "pid": pid,
            "foreground": fg,
        })

    logs = logcat_text()
    (out / "logcat.txt").write_text(logs, encoding="utf-8", errors="replace")
    gfx = adb("shell", "dumpsys", "gfxinfo", args.package, check=False, timeout=60)
    (out / "gfxinfo.txt").write_text(gfx, encoding="utf-8", errors="replace")
    meminfo = adb("shell", "dumpsys", "meminfo", args.package, check=False, timeout=60)
    (out / "meminfo.txt").write_text(meminfo, encoding="utf-8", errors="replace")

    fatals = fatal_lines(logs)
    if fatals and not any(f.kind == "runtime" for f in findings):
        findings.append(Finding("critical", "runtime", "Fatal runtime evidence detected", "\n".join(fatals[-40:]), args.steps))

    valid_mem = [x["total_pss_kb"] for x in memory_samples if x["total_pss_kb"] >= 0]
    memory_growth = 0
    if len(valid_mem) >= 2:
        memory_growth = valid_mem[-1] - valid_mem[0]
        # A 250 MB PSS increase in one hostile CI session is suspicious enough to investigate.
        if memory_growth > 250 * 1024:
            findings.append(Finding(
                "high", "memory-growth", "Large memory growth during chaos session",
                f"first_pss_kb={valid_mem[0]} last_pss_kb={valid_mem[-1]} growth_kb={memory_growth}", args.steps,
            ))

    report = {
        "package": args.package,
        "seed": args.seed,
        "steps_requested": args.steps,
        "steps_completed": timeline[-1]["step"] if timeline else 0,
        "unexpected_process_deaths": unexpected_deaths,
        "recoveries": recoveries,
        "memory_samples": memory_samples,
        "memory_growth_kb": memory_growth,
        "findings": [asdict(f) for f in findings],
        "timeline": timeline,
    }
    (out / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")

    md = [
        "# RENEW Android Chaos Playtest",
        "",
        f"- Seed: `{args.seed}`",
        f"- Requested hostile actions: **{args.steps}**",
        f"- Completed hostile actions: **{report['steps_completed']}**",
        f"- Unexpected process deaths: **{unexpected_deaths}**",
        f"- Automatic recoveries: **{recoveries}**",
        f"- Memory growth: **{memory_growth} KB**",
        f"- Findings: **{len(findings)}**",
        "",
        "The chaos bot deliberately used rapid taps, edge taps, extreme swipes, Back spam, background/foreground cycles, cold relaunches, rotation changes, Android Monkey bursts, long presses and unusual key events.",
        "",
    ]
    if findings:
        md += ["## Findings", ""]
        for i, finding in enumerate(findings, 1):
            md += [
                f"### {i}. [{finding.severity.upper()}] {finding.title}",
                "",
                f"Type: `{finding.kind}` — step **{finding.step}**",
                "",
                "```",
                finding.evidence[:6000],
                "```",
                "",
            ]
    else:
        md += [
            "## Result",
            "",
            "No crash, ANR, fatal signal, unrecoverable process death, severe Godot runtime error, or extreme memory-growth condition was detected.",
            "",
        ]
    md += ["## Evidence", "", "See `report.json`, `logcat.txt`, `gfxinfo.txt`, `meminfo.txt` and checkpoint screenshots.", ""]
    (out / "report.md").write_text("\n".join(md), encoding="utf-8")

    worst = {"critical": 4, "high": 3, "medium": 2, "low": 1}
    rank = max((worst[f.severity] for f in findings), default=0)
    print(json.dumps({"findings": len(findings), "steps_completed": report["steps_completed"], "memory_growth_kb": memory_growth}))
    return 1 if rank >= worst["high"] else 0


if __name__ == "__main__":
    sys.exit(main())
