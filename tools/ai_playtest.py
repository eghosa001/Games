#!/usr/bin/env python3
"""RENEW autonomous Android playtester.

Free, local-only screenshot-guided test agent. It launches the APK, explores the
rendered game with ADB input, learns which visual regions respond, records video,
captures screenshots/logcat/rendering diagnostics, detects runtime and visual UX
failures, and emits Markdown + JSON evidence suitable for GitHub issues.

The vision layer intentionally needs no paid API or cloud model. It uses Pillow to
score screenshot saliency, contrast, visual density and state changes, then adapts
future taps toward controls that produced useful transitions.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import re
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageStat


@dataclass
class Finding:
    severity: str
    kind: str
    title: str
    evidence: str
    reproduction: str


@dataclass
class Target:
    x: int
    y: int
    score: float
    source: str


def run(cmd, check=True, capture=True, timeout=120):
    kwargs = {"text": True, "timeout": timeout, "check": check}
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
        subprocess.run(
            ["adb", "exec-out", "screencap", "-p"],
            stdout=f,
            check=True,
            timeout=30,
        )


def display_size():
    out = adb("shell", "wm", "size", check=False)
    matches = re.findall(r"(\d+)x(\d+)", out)
    if not matches:
        return (1080, 2400)
    w, h = matches[-1]
    return int(w), int(h)


def foreground_package():
    out = adb("shell", "dumpsys", "window", "windows", check=False)
    matches = re.findall(r"mCurrentFocus=Window\{[^}]*\s([\w.]+)/", out)
    if matches:
        return matches[-1]
    out = adb("shell", "dumpsys", "activity", "activities", check=False)
    matches = re.findall(r"mResumedActivity:.*?\s([\w.]+)/", out)
    return matches[-1] if matches else ""


def ui_dump(out_file: Path):
    remote = "/sdcard/renew-window.xml"
    adb("shell", "uiautomator", "dump", remote, check=False, timeout=20)
    adb("pull", remote, str(out_file), check=False, timeout=20)
    if not out_file.exists():
        return []
    text = out_file.read_text(encoding="utf-8", errors="replace")
    nodes = []
    for m in re.finditer(
        r'<node[^>]*(?:text="([^"]*)")?[^>]*clickable="true"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        text,
    ):
        label, x1, y1, x2, y2 = m.groups()
        x1, y1, x2, y2 = map(int, (x1, y1, x2, y2))
        if x2 > x1 and y2 > y1:
            nodes.append({
                "label": label or "",
                "bounds": [x1, y1, x2, y2],
                "center": [(x1 + x2) // 2, (y1 + y2) // 2],
            })
    return nodes


def ahash(path: Path, size=16):
    img = Image.open(path).convert("L").resize((size, size))
    px = list(img.getdata())
    avg = sum(px) / len(px)
    bits = ["1" if p >= avg else "0" for p in px]
    return hex(int("".join(bits), 2))[2:].zfill(size * size // 4)


def hamming_hex(a: str, b: str):
    try:
        return (int(a, 16) ^ int(b, 16)).bit_count()
    except Exception:
        return 999


def image_difference(a: Path, b: Path):
    ia = Image.open(a).convert("RGB").resize((240, 135))
    ib = Image.open(b).convert("RGB").resize((240, 135))
    diff = ImageChops.difference(ia, ib)
    stat = ImageStat.Stat(diff)
    return round(sum(stat.mean) / (3.0 * 255.0), 5)


def image_metrics(path: Path):
    img = Image.open(path).convert("RGB")
    stat = ImageStat.Stat(img)
    means = stat.mean
    extrema = stat.extrema
    brightness = sum(means) / 3.0
    dynamic_range = max(v[1] for v in extrema) - min(v[0] for v in extrema)

    # Edge density is a useful proxy for a visually crowded screen.
    gray = img.convert("L").resize((360, max(180, int(360 * img.height / img.width))))
    edges = gray.filter(ImageFilter.FIND_EDGES)
    est = ImageStat.Stat(edges)
    edge_mean = est.mean[0]
    edge_density = min(1.0, edge_mean / 42.0)

    small = img.resize((64, 64))
    colors = small.quantize(colors=64).getcolors(maxcolors=64) or []
    occupied = len(colors)

    # Contrast estimate. Low contrast on a text-heavy screen is a legibility risk.
    lum = gray.resize((96, 96))
    lum_stat = ImageStat.Stat(lum)
    contrast = lum_stat.stddev[0]

    return {
        "width": img.width,
        "height": img.height,
        "brightness": round(brightness, 2),
        "dynamic_range": int(dynamic_range),
        "color_buckets": int(occupied),
        "edge_density": round(edge_density, 4),
        "contrast_stddev": round(contrast, 2),
        "state_hash": ahash(path),
    }


def visual_targets(path: Path, width: int, height: int, cols=6, rows=10):
    """Return likely interactive regions using local contrast + edge saliency."""
    img = Image.open(path).convert("L")
    # Avoid Android status/nav areas while retaining Godot's top/bottom UI.
    crop_top = int(img.height * 0.035)
    crop_bottom = int(img.height * 0.965)
    usable = img.crop((0, crop_top, img.width, crop_bottom))
    edges = usable.filter(ImageFilter.FIND_EDGES)

    cw = usable.width / cols
    ch = usable.height / rows
    candidates = []
    scores = []
    for r in range(rows):
        for c in range(cols):
            x1, y1 = int(c * cw), int(r * ch)
            x2, y2 = int((c + 1) * cw), int((r + 1) * ch)
            cell = usable.crop((x1, y1, x2, y2))
            edge = edges.crop((x1, y1, x2, y2))
            s = ImageStat.Stat(cell)
            e = ImageStat.Stat(edge)
            # Prefer regions with both structure and local tonal variation.
            score = (s.stddev[0] / 64.0) + (e.mean[0] / 40.0)
            # A small center bias avoids repeatedly poking decorative corners.
            nx = (c + 0.5) / cols
            ny = (r + 0.5) / rows
            center_bias = 1.0 - 0.15 * math.hypot(nx - 0.5, ny - 0.52)
            score *= center_bias
            px = int(width * nx)
            py = int(height * (crop_top / img.height + ny * ((crop_bottom - crop_top) / img.height)))
            scores.append(score)
            candidates.append(Target(px, py, score, "vision-grid"))

    if not scores:
        return []
    ordered = sorted(candidates, key=lambda t: t.score, reverse=True)
    # Keep the best regions while forcing some spatial diversity.
    chosen = []
    min_dist = min(width / cols, height / rows) * 0.55
    for target in ordered:
        if all(math.hypot(target.x - q.x, target.y - q.y) >= min_dist for q in chosen):
            chosen.append(target)
        if len(chosen) >= 14:
            break
    return chosen


def weighted_choice(targets, learned, rng):
    if not targets:
        return None
    weights = []
    for t in targets:
        # Learned response score rewards regions that previously changed the screen.
        key = f"{round(t.x / 80)}:{round(t.y / 80)}"
        reward = learned.get(key, {"attempts": 0, "reward": 0.0})
        exploitation = 1.0 + reward["reward"] / max(1, reward["attempts"])
        novelty = 1.0 / (1.0 + 0.12 * reward["attempts"])
        weights.append(max(0.05, t.score * exploitation * novelty))
    return rng.choices(targets, weights=weights, k=1)[0]


def target_key(x, y):
    return f"{round(x / 80)}:{round(y / 80)}"


def add_ux_findings(findings, metrics, shot, step, clickable_nodes=0):
    evidence = f"screenshot={shot}; metrics={json.dumps(metrics)}; accessible_clickables={clickable_nodes}"
    repro = f"Replay the same seed and inspect the screen around step {step}."

    if metrics["edge_density"] >= 0.72 and metrics["color_buckets"] >= 45:
        findings.append(Finding(
            "medium", "ux-density",
            f"Screen appears visually overcrowded near step {step}",
            evidence,
            repro,
        ))
    elif metrics["edge_density"] >= 0.60:
        findings.append(Finding(
            "low", "ux-density",
            f"High visual density detected near step {step}",
            evidence,
            repro,
        ))

    if metrics["contrast_stddev"] < 20 and metrics["edge_density"] > 0.30:
        findings.append(Finding(
            "medium", "legibility",
            f"Low-contrast structured screen may be difficult to read near step {step}",
            evidence,
            repro,
        ))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", required=True)
    parser.add_argument("--package", default="com.eghosa.renew")
    parser.add_argument("--out", default="build/ai-playtest")
    parser.add_argument("--seed", type=int, default=20260912)
    parser.add_argument("--steps", type=int, default=90)
    parser.add_argument("--issue-threshold", choices=["critical", "high", "medium", "low"], default="high")
    parser.add_argument("--capture-every", type=int, default=3)
    args = parser.parse_args()

    out = Path(args.out)
    shots = out / "screenshots"
    dumps = out / "ui-dumps"
    out.mkdir(parents=True, exist_ok=True)
    shots.mkdir(parents=True, exist_ok=True)
    dumps.mkdir(parents=True, exist_ok=True)

    findings: list[Finding] = []
    timeline = []
    learned = {}
    state_visits = {}
    transitions = {}
    rng = random.Random(args.seed)

    wait_for_device()
    adb("logcat", "-c", check=False)
    adb("install", "-r", args.apk, timeout=240)

    adb("shell", "settings", "put", "system", "font_scale", "1.0", check=False)
    adb("shell", "settings", "put", "global", "window_animation_scale", "0", check=False)
    adb("shell", "settings", "put", "global", "transition_animation_scale", "0", check=False)
    adb("shell", "settings", "put", "global", "animator_duration_scale", "0", check=False)

    launch = adb(
        "shell", "monkey", "-p", args.package,
        "-c", "android.intent.category.LAUNCHER", "1", check=False,
    )
    time.sleep(6)
    if args.package not in foreground_package():
        findings.append(Finding(
            "critical", "launch", "Game did not remain in foreground after launch",
            launch[-1000:], "Install APK and launch the RENEW app.",
        ))

    remote_video = "/sdcard/renew-ai-playtest.mp4"
    video_secs = min(180, max(60, int(args.steps * 1.5 + 20)))
    video_proc = subprocess.Popen(
        ["adb", "shell", "screenrecord", "--bit-rate", "4000000", "--time-limit", str(video_secs), remote_video],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    width, height = display_size()
    initial = shots / "000_initial.png"
    screencap(initial)
    initial_metrics = image_metrics(initial)
    initial_state = initial_metrics["state_hash"]
    state_visits[initial_state] = 1

    initial_nodes = ui_dump(dumps / "000.xml")
    add_ux_findings(findings, initial_metrics, initial, 0, len(initial_nodes))
    if initial_metrics["brightness"] < 3 or initial_metrics["color_buckets"] <= 2:
        findings.append(Finding(
            "critical", "visual", "Initial game screen appears blank/black",
            json.dumps(initial_metrics), "Launch the APK and wait 6 seconds.",
        ))

    current_shot = initial
    current_metrics = initial_metrics
    current_state = initial_state
    stagnant = 0
    consecutive_dead_actions = 0
    unique_state_history = [current_state]

    common_hotspots = [
        (0.50, 0.50), (0.50, 0.82), (0.50, 0.68), (0.20, 0.88), (0.80, 0.88),
        (0.12, 0.09), (0.88, 0.09), (0.25, 0.55), (0.75, 0.55), (0.50, 0.92),
    ]

    for step in range(1, args.steps + 1):
        nodes = ui_dump(dumps / f"{step:03d}.xml") if step % 6 == 1 else []
        vision = visual_targets(current_shot, width, height)
        accessible = [
            Target(n["center"][0], n["center"][1], 2.5, "uiautomator")
            for n in nodes
            if 0 <= n["center"][0] < width and 0 <= n["center"][1] < height
        ]
        fallback = [Target(int(width*x), int(height*y), 0.9, "fallback") for x, y in common_hotspots]
        candidates = accessible + vision + fallback

        # Mostly tap screenshot-guided targets. Swipes and Back preserve broad exploration.
        roll = rng.random()
        action = {"kind": "", "description": "", "source": ""}
        chosen = None
        if roll < 0.76:
            chosen = weighted_choice(candidates, learned, rng)
            if chosen:
                adb("shell", "input", "tap", str(chosen.x), str(chosen.y), check=False)
                action = {
                    "kind": "tap",
                    "description": f"tap({chosen.x},{chosen.y})",
                    "source": chosen.source,
                    "x": chosen.x,
                    "y": chosen.y,
                }
        elif roll < 0.94:
            x1 = rng.randint(int(width * 0.22), int(width * 0.78))
            y1 = rng.randint(int(height * 0.28), int(height * 0.82))
            direction = rng.choice(["up", "down", "left", "right"])
            dx, dy = {
                "up": (0, -int(height * .36)),
                "down": (0, int(height * .36)),
                "left": (-int(width * .48), 0),
                "right": (int(width * .48), 0),
            }[direction]
            x2 = min(width - 10, max(10, x1 + dx))
            y2 = min(height - 10, max(10, y1 + dy))
            adb("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), "260", check=False)
            action = {"kind": "swipe", "description": f"swipe-{direction}", "source": "exploration"}
        else:
            adb("shell", "input", "keyevent", "4", check=False)
            action = {"kind": "back", "description": "back", "source": "navigation"}

        time.sleep(0.72)

        # Screenshot feedback after every action gives the agent a reward signal. Only
        # long-term evidence frames are retained every N steps.
        feedback = shots / f"{step:03d}_feedback.png"
        screencap(feedback)
        new_metrics = image_metrics(feedback)
        delta = image_difference(current_shot, feedback)
        new_state = new_metrics["state_hash"]
        hash_distance = hamming_hex(current_state, new_state)
        changed = delta >= 0.004 or hash_distance >= 8
        novel = all(hamming_hex(new_state, s) >= 10 for s in state_visits)

        if chosen:
            key = target_key(chosen.x, chosen.y)
            rec = learned.setdefault(key, {"attempts": 0, "reward": 0.0})
            rec["attempts"] += 1
            rec["reward"] += (2.0 if novel else 1.0 if changed else -0.25)

        state_visits[new_state] = state_visits.get(new_state, 0) + 1
        edge = f"{current_state[:10]}->{new_state[:10]}"
        transitions[edge] = transitions.get(edge, 0) + 1
        if novel:
            unique_state_history.append(new_state)

        if changed:
            stagnant = 0
            consecutive_dead_actions = 0
        else:
            stagnant += 1
            consecutive_dead_actions += 1

        keep = (step % max(1, args.capture_every) == 0) or step == args.steps or novel
        evidence_path = feedback
        if not keep:
            feedback.unlink(missing_ok=True)
            evidence_path = current_shot

        timeline.append({
            "step": step,
            "action": action,
            "screenshot": str(evidence_path),
            "delta": delta,
            "hash_distance": hash_distance,
            "changed": changed,
            "novel_state": novel,
            "state_hash": new_state,
            "state_visit_count": state_visits[new_state],
            "metrics": new_metrics,
            "foreground": foreground_package(),
            "accessible_clickables": len(nodes),
            "vision_targets": len(vision),
        })

        if keep:
            add_ux_findings(findings, new_metrics, evidence_path, step, len(nodes))

        if new_metrics["brightness"] < 3 or new_metrics["color_buckets"] <= 2:
            findings.append(Finding(
                "high", "visual", f"Screen appears blank near step {step}",
                f"screenshot={evidence_path}; {json.dumps(new_metrics)}",
                f"Replay with seed {args.seed}; inspect around exploratory step {step}.",
            ))

        if stagnant >= 7:
            findings.append(Finding(
                "medium", "softlock",
                f"Seven consecutive exploratory actions caused no meaningful visual response near step {step}",
                f"screenshot={evidence_path}; last_delta={delta}; state={new_state[:16]}",
                f"Replay with seed {args.seed}; inspect steps {max(1, step-7)}-{step}.",
            ))
            # Escape strategy: Back, then swipe. This makes the agent recover instead of
            # spending the rest of the run on a dead state.
            adb("shell", "input", "keyevent", "4", check=False)
            time.sleep(0.35)
            adb("shell", "input", "swipe", str(width//2), str(int(height*.78)), str(width//2), str(int(height*.30)), "320", check=False)
            stagnant = 0

        if consecutive_dead_actions >= 12:
            findings.append(Finding(
                "high", "interaction",
                f"Large region of the game appears non-responsive near step {step}",
                f"12 actions produced no meaningful screen transition; screenshot={evidence_path}",
                f"Replay with seed {args.seed}; inspect the last 12 actions before step {step}.",
            ))
            consecutive_dead_actions = 0

        fg = foreground_package()
        if fg and fg != args.package and not fg.startswith("com.android"):
            findings.append(Finding(
                "high", "navigation", f"Game lost foreground near step {step}",
                f"foreground={fg}", f"Replay with seed {args.seed}; inspect step {step}.",
            ))

        current_shot = feedback if feedback.exists() else evidence_path
        current_metrics = new_metrics
        current_state = new_state

    try:
        video_proc.wait(timeout=video_secs + 20)
    except subprocess.TimeoutExpired:
        video_proc.terminate()
        video_proc.wait(timeout=10)
    adb("pull", remote_video, str(out / "session.mp4"), check=False, timeout=120)

    logcat = adb("logcat", "-d", "-v", "threadtime", check=False, timeout=60)
    (out / "logcat.txt").write_text(logcat, encoding="utf-8", errors="replace")
    crash_lines = [
        line for line in logcat.splitlines()
        if re.search(r"FATAL EXCEPTION|ANR in |Fatal signal|SIGSEGV|SIGABRT|CRASH|Godot.*ERROR", line, re.I)
    ]
    if crash_lines:
        findings.append(Finding(
            "critical", "runtime", "Crash/ANR/fatal runtime evidence detected",
            "\n".join(crash_lines[-30:]), f"Replay automated session with seed {args.seed}.",
        ))

    gfx = adb("shell", "dumpsys", "gfxinfo", args.package, check=False, timeout=60)
    (out / "gfxinfo.txt").write_text(gfx, encoding="utf-8", errors="replace")

    # Coverage-oriented findings are intentionally moderate: they flag a game that can
    # launch but never exposes enough distinguishable states to an exploratory player.
    unique_states = len(unique_state_history)
    transition_count = len(transitions)
    if args.steps >= 40 and unique_states <= 3:
        findings.append(Finding(
            "high", "playability",
            "Automated player discovered almost no navigable game states",
            f"unique_states={unique_states}; transitions={transition_count}; steps={args.steps}",
            f"Replay with seed {args.seed}; verify that menus/gameplay can be progressed with visible controls.",
        ))
    elif args.steps >= 40 and unique_states <= 6:
        findings.append(Finding(
            "medium", "discoverability",
            "Automated player found limited screen progression",
            f"unique_states={unique_states}; transitions={transition_count}; steps={args.steps}",
            f"Replay with seed {args.seed}; inspect whether primary actions are obvious on mobile.",
        ))

    # Deduplicate exact finding titles.
    unique = []
    seen = set()
    for f in findings:
        key = (f.kind, f.title)
        if key not in seen:
            unique.append(f)
            seen.add(key)
    findings = unique

    severity_rank = {"critical": 4, "high": 3, "medium": 2, "low": 1}
    worst = max((severity_rank[f.severity] for f in findings), default=0)
    threshold = severity_rank[args.issue_threshold]
    fingerprint = (
        hashlib.sha1("\n".join(sorted(f"{f.kind}:{f.title}" for f in findings)).encode()).hexdigest()[:12]
        if findings else "clean"
    )

    interaction_attempts = sum(v["attempts"] for v in learned.values())
    positive_regions = sum(1 for v in learned.values() if v["reward"] > 0)
    coverage = {
        "unique_visual_states": unique_states,
        "state_samples": len(state_visits),
        "unique_transitions": transition_count,
        "learned_tap_regions": len(learned),
        "positive_response_regions": positive_regions,
        "tap_attempts": interaction_attempts,
    }

    report = {
        "package": args.package,
        "seed": args.seed,
        "steps": args.steps,
        "initial_metrics": initial_metrics,
        "coverage": coverage,
        "findings": [asdict(f) for f in findings],
        "timeline": timeline,
        "learned_regions": learned,
        "transitions": transitions,
        "fingerprint": fingerprint,
        "should_open_issue": worst >= threshold,
    }
    (out / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")

    md = [
        "# RENEW Android Vision Playtest Report",
        "",
        f"- Package: `{args.package}`",
        f"- Seed: `{args.seed}`",
        f"- Screenshot-guided actions: **{args.steps}**",
        f"- Unique visual states discovered: **{unique_states}**",
        f"- Unique state transitions: **{transition_count}**",
        f"- Responsive tap regions learned: **{positive_regions}/{len(learned)}**",
        f"- Findings: **{len(findings)}**",
        f"- Fingerprint: `{fingerprint}`",
        "",
        "## What the agent did",
        "",
        "The runner analyzed every screenshot, selected visually salient targets, rewarded targets that changed the game state, avoided repeatedly unresponsive regions, and mixed in swipes/back navigation to discover additional paths.",
        "",
    ]
    if findings:
        md += ["## Findings", ""]
        for i, f in enumerate(findings, 1):
            md += [
                f"### {i}. [{f.severity.upper()}] {f.title}", "",
                f"**Type:** `{f.kind}`", "", "**Evidence**", "```",
                f.evidence[:6000], "```", "", f"**Reproduction:** {f.reproduction}", "",
            ]
    else:
        md += [
            "## Result", "",
            "No crash, ANR, blank-screen, major foreground-loss, severe interaction dead-zone, or navigation-coverage failure was detected during this session.", "",
        ]
    md += [
        "## Artifacts", "",
        "Review `session.mp4`, `screenshots/`, `ui-dumps/`, `logcat.txt`, `gfxinfo.txt`, and `report.json` for complete evidence.", "",
        "## Interpretation", "",
        "Visual-density and legibility findings are heuristic warnings, not substitutes for a human accessibility review. Godot games may expose little or no Android accessibility tree, so screenshot feedback is the primary exploration signal.", "",
    ]
    (out / "report.md").write_text("\n".join(md), encoding="utf-8")

    print(json.dumps({
        "findings": len(findings),
        "fingerprint": fingerprint,
        "should_open_issue": worst >= threshold,
        "unique_states": unique_states,
        "transitions": transition_count,
    }))
    return 1 if worst >= severity_rank["critical"] else 0


if __name__ == "__main__":
    sys.exit(main())
