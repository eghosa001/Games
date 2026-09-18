#!/usr/bin/env python3
"""
visual_assertions.py — region-level visual assertions for browser-qa screenshots.

These checks validate the current RESTORA command-deck design rather than an
obsolete world-sky background. Dark shell surfaces may be layered and textured,
so the assertions allow normal variation while still rejecting bright/clear
bleed-through, missing panels and broken compact layouts.
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
ACTION_DOCK = (5, 14, 18, 34, 22, 40)


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
    x0, y0, x1, y1 = int(vw * 0.1), 0, int(vw * 0.9), 66
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


def assert_hybrid_world_surface(img, x0, y0, x1, y1, label):
    """Validate exposed 3D/world content without pinning it to one palette.

    The hybrid shell deliberately reveals rendered world geometry behind the UI.
    Require a non-blank, non-washed-out, visually varied region so a flat missing
    canvas, white error surface or fully black render still fails the gate.
    """
    mean = _region_avg(img, x0, y0, x1, y1)
    if mean is None:
        return False, f"{label}: empty region"
    values = _sample_luminance(img, x0, y0, x1, y1)
    if not values:
        return False, f"{label}: no pixels sampled"
    avg_lum = sum(values) / len(values)
    variance = sum((v - avg_lum) ** 2 for v in values) / len(values)
    std_lum = variance ** 0.5
    dark_ratio = sum(v < 12 for v in values) / len(values)
    bright_ratio = sum(v > 180 for v in values) / len(values)
    passed = (18 <= avg_lum <= 125 and std_lum >= 10 and
              dark_ratio < 0.65 and bright_ratio < 0.30)
    return passed, (f"{label}: mean={mean} avg_lum={avg_lum:.1f} "
                    f"std_lum={std_lum:.1f} dark_ratio={dark_ratio:.3f} "
                    f"bright_ratio={bright_ratio:.3f}")


def assert_dark_surface(img, x0, y0, x1, y1, expected, label):
    """Validate a dark UI surface without assuming it is pixel-flat."""
    mean = _region_avg(img, x0, y0, x1, y1)
    if mean is None:
        return False, f"{label}: empty region"
    values = _sample_luminance(img, x0, y0, x1, y1)
    if not values:
        return False, f"{label}: no pixels sampled"
    avg_lum = sum(values) / len(values)
    bright_ratio = sum(v > 120 for v in values) / len(values)
    in_range = _in_range(mean, expected, tol=24)
    passed = in_range and avg_lum < 85 and bright_ratio < 0.12
    return passed, (f"{label}: mean={mean} avg_lum={avg_lum:.1f} "
                    f"bright_ratio={bright_ratio:.3f} range={'OK' if in_range else 'BAD'}")


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
    if not narrow:
        results.append(assert_shell_backdrop(img, vw, vh))
        results.append(assert_dark_surface(img, *R(4, 110, 100, 340), PANEL_DARK, "left_rail"))
        results.append(assert_dark_surface(img, *R(104, 216, int(vw * 0.92), int(vh * 0.80)), ACTION_DOCK, "action_dock"))
        results.append(assert_dark_surface(img, *R(104, 112, 440, 212), PANEL_DARK, "selected_card"))

    dock_bottom = int(vh * 0.78) if narrow else int(vh * 0.80)
    # The hybrid shell intentionally exposes the rendered 3D/world surface
    # behind this area on both desktop and mobile. Validate that the region is
    # present and visually textured without pinning it to the retired 2D palette.
    results.append(assert_hybrid_world_surface(
        img, *R(4, dock_bottom, int(vw * 0.35), vh), "status-area-world"
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
