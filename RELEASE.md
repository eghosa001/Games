# RENEW V1 – Release Checklist

## ✅ Architecture & State (DONE)
- [x] `GameState` is the single source of truth.
- [x] All systems persist via `GameState`.
- [x] `SaveSystem` uses canonical schema version 8.
- [x] `main.gd` is a thin controller (UI compatibility preserved).

## ✅ Balance (DONE – verified by Day-30 test)
- [x] Furniture production is profitable.
- [x] Starting cash = $35,000.
- [x] Contract terms are fair.
- [x] Loans are repayable.

## 🎨 Art (NEXT)
- [ ] Replace placeholder rectangles with building sprites (3 types, 6 stages each).
- [ ] Add employee portraits (at least 5 variants).
- [ ] Resource icons (timber, iron, energy, food, electronics).
- [ ] UI theme: buttons, panels, background, logo.
- [ ] World map region illustrations.
- [ ] Headquarters visual stages (small office → skyscraper).

## 🔊 Audio (NEXT)
- [ ] UI feedback sounds (tap, success, failure).
- [ ] Background music loop for main screen.
- [ ] Day‐end chime.
- [ ] Construction/restoration ambient sounds.

## 📱 Mobile & Performance (NEXT)
- [ ] Test on 320px, 360px, 480px, 720px, tablet.
- [ ] Play 15 minutes without keyboard.
- [ ] Touch targets ≥ 44x44 points.
- [ ] Frame rate ≥ 30 FPS on low‐end Android.
- [ ] Memory usage stable.

## 📦 Android Build (NEXT)
- [ ] Export APK using Godot 4.x export template.
- [ ] Test on 3 devices (low, mid, high).
- [ ] Verify save/load on device.
- [ ] Check internet permission (if needed for analytics).

## 📝 Store Metadata (NEXT)
- [ ] App name: RENEW.
- [ ] Short description: "Build an empire from a neglected warehouse."
- [ ] Screenshots: restoration, business, world map, alliance.
- [ ] Privacy policy and terms of service.

## 🚀 Alpha / Soft Launch (AFTER)
- [ ] Closed Alpha with 50 testers.
- [ ] Measure D1, D7, D30 retention.
- [ ] Tune difficulty based on feedback.
- [ ] Soft Launch (selected country).
- [ ] Global Launch.

---

**Current Status:** Ready for Art & Audio integration. All code systems are final.
