#!/usr/bin/env python3
"""
visual_assertions.py — region-level pixel assertions for browser-qa screenshots.

Designed to catch the class of bugs that property-based tests miss:
  • Invisible scenery (PremiumWorldBackdrop draws nothing despite visible=True)
  • Ghost-text / z-order bleed-through (legacy renderers or floaters drawing
    inside areas that should be covered by a single opaque panel)
  • Panel overlap (two Controls painting into the same rectangle)

Usage (called from browser-qa.sh):
    python scripts/visual_assertions.py <screenshot.png> <viewport_width> <viewport_height>

Exit code 0 = all assertions passed.
Exit code 1 = one or more assertions failed (prints which ones).
"""

import sys
from pathlib import Path

try:
    from PIL import Image, ImageStat
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow", file=sys.stderr)
    sys.exit(2)


# ---------------------------------------------------------------------------
# Colour palettes pulled directly from source — used as acceptance bounds,
# NOT as exact-match references.  Each entry is (r_lo, r_hi, g_lo, g_hi, b_lo, b_hi).
# ---------------------------------------------------------------------------

BG_DARK      = (4,  18,  12, 30,  16, 30)     # BG           "071217"
PANEL_DARK   = (8,  16,  22, 36,  28, 42)     # PANEL        "0b1b22"
BORDER_TEAL  = (40, 60,  70, 100, 78, 108)    # BORDER       "31545c"
BACKDROP_TEAL= (16, 30,  48, 72,  60, 90)     # PremiumWorldBackdrop sky "173847"/"28545c"
TEXT_WHITE   = (220, 255, 240, 255, 235, 250) # TEXT         "edf6f3"
ACTION_DOCK  = (5,  14,  18, 34,  22, 40)     # action_dock  "091920"


def _region_avg(img: Image.Image, x0: int, y0: int, x1: int, y1: int) -> tuple:
    """Return (R,G,B) mean of pixels in [x0,x1) × [y0,y1), or None if empty."""
    if x1 <= x0 or y1 <= y0:
        return None
    crop = img.crop((x0, y0, x1, y1))
    stat = ImageStat.Stat(crop)
    return tuple(int(v) for v in stat.mean[:3])


def _in_range(mean: tuple, r_lo: int, r_hi: int, g_lo: int, g_hi: int, b_lo: int, b_hi: int) -> bool:
    return r_lo <= mean[0] <= r_hi and g_lo <= mean[1] <= g_hi and b_lo <= mean[2] <= b_hi


