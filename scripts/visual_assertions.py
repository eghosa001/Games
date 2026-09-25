#!/usr/bin/env python3
"""
visual_assertions.py — region-level visual assertions for browser-qa screenshots.

These checks validate RESTORA's management-first command interface.
They deliberately avoid assumptions from the retired live-world/3D shell:
the page background may be intentionally quiet, while the current property status surface, management cards and compact navigation must remain visible,
contained and visually distinct.
"""

import sys
from pathlib import Path

try:
    from PIL import Image, ImageStat
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow", file=sys.stderr)
    sys.exit(2)

BG_DARK = (4, 18, 12, 30, 16, 30)
PANEL_DARK = (8, 16, 22, 36, 28, 42)
ACTION_DOCK = (12, 52, 12, 52, 16, 58)


def _region_avg(img: Image.Image, x0: int, y0: int, x1: int, y1: int):
    if x1 <= x0 or y1 <= y0:
        return None
    stat = ImageStat.Stat(img.crop((x0, y0, x1, y1)))
    return tuple(int(v) for v in stat.mean[:3])


def _in_range(mean, expected, tol=12):
    if mean is None:
        return False
    lo_r, hi_r, lo_g, hi_g, lo_b, hi_b = expected
    return (lo_r - tol <= mean[0] <= hi_r + tol and
            lo_g - tol <= mean[1] <= hi_g + tol and
            lo_b - tol <= mean[2] <= hi_b + tol)


def _sample_luminance(img, x0, y0, x1, y1, step=8):
    values = []
    for y in range(y0, y1, step):
        for x in range(x0, x1, step):
            r, g, b = img.getpixel((x, y))[:3]
            values.append((r + g + b) / 3.0)
    return values


def assert_shell_backdrop(img, vw, vh):
    if vw < 700:
        return True, "shell backdrop: skipped (narrow/mobile viewport)"
    x0, y0, x1, y1 = int(vw * 0.1), 0, int(vw * 0.9), min(66, vh)
    mean = _region_avg(img, x0, y0, x1, y1)
    if mean is None:
        return False, "shell backdrop: could not sample top strip"
    values = _sample_luminance(img, x0, y0, x1, y1)
    if not values:
        return False, "shell backdrop: no pixels sampled"
    avg_lum = sum(values) / len(values)
    bright_ratio = sum(v > 120 for v in values) / len(values)
    in_range = _in_range(mean, BG_DARK, tol=20)
    passed = in_range and avg_lum < 70 and bright_ratio < 0.08
    return passed, (f"shell backdrop: mean={mean} avg_lum={avg_lum:.1f} "
                    f"bright_ratio={bright_ratio:.3f} range={'OK' if in_range else 'BAD'}")


def assert_dark_surface(img, x0, y0, x1, y1, expected, label, tol=24, bright_limit=0.12):
    mean = _region_avg(img, x0, y0, x1, y1)
    if mean is None:
        return False, f"{label}: empty region"
    values = _sample_luminance(img, x0, y0, x1, y1)
    if not values:
        return False, f"{label}: no pixels sampled"
    avg_lum = sum(values) / len(values)
    bright_ratio = sum(v > 120 for v in values) / len(values)
    in_range = _in_range(mean, expected, tol=tol)
    passed = in_range and avg_lum < 90 and bright_ratio < bright_limit
    return passed, (f"{label}: mean={mean} avg_lum={avg_lum:.1f} "
                    f"bright_ratio={bright_ratio:.3f} range={'OK' if in_range else 'BAD'}")


def assert_management_surface(img, x0, y0, x1, y1, label):
    """Require a non-blank, readable management/status surface without assuming artwork."""
    mean = _region_avg(img, x0, y0, x1, y1)
    if mean is None:
        return False, f"{label}: empty region"
    values = _sample_luminance(img, x0, y0, x1, y1, step=6)
    if not values:
        return False, f"{label}: no pixels sampled"
    avg_lum = sum(values) / len(values)
    variance = sum((v - avg_lum) ** 2 for v in values) / len(values)
    std_lum = variance ** 0.5
    bright_ratio = sum(v > 180 for v in values) / len(values)
    passed = 18 <= avg_lum <= 105 and std_lum >= 7 and bright_ratio < 0.20
    return passed, (f"{label}: mean={mean} avg_lum={avg_lum:.1f} "
                    f"std_lum={std_lum:.1f} bright_ratio={bright_ratio:.3f}")


def assert_screenshot(path, vw, vh):
    results = []
    img = Image.open(path).convert("RGB")
    iw, ih = img.size
    sx = iw / max(vw, 1)
    sy = ih / max(vh, 1)

    def R(x0, y0, x1, y1):
        return (max(0, int(x0 * sx)), max(0, int(y0 * sy)),
                min(iw, int(x1 * sx)), min(ih, int(y1 * sy)))

    narrow = vw < 700

    if narrow:
        # The compact home hero deliberately overlays copy on the left and keeps
        # the current property status readable within the hero.
        results.append(assert_management_surface(
            img, *R(vw * 0.48, 82, vw * 0.96, min(236, vh * 0.34)),
            "mobile-property-status"
        ))
        results.append(assert_dark_surface(
            img, *R(18, 495, vw - 18, min(687, vh - 150)),
            PANEL_DARK, "mobile-signals", tol=30, bright_limit=0.12
        ))
        results.append(assert_dark_surface(
            img, *R(13, max(0, vh - 85), vw - 13, vh - 16),
            ACTION_DOCK, "mobile-navigation", tol=34, bright_limit=0.16
        ))
    else:
        results.append(assert_shell_backdrop(img, vw, vh))
        results.append(assert_management_surface(
            img, *R(vw * 0.133, vh * 0.224, vw * 0.457, vh * 0.662),
            "current-property-status"
        ))
        results.append(assert_dark_surface(
            img, *R(vw * 0.49, vh * 0.307, vw * 0.88, vh * 0.562),
            PANEL_DARK, "next-objective"
        ))
        results.append(assert_dark_surface(
            img, *R(vw * 0.12, vh * 0.662, vw * 0.472, vh * 0.912),
            PANEL_DARK, "building-details"
        ))
        results.append(assert_dark_surface(
            img, *R(vw * 0.689, vh * 0.593, vw * 0.88, vh * 0.912),
            ACTION_DOCK, "quick-actions", tol=34, bright_limit=0.18
        ))

    return results


def main():
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <screenshot.png> <viewport_width> <viewport_height>", file=sys.stderr)
        sys.exit(2)
    path, vw, vh = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    p = Path(path)
    if not p.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        sys.exit(2)
    results = assert_screenshot(str(p), vw, vh)
    failures = [msg for ok, msg in results if not ok]
    for ok, msg in results:
        print(("PASS" if ok else "FAIL") + ": " + msg)
    if failures:
        print(f"\n{len(failures)} assertion(s) failed.")
        sys.exit(1)
    print(f"\nAll {len(results)} visual assertions passed.")
    sys.exit(0)


if __name__ == "__main__":
    main()
