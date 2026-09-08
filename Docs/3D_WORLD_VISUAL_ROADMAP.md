# RENEW — 3D World & Visual Evolution Roadmap

> **Status:** Planned long-term product direction
> **Relationship to V1:** This roadmap extends the existing simulation and UI architecture. It does not replace the V1 build sequence.
> **Core rule:** Build the simulation first, then progressively expose the same authoritative state through a richer 3D world.

---

## 1. Vision

RENEW will evolve from a management-heavy economic simulation into a **3D economic empire simulator** without throwing away the systems already being built.

The long-term player experience should move naturally between levels of scale:

**GLOBAL WORLD → REGION → CITY → DISTRICT → PROPERTY → BUILDING → BUSINESS → PEOPLE**

The 3D layer is the visual representation of the simulation. It must not become a second economy.

The existing systems remain the game's brain:

- GameState
- Property
- Business
- Branch
- Employees
- Economy
- Resources
- Production
- Supply Chain
- Contracts
- Competitors
- Ownership
- Finance
- Alliances
- Diplomacy
- Infrastructure
- Technology
- World Events
- History
- Progression

The new visual layer becomes the world's body and senses:

- terrain
- cities
- roads
- factories
- warehouses
- offices
- shops
- ports
- farms
- mines
- vehicles
- employees
- customers
- construction
- restoration stages
- weather
- lighting
- cameras
- animation
- environmental storytelling

---

## 2. Important technical decision

**Godot is capable of supporting this visual direction.** The current limitation is not the engine. The current RENEW project has primarily been constructed as a UI/map-driven simulation, so the 3D presentation layer must be introduced deliberately.

Do not attempt to convert the entire project to 3D in one rewrite.

The migration must be incremental:

1. Stabilize the simulation and current UI.
2. Introduce a reusable 3D world renderer.
3. Connect 3D objects to authoritative entities.
4. Add camera/detail levels.
5. Add buildings, people and vehicles.
6. Add environmental simulation.
7. Add richer interactions and interiors.
8. Optimize for Android, tablet and desktop.
9. Only then consider cinematic/high-end visual features.

The existing 2D management interface remains available throughout the transition.

---

# 3. Target player experience

## 3.1 Strategic view

The player can see the entire empire from above:

- regions
- cities
- owned properties
- branches
- infrastructure
- resource locations
- trade routes
- competitors
- ports
- factories
- major construction projects

The strategic layer communicates economic geography at a glance.

## 3.2 Regional view

Zooming into a region reveals:

- cities and towns
- roads and rail
- industrial zones
- agricultural areas
- mines and extraction sites
- warehouses
- logistics hubs
- company branches
- competitor facilities
- infrastructure projects

Regional changes caused by the simulation should become visually visible.

## 3.3 City view

Cities should become living economic environments rather than static map labels.

Examples:

- employees commute
- trucks move goods
- factories operate
- construction sites develop
- stores receive deliveries
- customers visit businesses
- traffic responds to infrastructure
- districts visibly change as investment increases

## 3.4 Property view

Selecting a property opens a close 3D view showing its physical state.

A property can visually progress through:

**DERELICT → CLEANING → REPAIR → RESTORATION → OPERATIONAL → UPGRADED → PREMIUM**

The visual state must be driven by the same restoration/property data used by gameplay.

## 3.5 Business view

A functioning business should visibly communicate its activity:

- workers present
- machinery operating
- inventory movement
- loading/unloading
- offices active
- deliveries arriving
- customers served
- maintenance activity

The player should be able to understand business performance without opening every menu, while detailed numbers remain available in the management UI.

## 3.6 People view

Employees eventually become visible characters rather than only records.

A character can have:

- role
- uniform/style
- workplace
- shift
- movement
- task
- morale/reputation cues where appropriate
- career progression

The simulation remains authoritative; characters are presentation agents driven by simulation state.

---

# 4. Visual architecture

Create a separate presentation layer rather than putting 3D logic into economic systems.

Recommended future structure:

