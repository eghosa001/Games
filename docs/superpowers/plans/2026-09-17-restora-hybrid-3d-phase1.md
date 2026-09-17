# Restora Hybrid 3D Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a performant stylized 3D property presentation to Restora while preserving the existing economy, game-state, save/load and 2D management UI.

**Architecture:** Keep `RenewGameState` and current systems authoritative. A new `World3D` subtree reads a small visual snapshot and mirrors property/restoration/business state into a procedural low-poly building, environment and camera. Existing CanvasLayer UI remains above the 3D world and no new persistent state is introduced.

**Tech Stack:** Godot 4.x, GDScript, Node3D/MeshInstance3D/Camera3D, StandardMaterial3D, GL Compatibility renderer.

**Spec:** `docs/superpowers/specs/2026-09-17-restora-hybrid-3d-design.md`

## Global Constraints

- Preserve `renderer/rendering_method="gl_compatibility"` and mobile GL Compatibility.
- Do not change save schema or authoritative simulation state.
- Keep existing management CanvasLayers functional.
- Use primitive/low-poly geometry and shared materials; no imported high-poly assets in phase 1.
- No per-frame mesh rebuilding.
- Automated tests remain short and renderer-independent.

---

### Task 1: Visual state mapping and regression tests

**Files:**
- Create: `scripts/restora_3d_visual_state.gd`
- Create: `tests/test_restora_3d_visual_state.gd`

**Interfaces:**
- Produces: `Restora3DVisualState.stage_from_state(state: Dictionary) -> String`
- Produces: `Restora3DVisualState.archetype_from_property(property: Dictionary) -> String`
- Produces: `Restora3DVisualState.snapshot_from_game_state(state: Node) -> Dictionary`

- [ ] **Step 1: Write the failing test** covering stage mapping, archetype mapping and empty-catalog fallback.
- [ ] **Step 2: Run only `tests/test_restora_3d_visual_state.gd` and verify failure is caused by the missing production script.**
- [ ] **Step 3: Implement the minimal pure mapping/snapshot helper.**
- [ ] **Step 4: Run the focused test and verify it passes.**
- [ ] **Step 5: Commit.**

### Task 2: Procedural 3D property presenter

**Files:**
- Create: `scripts/property_3d_presenter.gd`
- Create: `scenes/Property3D.tscn`
- Create: `tests/test_property_3d_presenter.gd`

**Interfaces:**
- Consumes: visual snapshot from `restora_3d_visual_state.gd`
- Produces: `apply_snapshot(snapshot: Dictionary, animate := true) -> void`
- Produces: `get_visual_stage() -> String`

- [ ] **Step 1: Write a headless-safe test** that instantiates the presenter and verifies stage/archetype state can be applied without needing renderer assertions.
- [ ] **Step 2: Run the focused test and verify it fails before the presenter exists.**
- [ ] **Step 3: Implement a low-poly warehouse foundation from primitive meshes: slab, walls, roof, loading doors, sign, windows and simple site props.**
- [ ] **Step 4: Add shared materials for neglected, repaired, painted and operational states; toggle details rather than rebuilding meshes each frame.**
- [ ] **Step 5: Add lightweight transition tweening for stage changes and operational lights/signage.**
- [ ] **Step 6: Run the focused test and verify it passes.**
- [ ] **Step 7: Commit.**

### Task 3: World controller, environment and camera

**Files:**
- Create: `scripts/restora_world_3d_controller.gd`
- Create: `scenes/RestoraWorld3D.tscn`
- Create: `tests/test_restora_world_3d_controller.gd`

**Interfaces:**
- Consumes: `/root/RenewGameState`
- Consumes: `Property3DPresenter.apply_snapshot(snapshot, animate)`
- Produces: low-frequency visual synchronization and camera focus behavior.

- [ ] **Step 1: Write a headless-safe initialization/fallback test** for a controller with no game-state node.
- [ ] **Step 2: Run the focused test and verify failure before implementation.**
- [ ] **Step 3: Add WorldEnvironment, one DirectionalLight3D, ground/road dressing and an angled Camera3D rig.**
- [ ] **Step 4: Implement low-frequency snapshot polling and update only when the visual snapshot changes.**
- [ ] **Step 5: Add establishing/focus/detail camera targets with tweened movement; gameplay input remains outside the camera controller.**
- [ ] **Step 6: Run the focused test and verify it passes.**
- [ ] **Step 7: Commit.**

### Task 4: Main-scene integration and 2D fallback behavior

**Files:**
- Modify: `scenes/Main.tscn`
- Modify: `scripts/property_visual.gd`
- Create: `tests/test_restora_3d_scene_integration.gd`

**Interfaces:**
- `Main.tscn` instantiates `RestoraWorld3D.tscn` under the root, before UI layers.
- Existing `PropertyVisual` keeps status/progress overlay but suppresses duplicate main-building artwork when 3D is active.

- [ ] **Step 1: Write a scene-structure test** asserting `World3D` and existing `UI` both exist and the 3D controller can be disabled without removing gameplay controllers.
- [ ] **Step 2: Run the focused test and verify it fails before scene integration.**
- [ ] **Step 3: Add the 3D scene to `Main.tscn` while leaving the current `World` controllers and all CanvasLayers intact.**
- [ ] **Step 4: Update `property_visual.gd` so its status/progress overlay remains but duplicate building art is hidden while `World3D` is active.**
- [ ] **Step 5: Run the focused integration test.**
- [ ] **Step 6: Run the existing short/fast test entry point plus the new four focused tests.**
- [ ] **Step 7: Commit.**

### Task 5: Verification and release-safety check

**Files:**
- Modify only if verification exposes a defect.

- [ ] **Step 1: Verify `project.godot` still uses GL Compatibility and the save schema/version is unchanged.**
- [ ] **Step 2: Verify no existing finance, production, contract or save/load file was modified by this phase.**
- [ ] **Step 3: Verify the branch diff contains only the intended 3D presentation, tests and documentation changes.**
- [ ] **Step 4: Check CI/status for the latest branch commit and report any renderer-only validation that still requires a rendered Godot run.**
