#!/usr/bin/env python3
"""
visual_assertions.py — region-level visual assertions for browser-qa screenshots.

These checks validate rendered intent rather than exact pixel-flat colours.
RENEW uses layered/translucent panels and illustrated world surfaces, so colour
entropy inside a UI region is not by itself evidence of ghost rendering.
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
BACKDROP_TEAL = (16, 30, 48, 72, 60, 90)
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


def assert_backdrop_visible(img, vw, vh):
    if vw < 700:
        return True, "backdrop: skipped (narrow/mobile viewport)"
    mean = _region_avg(img, int(vw * 0.1), 0, int(vw * 0.9), 66)
    if mean is None:
        return False, "backdrop: could not sample top strip"
    if _in_range(mean, BACKDROP_TEAL, tol=16):
        return True, f"backdrop: teal sky present in top strip ({mean})"
    lum = sum(mean) / 3.0
    if lum > 22:
        return True, f"backdrop: rendered non-clear top strip ({mean}, lum={lum:.1f})"
    return False, f"backdrop: top strip is near-clear-colour (mean={mean}, lum={lum:.1f})"


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
        results.append(assert_backdrop_visible(img, vw, vh))
        results.append(assert_dark_surface(img, *R(4, 110, 100, 340), PANEL_DARK, "left_rail"))
        results.append(assert_dark_surface(img, *R(104, 216, int(vw * 0.92), int(vh * 0.80)), ACTION_DOCK, "action_dock"))
        results.append(assert_dark_surface(img, *R(104, 112, 440, 212), PANEL_DARK, "selected_card"))

    dock_bottom = int(vh * 0.78) if narrow else int(vh * 0.80)
    # In the compact layout this region is occupied by the overview panel,
    # not the exposed base background used by desktop. Validate the rendered
    # panel palette on mobile while preserving the stricter desktop baseline.
    status_surface = PANEL_DARK if narrow else BG_DARK
    results.append(assert_dark_surface(img, *R(4, dock_bottom, int(vw * 0.35), vh), status_surface, "status-area-bg"))
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