```text
WorldPresentation
├── World3D
│   ├── Terrain
│   ├── Regions
│   ├── Cities
│   ├── Districts
│   ├── Roads
│   ├── Infrastructure
│   ├── Properties
│   ├── Businesses
│   ├── Resources
│   ├── Vehicles
│   └── Characters
├── CameraSystem
├── SelectionSystem
├── EntityVisualRegistry
├── LODSystem
├── EnvironmentSystem
├── WeatherPresentation
├── LightingSystem
└── WorldInteractionBridge
```

The 3D presentation layer reads snapshots or queries from authoritative systems.

It must not independently mutate:

- cash
- inventory
- production
- ownership
- employee records
- contracts
- finance
- regional state

Player actions originating in 3D must be sent back through the same command/system APIs used by the existing UI.

---

# 5. Camera hierarchy

The camera system should support progressive levels of detail.

### Level 0 — Empire

High altitude strategic map.

Visible:

- regions
- borders
- major assets
- trade corridors
- resource areas
- strategic alerts

### Level 1 — Region

Medium altitude.

Visible:

- cities
- infrastructure
- businesses
- properties
- transport networks

### Level 2 — City

Low altitude.

Visible:

- districts
- roads
- buildings
- vehicles
- employees/crowds

### Level 3 — Property

Close camera.

Visible:

- building details
- restoration state
- machinery
- workers
- entrances
- landscaping

### Level 4 — Interior

Optional later feature.

Visible:

- offices
- factories
- stores
- warehouses
- HQ rooms
- museums

Not every property needs an interior. Interior scenes should be reserved for important or player-owned locations where the detail provides gameplay value.

---

# 6. World-to-simulation binding

Every visible economic object should have an authoritative identity.

Example:

```text
3D Property Node
    ↓
property_id
    ↓
PropertySystem / GameState
```

Likewise:

```text
3D Factory
    ↓
business_id + property_id + branch_id
    ↓
BusinessSystem / ProductionSystem / BranchSystem
```

And:

```text
3D Employee
    ↓
employee_id
    ↓
EmployeeSystem
```

The visual registry should be able to answer:

- Which simulation entity does this object represent?
- Is it currently active?
- What visual state should it have?
- What level of detail is required?
- Which interaction is available?

Destroyed, sold, acquired, upgraded or relocated entities must update their visual representation automatically.

---

# 7. Buildings and asset pipeline

Create a standardized asset pipeline before producing hundreds of models.

Every building asset should have:

- low-detail model
- medium-detail model
- high-detail model where justified
- collision mesh
- interaction points
- material definitions
- texture set
- LOD thresholds
- optional night/emission state
- construction/restoration variants

Initial building families:

1. headquarters
2. office
3. factory
4. warehouse
5. retail store
6. workshop
7. farm
8. mine/extraction site
9. power/energy facility
10. port/logistics hub
11. research facility
12. residential/city background buildings
13. civic/infrastructure buildings
14. historic/special properties

Do not model every background building at hero quality. Use modular kits and LODs.

---

# 8. Restoration visuals

Restoration is one of the strongest opportunities for visual storytelling.

A property should visibly change after major actions.

### Stage 1 — Inspection

- damaged surfaces
- clutter
- broken windows
- vegetation/neglect
- construction barriers

### Stage 2 — Cleaning

- debris removed
- site organized
- temporary equipment appears

### Stage 3 — Structural repair

- scaffolding
- repaired walls
- roof work
- structural equipment

### Stage 4 — Installation

- machinery arrives
- utilities installed
- interior activity begins

### Stage 5 — Opening

- signage
- lighting
- staff
- deliveries
- customers

### Stage 6 — Premium restoration

- upgraded materials
- landscaping
- architectural lighting
- polished exterior
- stronger visual identity

These stages should be driven by restoration/property state rather than manually toggled by presentation code.

---

# 9. Living economic world

The world should eventually feel alive because simulation activity creates visible activity.

## Employees

- commute to branches
- enter workplaces
- work shifts
- move between departments where practical

## Logistics

- trucks leave warehouses
- deliveries travel between facilities
- loading bays become active
- ports handle shipments

## Production

- factories show operational states
- machinery lights/effects indicate activity
- production intensity affects visible activity

## Retail

- customers enter stores
- deliveries arrive
- store activity reflects demand

## Construction

- construction sites progress through stages
- cranes/scaffolding appear where appropriate
- completed infrastructure replaces temporary works

