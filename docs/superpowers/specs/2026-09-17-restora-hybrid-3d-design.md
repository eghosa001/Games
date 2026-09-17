# Restora Hybrid 3D Presentation Design

Date: 2026-09-17
Branch: `restora-hybrid-3d`

## Goal

Transform Restora from a primarily 2D presentation into a premium stylized hybrid 3D management game without rewriting the existing economy, business, finance, contracts, progression, save/load, or competitor simulation systems.

The 3D layer is a presentation system. Existing game state remains authoritative.

## Design Direction

Use stylized mobile 3D for the world and restoration payoff while preserving clean 2D management interfaces.

### 3D

- abandoned/restored properties
- warehouse, factory, retail, office/HQ and resource-site archetypes
- roads, lots, simple district dressing and environmental props
- construction/restoration progression
- workers, vehicles and machinery represented by lightweight ambient actors
- camera focus transitions between selected properties
- opening, upgrade and operational-state visual feedback

### 2D

- dashboard
- finance and loans
- inventory/production details
- staff management
- pricing
- contracts
- supplier choices
- corporation/diplomacy screens
- research and detailed reports

## Architecture

```text
RenewGameState / existing simulation systems
                |
                v
      RestoraWorld3DController
                |
      +---------+----------+
      |                    |
      v                    v
Property3DPresenter   AmbientWorld3D
      |                    |
      v                    v
Building meshes       vehicles/workers/FX

Existing CanvasLayer UI remains above the 3D world.
```

No simulation system will depend on a 3D node. The 3D controller reads public state through `RenewGameState` and mirrors it visually.

## Scene Structure

The root remains compatible with the existing application and controllers, but a new `Node3D` presentation subtree is added under the current world boundary.

```text
Renew (existing root)
├── World (existing Node2D systems/controllers)
├── World3D (Node3D)
│   ├── Environment
│   ├── CameraRig
│   │   └── Camera3D
│   ├── Sun
│   ├── Properties
│   │   └── ActiveProperty3D
│   ├── DistrictDressing
│   ├── AmbientActors
│   └── Effects
└── UI (existing CanvasLayer tree)
```

During migration, the old `PropertyVisual` can remain as a fallback but will stop drawing the main building when the 3D presentation is active.

## Property Presentation

Create a reusable `Property3DPresenter` that maps the existing property type and restoration state to a stylized procedural model.

Initial archetypes:

1. Warehouse
2. Factory / industrial
3. Office / headquarters
4. Retail
5. Resource site

The first implementation uses Godot primitive meshes and procedural materials rather than external high-poly assets. This keeps the repository self-contained and allows rapid iteration before final authored art is introduced.

### Restoration stages

Existing state remains the source of truth. Visual stages map as follows:

- Neglected / Abandoned: dirty muted materials, broken/disabled details, sparse lighting
- Cleaned: debris removed, site cleared
- Repaired: stronger structure, repaired roof/walls
- Painted: finished facade and brighter materials
- Furnished: props/signage/equipment appear
- Operational: full lights, signage, vehicles/workers and active machinery

Transitions should animate rather than instantly replacing the whole scene: material blending, scale/pop-in for repaired components, construction particles and brief camera emphasis.

## Camera

Add a lightweight camera rig with three modes:

- Establishing: default angled property overview
- Focus: smooth move toward the selected building/property
- Detail: closer view used during restoration/open/upgrade moments

The camera must never own gameplay input. UI and gameplay commands remain routed through existing controllers.

Mobile controls for the first phase are intentionally limited to property selection and optional drag orbit. Pinch zoom and free-roam navigation are deferred until the base presentation is stable.

## Ambient Motion

To create life without expensive simulation:

- pooled low-poly trucks follow short predefined paths
- workers use simple billboard/low-poly actors with looping motion
- machinery uses deterministic rotation/translation loops
- windows/signage activate only when operational
- construction dust/sparks use low particle counts

Ambient actors are visual only and never modify economy or production state.

## UI Integration

Existing `CanvasLayer` screens stay authoritative for management actions. The 3D viewport sits behind them.

When a large management panel is open, the camera can subtly shift the property to the unobstructed side of the viewport. This avoids excessive dead space and prevents the 3D focal object from being hidden by panels.

## Performance Targets

Primary target: Android mobile using Godot GL Compatibility.

Initial budgets:

- one main directional light
- minimal realtime shadows; important buildings only
- primitive/low-poly geometry
- shared StandardMaterial3D resources
- no post-processing dependency for core readability
- pooled ambient actors
- capped particles
- no per-frame rebuilding of meshes
- 60 FPS target on capable devices; presentation must remain usable at 30 FPS

The implementation must preserve the repository's current GL Compatibility renderer.

## State Synchronization

`RestoraWorld3DController` polls a small visual snapshot at a low frequency and reacts only when relevant values change:

- selected property
- ownership
- property type
- restoration/stage
- cleaning
- repair
- painting
- furnishing
- business open state

This avoids adding invasive signals to `game_state.gd` during the first phase.

If polling proves insufficient later, a dedicated visual-state signal can be introduced as a separate change.

## Failure / Fallback Behavior

- If property catalog data is missing, show the default warehouse archetype.
- If the 3D presentation cannot resolve state, keep the world visible in its default neglected state rather than crashing.
- Existing 2D UI remains functional even if the 3D subtree is disabled.
- Save files are unchanged because no new authoritative state is required for phase one.

## Initial Implementation Slice

Phase 1 will produce a playable 3D foundation rather than attempting the entire game world at once:

1. Add `World3D` to `Main.tscn` behind the existing UI.
2. Add a reusable procedural warehouse/property presenter.
3. Add environment, lighting, ground and camera rig.
4. Synchronize the first property's existing restoration state into 3D.
5. Add animated visual transitions for restoration and operational state.
6. Keep all current management CanvasLayers intact.
7. Disable only the duplicate 2D main-building presentation when 3D is active.
8. Add short focused tests for stage mapping, state snapshot generation and safe fallback behavior.

After this foundation is verified, subsequent slices can add factory/retail/HQ/resource variants, district presentation and ambient logistics.

## Testing

Tests will be intentionally short and targeted:

- restoration stage -> visual stage mapping
- property type -> archetype mapping
- missing/empty catalog fallback
- controller can initialize in headless mode without renderer-dependent assertions
- existing fast game-state tests remain unchanged

Visual quality itself will be checked in a rendered Godot run rather than turning the automated suite into a long renderer test.

## Non-Goals for Phase 1

- rewriting economy/business logic
- replacing the existing save schema
- full open-world navigation
- physics-driven workers or vehicles
- high-poly imported art
- converting finance/dashboard panels into 3D
- changing monetization or progression rules

## Acceptance Criteria

Phase 1 is complete when:

- the first property is visibly rendered as stylized 3D in the main game
- restoration changes visibly progress the 3D property through existing state
- opening the business makes the property visibly active
- existing 2D management screens continue to work above the world
- no save migration is required
- focused tests pass
- the 3D system can be disabled without breaking gameplay