def _unique_colours(img: Image.Image, x0: int, y0: int, x1: int, y1: int,
                    quant: int = 12) -> int:
    """Count distinct (R//q, G//q, B//q) colours in region."""
    if x1 <= x0 or y1 <= y0:
        return 0
    # Sample every Nth pixel to keep runtime sane on large images.
    step = max(1, max(x1 - x0, 1) // 80)
    seen = set()
    for y in range(y0, y1, step):
        for x in range(x0, x1, step):
            c = img.getpixel((x, y))
            if isinstance(c, tuple) and len(c) >= 3:
                seen.add((c[0] // quant, c[1] // quant, c[2] // quant))
    return len(seen)


# ---------------------------------------------------------------------------
# Assertions — each returns (passed: bool, message: str)
# ---------------------------------------------------------------------------

def assert_backdrop_visible(img: Image.Image, vw: int, vh: int) -> tuple:
    """
    The top strip of the screen (y: 0–64, above the mode_rail at y=64) must
    contain backdrop-teal pixels from PremiumWorldBackdrop.  If the entire
    top strip is clear-colour black, the backdrop is not rendering.
    On narrow (mobile) viewports the HUD covers the full height so this check
    is skipped.
    """
    if vw < 700:
        return True, "backdrop: skipped (narrow/mobile viewport)"
    # Sample only the y:0–64 strip — above mode_rail which starts at y=64.
    band_x0, band_y0 = int(vw * 0.1), 0
    band_x1, band_y1 = int(vw * 0.9), 66
    mean = _region_avg(img, band_x0, band_y0, band_x1, band_y1)
    if mean is None:
        return False, "backdrop: could not sample top strip"
    if _in_range(mean, *BACKDROP_TEAL):
        return True, f"backdrop: teal sky present in top strip ({mean})"
    lum = sum(mean) / 3.0
    # Clear colour is ~8,13,15.  Anything noticeably brighter = something drew.
    if lum > 25:
        return True, f"backdrop: non-clear colour in top strip lum={lum:.1f} (may be HUD chrome)"
    return False, (f"backdrop: top strip is near-clear-colour "
                  f"(mean={mean}, lum={lum:.1f}) — PremiumWorldBackdrop may not be rendering")


def assert_region_flat(img: Image.Image, x0: int, y0: int, x1: int, y1: int,
                        expected: tuple, label: str, tol: int = 10) -> tuple:
    """Region must be a single flat colour within tolerance — catches ghost-text bleed."""
    mean = _region_avg(img, x0, y0, x1, y1)
    if mean is None:
        return False, f"{label}: empty region"
    distinct = _unique_colours(img, x0, y0, x1, y1, quant=max(1, tol // 3))
    lo_r, hi_r, lo_g, hi_g, lo_b, hi_b = expected
    in_range = (lo_r - tol <= mean[0] <= hi_r + tol and
                lo_g - tol <= mean[1] <= hi_g + tol and
                lo_b - tol <= mean[2] <= hi_b + tol)
    # Flatness: a solid-colour region should have ≤4 distinct quantised buckets.
    flat_ok = distinct <= 6
    msg = (f"{label}: mean={mean} distinct={distinct}/"
           f"expected~{expected} flat={'OK' if flat_ok else 'BAD'} range={'OK' if in_range else 'BAD'}")
    return in_range and flat_ok, msg


def assert_no_ghost_in(img: Image.Image, x0: int, y0: int, x1: int, y1: int,
                        bg_expected: tuple, label: str) -> tuple:
    """
    Region should match the panel colour.  High colour-entropy signals
    ghost-text or z-order bleed-through from a second renderer.
    """
    distinct = _unique_colours(img, x0, y0, x1, y1, quant=8)
    mean = _region_avg(img, x0, y0, x1, y1) or (0, 0, 0)
    lo_r, hi_r, lo_g, hi_g, lo_b, hi_b = bg_expected
    in_range = (lo_r - 8 <= mean[0] <= hi_r + 8 and
                lo_g - 8 <= mean[1] <= hi_g + 8 and
                lo_b - 8 <= mean[2] <= hi_b + 8)
    # Thresholds: good screens show ~2 distinct buckets in flat panels.
    # Ghost text / z-order bleed introduces many more (10–30+).
    max_distinct = 8 if "dock" in label.lower() else 10
    passed = in_range and distinct <= max_distinct
    return passed, (f"{label}: mean={mean} distinct_colour_buckets={distinct} "
                    f"(limit={max_distinct}, range_ok={'OK' if in_range else 'BAD'})")


# ---------------------------------------------------------------------------
# Entry point — maps screenshot dimensions to region rects
# ---------------------------------------------------------------------------

def assert_screenshot(path: str, vw: int, vh: int) -> list:
    results: list = []
    img = Image.open(path).convert("RGB")
    iw, ih = img.size

    # Scale rects proportionally when the actual capture differs from reported vp.
    sx = iw / max(vw, 1)
    sy = ih / max(vh, 1)

    def R(x0, y0, x1, y1):
        """Clamp-reported rect to image bounds, scaling for actual pixel dimensions."""
        return (max(0, int(x0 * sx)), max(0, int(y0 * sy)),
                min(iw, int(x1 * sx)), min(ih, int(y1 * sy)))

    narrow = vw < 700

    # ── 1. Backdrop visibility (desktop only — mobile HUD covers the whole screen) ──
    if not narrow:
        ok, msg = assert_backdrop_visible(img, vw, vh)
        results.append((ok, msg))

    # ── 2. Left rail must be a single flat PANEL colour (desktop only — hidden on mobile) ──
    if not narrow:
        ok, msg = assert_no_ghost_in(img, *R(4, 110, 100, 340), PANEL_DARK, "left_rail")
        results.append((ok, msg))

    # ── 3. Action dock must be a single flat colour — no ghost text from map/legacy renderers ──
    # Mobile: full-width panel from mode-rail bottom down. Desktop: x:108→right.
    if narrow:
        ok, msg = assert_no_ghost_in(img, *R(4, 190, vw - 4, int(vh * 0.78)),
                                      ACTION_DOCK, "action_dock")
    else:
        ok, msg = assert_no_ghost_in(img, *R(104, 216, int(vw * 0.92), int(vh * 0.80)),
                                      ACTION_DOCK, "action_dock")
    results.append((ok, msg))

    # ── 4. Selected card area should be PANEL (no map bleed-through) — desktop only ──
    if not narrow:
        ok, msg = assert_no_ghost_in(img, *R(104, 112, 440, 212), PANEL_DARK, "selected_card")
        results.append((ok, msg))

    # ── 5. Background band above HUD (desktop only — verify backdrop renders) ────────────────
    if not narrow:
        # y: 64–110 is the mode-rail zone; above that (0–64) should show backdrop teal.
        ok, msg = assert_region_flat(img, *R(0, 0, vw, 66),
                                      BACKDROP_TEAL, "top-backdrop-sky")
        results.append((ok, msg))

    # ── 6. Bottom status area (below action dock) should be BG/DARK — never backdrop ──
    dock_bottom = int(vh * 0.78) if narrow else int(vh * 0.80)
    ok, msg = assert_region_flat(img, *R(4, dock_bottom, int(vw * 0.35), vh),
                                  BG_DARK, "status-area-bg")
    results.append((ok, msg))

    return results


def main():
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <screenshot.png> <viewport_w> <viewport_h>",
              file=sys.stderr)
        sys.exit(2)
    path, vw_s, vh_s = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    p = Path(path)
    if not p.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        sys.exit(2)
    results = assert_screenshot(str(p), vw_s, vh_s)
    failures = [msg for ok, msg in results if not ok]
    for ok, msg in results:
        prefix = "PASS" if ok else "FAIL"
        print(f"{prefix}: {msg}")
    if failures:
        print(f"\n{len(failures)} assertion(s) failed.")
        sys.exit(1)
    print(f"\nAll {len(results)} visual assertions passed.")
    sys.exit(0)


if __name__ == "__main__":
    main()