The system should use simulation-level abstractions for distant activity instead of simulating thousands of individual agents.

---

# 10. Characters

Character development should happen after the economic world and property visuals are stable.

### Character tiers

**Tier 1:** simple animated silhouettes/low-detail workers for distant crowds.

**Tier 2:** recognizable worker characters near player-owned facilities.

**Tier 3:** higher-detail named employees for important characters.

**Tier 4:** fully featured executive/hero characters for major story events.

Named employees should remain connected to the EmployeeSystem.

Character appearance should be data-driven enough to avoid manually creating one asset per employee.

---

# 11. Vehicles and logistics visualization

Vehicles should be introduced only after route and supply-chain data is stable.

Initial vehicle categories:

- delivery van
- truck
- heavy truck
- construction vehicle
- passenger/company vehicle
- train/freight where rail infrastructure supports it
- ship where ports support it

At long distance, vehicles can be represented as aggregated flows.

At close range, actual animated vehicles can be shown.

This prevents the game from wasting CPU/GPU resources simulating visual objects the player cannot see.

---

# 12. Lighting, weather and atmosphere

The visual world should eventually support:

- day/night cycle
- sun direction
- artificial building lights
- weather states
- rain
- fog/haze
- environmental variation
- seasonal visual changes where economically useful

Weather must only affect gameplay when a corresponding simulation rule exists. Visual rain must not secretly change production or logistics.

When weather does affect gameplay, the causal chain should be explicit:

**World Event → Weather State → Infrastructure/Logistics Modifier → Economic Consequence → Visual Feedback**

---

# 13. UI + 3D coexistence

The current premium corporate UI remains important.

The future interface should combine:

**3D WORLD + MANAGEMENT HUD + CONTEXT PANEL**

Example:

```text
┌─────────────────────────────────────────┐
│ CASH   DEBT   REVENUE   DAY   ALERTS    │
├───────────────────────┬─────────────────┤
│                       │ FACTORY         │
│       3D WORLD        │ Status: Running │
│                       │ Output: 84%     │
│                       │ Staff: 42       │
│                       │ Margin: 18%     │
│                       │ [OPERATIONS]    │
│                       │ [UPGRADE]       │
└───────────────────────┴─────────────────┘
```

The management panels already being built should remain accessible from the 3D world.

Examples:

- select factory → Production Control
- select warehouse → Supply Chain
- select employee → Employee Management
- select property → Property/Restoration
- select competitor facility → Corporation/Intelligence
- select region → Regions
- select HQ → Headquarters
- select finance indicator → Finance

This prevents the 3D world from becoming a disconnected showcase.

---

# 14. Performance strategy

RENEW must remain usable on Android devices.

### Required techniques

- LOD meshes
- occlusion culling where beneficial
- visibility ranges
- instancing for repeated assets
- texture atlases where useful
- compressed textures
- pooled vehicles/agents
- distance-based simulation detail
- aggregated distant traffic
- simplified distant buildings
- limited active animations
- asynchronous loading for large scenes
- scene streaming for large cities

### Performance tiers

#### Mobile Low

- low-detail environment
- aggressive LOD
- limited pedestrians
- simplified shadows
- reduced effects
- smaller draw distance

#### Mobile High / Tablet

- medium environment detail
- moderate shadows
- more vehicles/characters
- better effects

#### Desktop

- higher LOD distances
- more detailed materials
- stronger lighting
- denser world activity
- optional cinematic effects

The simulation tick must remain independent of rendering FPS.

---

# 15. Asset quality target

The visual goal is **premium simulation realism**, not blindly copying another game's art style.

RENEW should have its own identity:

- sophisticated corporate architecture
- believable industrial environments
- rich city districts
- high-quality materials
- clean readable interfaces
- restrained cinematic presentation
- strong restoration transformations
- visually understandable economic activity

The goal is not simply “more polygons.”

The target is:

**A world where the player's economic decisions visibly transform places and businesses.**

---

# 16. Development phases

## 3D-P0 — Preparation

Before adding a large 3D world:

- finish the current V1 screen/panel build
- stabilize command routing
- stabilize GameState ownership
- stabilize save/load
- establish entity IDs
- remove duplicate sources of truth
- document current region/property/business relationships

