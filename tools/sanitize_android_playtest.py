#!/usr/bin/env python3
"""Normalize Android playtest reports so CI only gates on RENEW-attributable faults."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

SEVERITY = {"critical": 4, "high": 3, "medium": 2, "low": 1}
LIFECYCLE_ACTIONS = ("background-foreground", "force-stop-relaunch", "rotation", "monkey-burst")


def line_pid(line: str) -> str:
    m = re.match(r"\s*\d\d-\d\d\s+\d\d:\d\d:\d\d\.\d+\s+(\d+)\s+(\d+)\s+", line)
    return m.group(1) if m else ""


def game_pids(report: dict) -> set[str]:
    result = set()
    for item in report.get("timeline", []):
        pid = str(item.get("pid", "")).strip()
        if pid.isdigit():
            result.add(pid)
    return result


def attributed_to_game(evidence: str, package: str, pids: set[str]) -> bool:
    if package.lower() in evidence.lower():
        return True
    for line in evidence.splitlines():
        pid = line_pid(line)
        if pid and pid in pids:
            return True
    return False


def renderer_evidence(logcat: str, pids: set[str]) -> str:
    hits = []
    for line in logcat.splitlines():
        if not re.search(r"(?:SceneShaderGLES3|CanvasShaderGLES3): Program linking failed", line):
            continue
        pid = line_pid(line)
        if pids and pid and pid not in pids:
            continue
        hits.append(line)
    return "\n".join(hits[-20:])


def sanitize(mode: str, report: dict, logcat: str) -> list[dict]:
    package = report.get("package", "com.eghosa.renew")
    pids = game_pids(report)
    cleaned = []

    for finding in report.get("findings", []):
        kind = str(finding.get("kind", ""))
        evidence = str(finding.get("evidence", ""))

        if kind == "runtime" and not attributed_to_game(evidence, package, pids):
            continue

        if mode == "chaos" and kind == "unexpected-restart":
            if any(f'"kind": "{action}"' in evidence for action in LIFECYCLE_ACTIONS):
                continue

        if mode == "ai" and kind == "launch" and report.get("timeline"):
            continue

        cleaned.append(finding)

    render = renderer_evidence(logcat, pids)
    if render and not any(f.get("kind") == "rendering" for f in cleaned):
        cleaned.append({
            "severity": "high",
            "kind": "rendering",
            "title": "RENEW GLES3 shader programs failed to link",
            "evidence": render,
            "reproduction": "Launch the QA APK in the configured Android emulator and inspect logcat.",
        })

    unique = []
    seen = set()
    for finding in cleaned:
        key = (finding.get("kind"), finding.get("title"))
        if key not in seen:
            seen.add(key)
            unique.append(finding)
    return unique


def recompute_memory(report: dict) -> None:
    samples = report.get("memory_samples", [])
    timeline = report.get("timeline", [])
    if not samples:
        return

    pid_by_step = {
        int(item.get("step", -1)): str(item.get("pid", "")).strip()
        for item in timeline
        if str(item.get("pid", "")).strip().isdigit()
    }

    groups = []
    active_pid = None
    values = []
    enriched = []
    for sample in samples:
        step = int(sample.get("step", -1))
        pid = str(sample.get("pid", "")).strip() or pid_by_step.get(step, "")
        value = int(sample.get("total_pss_kb", -1))
        item = dict(sample)
        item["pid"] = pid
        enriched.append(item)
        if value < 0 or not pid:
            continue
        if pid != active_pid:
            if values:
                groups.append(values)
            active_pid = pid
            values = []
        values.append(value)
    if values:
        groups.append(values)

    report["memory_samples"] = enriched
    report["memory_growth_kb"] = max(
        (max(0, values[-1] - values[0]) for values in groups if len(values) >= 2),
        default=0,
    )


def write_summary(mode: str, report: dict, path: Path) -> None:
    findings = report.get("findings", [])
    lines = [f"# RENEW Android {mode.upper()} Playtest", ""]
    lines.append(f"- Actionable findings: **{len(findings)}**")
    if mode == "chaos":
        lines.append(f"- Completed actions: **{report.get('steps_completed', 0)}/{report.get('steps_requested', 0)}**")
        lines.append(f"- Same-process memory growth: **{report.get('memory_growth_kb', 0)} KB**")
    else:
        coverage = report.get("coverage", {})
        lines.append(f"- Unique visual states: **{coverage.get('unique_visual_states', 0)}**")
        lines.append(f"- Unique transitions: **{coverage.get('unique_transitions', 0)}**")
    lines += [""]

    if findings:
        lines += ["## Findings", ""]
        for index, finding in enumerate(findings, 1):
            lines += [
                f"### {index}. [{str(finding.get('severity', 'low')).upper()}] {finding.get('title', 'Finding')}",
                "",
                f"Type: `{finding.get('kind', 'unknown')}`",
                "",
                "```",
                str(finding.get("evidence", ""))[:6000],
                "```",
                "",
            ]
    else:
        lines += ["## Result", "", "No high-severity RENEW-attributable fault was detected.", ""]

    lines += [
        "## Attribution",
        "",
        "Device-wide Android service and launcher failures are excluded unless evidence references the RENEW package or an observed RENEW process PID.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["ai", "chaos"], required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--threshold", choices=list(SEVERITY), default="high")
    args = parser.parse_args()

    out = Path(args.out)
    report_path = out / "report.json"
    if not report_path.exists():
        print("report.json is missing", file=sys.stderr)
        return 2

    report = json.loads(report_path.read_text(encoding="utf-8"))
    logcat_path = out / "logcat.txt"
    logcat = logcat_path.read_text(encoding="utf-8", errors="replace") if logcat_path.exists() else ""

    if args.mode == "chaos":
        recompute_memory(report)

    report["findings"] = sanitize(args.mode, report, logcat)
    worst = max((SEVERITY.get(str(f.get("severity", "low")), 0) for f in report["findings"]), default=0)
    threshold = SEVERITY[args.threshold]
    source = "\n".join(sorted(f"{f.get('kind')}:{f.get('title')}" for f in report["findings"]))
    report["fingerprint"] = hashlib.sha1(source.encode()).hexdigest()[:12] if source else "clean"
    report["should_open_issue"] = worst >= threshold
    report["sanitized_attribution"] = True

    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    write_summary(args.mode, report, out / "report.md")
    print(json.dumps({"findings": len(report["findings"]), "fingerprint": report["fingerprint"], "gate": worst >= threshold}))
    return 1 if worst >= threshold else 0


if __name__ == "__main__":
    raise SystemExit(main())
