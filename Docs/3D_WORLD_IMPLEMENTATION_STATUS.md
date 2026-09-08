# RENEW — 3D World Implementation Status

> **Updated:** 2026-09-08
> **Current milestone:** 3D-P1 Technical Prototype — IN PROGRESS
> **Primary roadmap:** `Docs/3D_WORLD_VISUAL_ROADMAP.md`

## What has now been implemented

### 3D-P1 foundation

- Added `scripts/world_3d_view.gd` as the first reusable 3D presentation layer.
- The prototype creates a Godot 3D environment at runtime rather than replacing the existing simulation scene.
- Added a strategic camera and directional lighting.
- Added a small prototype district containing:
  - terrain
  - roads
  - headquarters
  - factory/workshop
  - warehouse
  - resource site
- Added simple 3D labels for major locations.
- Added collision bodies so prototype properties can be selected with a 3D raycast.
- Added an on-screen 3D status/selection overlay.

### Simulation boundary

The 3D layer is presentation-only.

It does **not** own:

- cash
- inventory
- production
- contracts
- ownership
- employees
- finance
- regional economic rules

When a real GameState property catalog exists, the prototype reads its real property IDs and synchronizes selection back to `GameState.properties.selected_property`.

This preserves the existing architectural rule that persistent truth belongs to GameState and gameplay systems.

### Existing game integration

A new `3D` / `3D WORLD` launcher action was added to `RegionsLauncher`.

Opening it:

1. creates/reuses the 3D world presentation node;
2. temporarily hides the existing 2D world presentation nodes;
3. leaves simulation controllers and management systems intact;
4. displays the 3D prototype;
5. restores the previous 2D presentation when closed.

ESC closes the 3D presentation.

### Automated coverage

`tests/test_ui_architecture.gd` now verifies:

- the 3D world is mounted;
- the open/close/toggle API exists;
- the prototype starts hidden;
- it can open and close;
- it creates a Camera3D;
- selectable prototype objects are present.

## Current limitations — intentionally P1

This is **not yet the final 3D game**.

The following are deliberately deferred:

- production-quality models
- real city terrain
- streamed regions
- real vehicle simulation visuals
- crowds and named employees
- restoration-stage meshes
- real building interiors
- advanced materials
- weather
- day/night presentation
- LOD/occlusion/instancing optimization
- complete property/business/branch visual registry
- camera level transitions
- cinematic presentation

These belong to P2 onward and must be implemented against the authoritative simulation instead of creating parallel gameplay state.

## P1 exit criteria

P1 is considered complete only when all of the following are true:

- [x] 3D scene can be opened from the existing game.
- [x] Existing 2D world can be restored safely.
- [x] Camera and lighting exist.
- [x] Prototype buildings and roads exist.
- [x] 3D properties carry entity IDs.
- [x] Real GameState property IDs are consumed when available.
- [x] Selection can synchronize to `GameState.properties.selected_property`.
- [x] Automated architecture coverage exists.
- [ ] CI confirms the new test and project parse cleanly.
- [ ] Browser/Web export confirms no runtime regression.
- [ ] Existing property-management interaction is opened directly from a selected 3D property.

The final two items are the remaining P1 integration gate before moving to P2.

## Next implementation sequence

### 3D-P1 completion

1. Verify Godot CI.
2. Verify Web export/browser QA.
3. Connect a selected 3D property to the existing Property Map/management surface.
4. Add camera controls suitable for touch and mouse.
5. Add a clean close/back affordance on mobile.

### 3D-P2 — Property Visualization

Build the first genuinely game-facing 3D property pipeline:

- real property registry
- property-to-3D visual registry
- restoration stage mapping
- derelict/clean/repair/paint/furnish/operational visual states
- construction/scaffolding variants
- property information context panel
- camera transition from strategic district view to property view

### 3D-P3 — Economic District

Then expose the existing economic simulation physically:

- factories
- warehouses
- retail
- resource sites
- logistics hubs
- roads
- infrastructure
- loading/unloading activity
- production activity indicators
- supply-chain movement

### 3D-P4 — Living City

Then add presentation agents:

- workers
- customers
- traffic
- construction crews
- day/night
- weather

Distant activity will remain aggregated for performance.

### 3D-P5 — Empire Scale

Then connect multiple regions, strategic camera levels, trade corridors, ports and competitor facilities.

### 3D-P6/P7/P8

Only after the world simulation and performance foundations are stable:

- hero locations
- named-character presentation
- interiors
- advanced lighting/materials
- weather polish
- cinematic camera work
- platform-specific optimization

## Non-negotiable rule

**The 3D world is the body of RENEW; the existing simulation is its brain.**

A beautiful building must still represent a real property. A factory animation must reflect production state. A delivery truck must represent real logistics activity. A selected employee must resolve to a real EmployeeSystem record.

Never create a second economic simulation merely to make the world look alive.
