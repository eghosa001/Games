# RENEW V1 – Release Checklist

## ✅ Architecture & State (DONE)
- [x] `GameState` is the single source of truth.
- [x] All systems persist via `GameState`.
- [x] `SaveSystem` uses canonical schema version 8.
- [x] `main.gd` is a thin controller (UI compatibility preserved).

## ✅ Balance (DONE – verified by existing Day-30 regression coverage)
- [x] Furniture production is profitable.
- [x] Starting cash = $35,000.
- [x] Contract terms are fair.
- [x] Loans are repayable.

## ✅ Presentation & Art (CODE COMPLETE)
- [x] Replace placeholder rectangles with building progression art (3 types, 6 stages each).
- [x] Add employee portraits (5 variants).
- [x] Resource icons (timber, iron, energy, food, electronics).
- [x] Global premium UI theme for buttons, panels and command surfaces.
- [x] Branded world/background presentation and regional empire visualization.
- [x] Headquarters visual progression from Small Office to Global Headquarters.

## ✅ Audio (CODE COMPLETE)
- [x] UI feedback sounds (tap, success, failure).
- [x] Adaptive background music generated at runtime.
- [x] Day-end chime.
- [x] Restoration/construction feedback sounds.

## 📱 Mobile & Performance (DEVICE QA REQUIRED)
- [ ] Test on 320px, 360px, 480px, 720px, tablet hardware.
- [ ] Play 15 minutes without keyboard input on a physical device.
- [x] Touch targets in the employee action panel are ≥ 44x44 points.
- [ ] Confirm frame rate ≥ 30 FPS on low-end Android hardware.
- [ ] Confirm memory usage remains stable on physical Android hardware.

## 📦 Android Build (RELEASE QA REQUIRED)
- [ ] Export/sign the release APK/AAB using the selected Godot 4.x release template.
- [ ] Test on low-, mid- and high-end devices.
- [ ] Verify save/load after app restart on device.
- [ ] Verify final Android permissions and package metadata.

## 📝 Store Metadata (PUBLISHING WORK)
- [x] App name: RENEW.
- [x] Short description: "Build an empire from a neglected warehouse."
- [ ] Capture final screenshots from the release build.
- [ ] Publish privacy policy and terms of service.

## 🚀 Alpha / Soft Launch (POST-BUILD)
- [ ] Closed Alpha with 50 testers.
- [ ] Measure D1, D7, D30 retention.
- [ ] Tune difficulty based on real player data.
- [ ] Soft Launch (selected country).
- [ ] Global Launch.

---

**Current Status:** The V1 game code and presentation systems are feature-complete for an internal release candidate. Remaining items require a runnable Godot build and/or physical-device or store-publishing work; they cannot be truthfully completed through static repository editing alone. Existing automated tests remain in the repository, but this completion pass does not claim a fresh runtime test execution.
