# RENEW V1 Visual Direction

## Target

A premium stylized management-simulation presentation: grounded architecture, clean silhouettes, restrained materials, warm restoration highlights, and high information readability on mobile.

The visual target is **stylized realism**, not photorealism and not flat cartoon UI. Every asset must look like it belongs to the same economic-restoration world.

## Visual rules

- Camera: elevated 3/4 management-game view with strong silhouette readability.
- Buildings: believable proportions, simplified secondary detail, clear entrances and windows.
- Restoration: six unmistakable visual states: abandoned, cleaned, repaired, painted, furnished, operational.
- Materials: concrete, brick, painted metal, glass, timber and corrugated roofing; use wear as storytelling.
- Lighting: cool ambient world light with warm operational lights at higher restoration stages.
- Color: dark slate foundation; steel-blue neutrals; restrained amber for active/valuable states; green for positive economic feedback; red-orange only for danger/cost pressure.
- UI: dark glass/slate panels, thin borders, generous spacing, strong hierarchy, consistent interaction states.
- Icons: simple silhouettes with one dominant shape and a small material cue; readable at 24px.
- Characters: semi-realistic stylized portraits with consistent proportions, lighting and framing.
- World map: simplified geography with distinct region palettes and infrastructure overlays; gameplay information must remain readable above decoration.
- HQ progression: each level must be recognisable from silhouette alone.

## Asset production order

1. Property visual system — 3 types x 6 restoration stages.
2. Resource icon family — timber, iron, energy, food, electronics.
3. UI visual theme — buttons, panels, cards, typography hierarchy, feedback states.
4. Employee portrait family — minimum five variants.
5. World-map region artwork.
6. Headquarters progression — five silhouettes.

## Quality gates

Every asset must pass four checks before being considered V1-ready:

1. **Silhouette:** identifiable at thumbnail/mobile scale.
2. **State readability:** the player can tell what changed without reading text.
3. **Style cohesion:** palette, lighting, proportions and detail density match this document.
4. **Engine readiness:** no unnecessary per-frame allocations, excessive draw calls or unreadable contrast.

## Restoration language

Abandoned = damage, weeds, debris, dark glazing, faded surfaces.

Cleaned = debris and weeds reduced; building remains visibly damaged.

Repaired = structural cracks and broken roof elements corrected.

Painted = coherent facade colors, trim and signage begin to appear.

Furnished = interior fixtures, landscaping, exterior equipment and improved lighting communicate investment.

Operational = active signage, warm lights, delivery/worker cues and clean surroundings communicate a productive business.

## Implementation note

V1 art is currently implemented with deterministic Godot drawing primitives so the prototype can ship with a coherent visual system before final external illustrations/3D assets are introduced. The renderer is deliberately data-driven from the existing property state and can later be replaced asset-for-asset without changing restoration gameplay rules.