**Exit criteria:** simulation remains authoritative and testable without 3D.

## 3D-P1 — Technical prototype

Build one small 3D scene containing:

- one region
- one city
- one road
- one player property
- one business
- one warehouse
- one resource location
- basic camera
- selection
- UI overlay

Use placeholder/modular assets initially.

**Exit criteria:** clicking a visible property identifies the same property in GameState and opens its existing management panel.

## 3D-P2 — Property visualization

Add:

- restoration stages
- building states
- property selection
- construction visuals
- basic lighting
- camera transitions

**Exit criteria:** restoration actions visibly change the property.

## 3D-P3 — Economic district

Add:

- factories
- warehouses
- retail
- roads
- logistics movement
- resource sites
- infrastructure visualization

**Exit criteria:** production and logistics activity can be visually observed and matches simulation state.

## 3D-P4 — Living city

Add:

- workers
- customers
- traffic
- construction activity
- day/night
- basic weather

**Exit criteria:** a city appears active without requiring thousands of simulated entities.

## 3D-P5 — Empire scale

Add:

- multiple regions
- region transitions
- strategic camera
- trade routes
- ports
- major infrastructure
- competitor presence

**Exit criteria:** the player can navigate the empire from strategic scale to a selected property.

## 3D-P6 — High-detail hero locations

Add detailed scenes for:

- headquarters
- flagship businesses
- historic properties
- major factories
- museum/legacy locations

**Exit criteria:** selected important locations provide meaningful close-up visual experiences.

## 3D-P7 — Interior layer

Optional, later:

- HQ interior
- factory interior
- retail interior
- museum interior
- executive offices

**Exit criteria:** interiors add meaningful interaction rather than becoming decorative loading screens.

## 3D-P8 — Visual polish and optimization

- materials
- animation polish
- lighting polish
- sound hooks
- weather polish
- camera polish
- mobile optimization
- desktop quality tier
- loading/streaming improvements

**Exit criteria:** stable target performance across supported hardware classes.

---

# 17. What must NOT happen

Do not:

- rewrite the simulation just to make it 3D
- create a second economy inside the 3D scene
- hard-code property/business values into models
- simulate every visible pedestrian as a full economic entity
- require high-end hardware for basic gameplay
- abandon the mobile-first principle
- replace functional management panels with decorative 3D screens
- make 3D visuals a prerequisite for core simulation tests
- create hundreds of bespoke assets before the pipeline is proven
- sacrifice save compatibility for visual experiments

---

# 18. Acceptance criteria for the final visual direction

The long-term 3D implementation is successful when all of the following are true:

1. The player can see the empire at strategic scale.
2. Regions contain visually distinct cities and economic zones.
3. Player properties have physical 3D representations.
4. Restoration visibly transforms properties.
5. Businesses visibly operate.
6. Supply chains visibly move goods at an appropriate abstraction level.
7. Infrastructure visibly changes regional connectivity/capacity.
8. Employees can eventually be seen in important locations.
9. Competitors have visible economic presence.
10. Selecting a 3D object opens the same authoritative management systems already used by the 2D UI.
11. Every major visual state is derived from GameState/system APIs.
12. The simulation remains deterministic and testable independently of rendering.
13. Mobile remains a first-class target.
14. Desktop can use higher visual quality without changing gameplay rules.
15. Save/load remains compatible through the visual evolution.
16. 3D performance does not cause the simulation clock to run faster or slower.
17. The world looks substantially richer because of simulation-driven activity, not merely decorative effects.

---

# 19. Relationship to the existing build rule

The project continues to follow:

> **BUILD EVERYTHING → THEN AUDIT**

The 3D roadmap is therefore a **future visual-development track**, not permission to stop the current V1 screen/panel build and begin a risky rewrite.

The immediate sequence remains:

**Complete V1 UI/UX → connect every action → finish responsive/mobile presentation → stabilize core architecture → introduce 3D-P0/P1 → expand the 3D world incrementally → comprehensive audit.**

The long-term objective is a RENEW world where the existing economic simulation is not hidden behind menus: **the player can see the economy operating in the world.**
