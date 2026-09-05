extends Node2D

## Premium restoration presentation layer.
## The authored restoration scene is the visual foundation; this script adds
## state-driven construction detail, progress, lighting and certification.
## It owns no gameplay state and never mutates the canonical systems.

const STEPS := ["cleaning", "repair", "painting", "furnishing"]
const GOLD := Color("d5b56e")
const GREEN := Color("65b38f")
const TEXT := Color("d7e3e4")
const MUTED := Color("8ba1a3")
const PANEL := Color(0.035, 0.07, 0.08, 0.94)

var _time := 0.0

func _process(delta: float) -> void:
    _time += delta
    queue_redraw()

func _draw() -> void:
    var state = get_node_or_null("/root/RenewGameState")
    if state == null:
        return
    var catalog = state.get_value("properties", "catalog", [])
    if not catalog is Array or catalog.is_empty():
        return
    var index := clampi(int(state.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    var property: Dictionary = catalog[index]
    var owned := bool(state.get_value("properties", "owned", false))
    var stage := _visual_stage(property, owned)
    _sync_scene_art(stage)
    _draw_site_overlay(property, stage)

func _sync_scene_art(stage: String) -> void:
    var scene_art := get_node_or_null("../PremiumRestorationScene")
    if scene_art == null:
        return
    scene_art.visible = true
    var progress := _stage_progress(stage)
    scene_art.modulate = Color(1.0, 1.0, 1.0, 0.78 + progress * 0.20)
    var target_scale := 0.86 + progress * 0.06
    scene_art.scale = Vector2(target_scale, target_scale)

func _stage_progress(stage: String) -> float:
    match stage:
        "Abandoned": return 0.0
        "Cleaned": return 0.24
        "Repaired": return 0.48
        "Painted": return 0.68
        "Furnished": return 0.86
        "Operational": return 1.0
    return 0.0

func _visual_stage(property: Dictionary, owned: bool) -> String:
    if not owned:
        return "Abandoned"
    if int(property.get("cleaning", 0)) < 100:
        return "Abandoned"
    if int(property.get("repair", 0)) < 100:
        return "Cleaned"
    if int(property.get("painting", 0)) < 100:
        return "Repaired"
    if int(property.get("furnishing", 0)) < 50:
        return "Painted"
    if int(property.get("furnishing", 0)) < 100:
        return "Furnished"
    return "Operational"

func _draw_site_overlay(property: Dictionary, stage: String) -> void:
    var viewport_size := get_viewport_rect().size
    var w := maxf(viewport_size.x, 320.0)
    var h := maxf(viewport_size.y, 568.0)
    var progress := _stage_progress(stage)

    # Cinematic vignette keeps the authored SVG scene readable beneath the HUD.
    draw_rect(Rect2(0, h - 116.0, w, 116.0), Color(0.02, 0.04, 0.05, 0.30), true)
    _draw_site_lights(w, h, progress)
    _draw_construction_activity(w, h, progress)
    _draw_stage_banner(w, h, property, stage, progress)
    _draw_progress_card(w, h, property, stage)

func _draw_site_lights(w: float, h: float, progress: float) -> void:
    var intensity := 0.08 + progress * 0.18
    for i in range(7):
        var x := 70.0 + float(i) * maxf(120.0, (w - 140.0) / 6.0)
        var pulse := 0.65 + 0.35 * sin(_time * 1.8 + i * 0.7)
        draw_circle(Vector2(x, h - 74.0), 5.0, Color(GOLD.r, GOLD.g, GOLD.b, intensity * pulse))
        draw_line(Vector2(x, h - 70.0), Vector2(x, h - 54.0), Color(GOLD.r, GOLD.g, GOLD.b, intensity * 0.22), 2.0)

func _draw_construction_activity(w: float, h: float, progress: float) -> void:
    if progress >= 1.0:
        return
    var activity := 1.0 - progress
    var base_y := h - 44.0
    for i in range(4):
        var phase := fmod(_time * (0.10 + i * 0.015) + i * 0.23, 1.0)
        var x := lerpf(-60.0, w + 60.0, phase)
        var y := base_y - float(i % 2) * 18.0
        draw_rect(Rect2(x, y, 34.0, 10.0), Color(0.83, 0.70, 0.40, 0.75 * activity), true)
        draw_circle(Vector2(x + 7, y + 11), 4.0, Color(0.02, 0.05, 0.06, 0.9))
        draw_circle(Vector2(x + 27, y + 11), 4.0, Color(0.02, 0.05, 0.06, 0.9))
    for i in range(5):
        var x := w * 0.58 + float(i) * 34.0
        var sway := sin(_time * 0.9 + i) * 5.0
        draw_line(Vector2(x, h - 120.0), Vector2(x + sway, h - 148.0), Color(MUTED.r, MUTED.g, MUTED.b, 0.28 * activity), 2.0)

func _draw_stage_banner(w: float, h: float, property: Dictionary, stage: String, progress: float) -> void:
    var font := ThemeDB.fallback_font
    var card := Rect2(18.0, h - 104.0, minf(330.0, w - 36.0), 76.0)
    draw_rect(card, PANEL, true)
    draw_rect(Rect2(card.position, Vector2(3, card.size.y)), GOLD if stage == "Operational" else GREEN, true)
    draw_string(font, card.position + Vector2(16, 22), stage.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 32, 16, TEXT)
    draw_string(font, card.position + Vector2(16, 41), str(property.get("name", "Acquired Property")), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 32, 11, MUTED)
    draw_string(font, card.position + Vector2(16, 61), _stage_caption(stage), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 32, 10, TEXT)
    draw_string(font, card.position + Vector2(card.size.x - 58, 22), "%d%%" % int(progress * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 42, 13, GOLD)

func _stage_caption(stage: String) -> String:
    match stage:
        "Abandoned": return "Awaiting acquisition and restoration"
        "Cleaned": return "Site cleared • structural work next"
        "Repaired": return "Structure secured • finishing works next"
        "Painted": return "Exterior complete • fit-out in progress"
        "Furnished": return "Fit-out complete • commissioning"
        "Operational": return "Certified site • ready for commercial use"
    return "Restoration programme active"

func _draw_progress_card(w: float, h: float, property: Dictionary, stage: String) -> void:
    var font := ThemeDB.fallback_font
    var card_w := minf(360.0, w - 36.0)
    var card := Rect2(w - card_w - 18.0, h - 104.0, card_w, 76.0)
    draw_rect(card, PANEL, true)
    draw_rect(card, Color("34545a"), false, 1.0)
    var x := card.position.x + 14.0
    var y := card.position.y + 18.0
    for step in STEPS:
        var value := clampf(float(property.get(step, 0)), 0.0, 100.0)
        draw_string(font, Vector2(x, y), step.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, 64, 9, MUTED)
        draw_rect(Rect2(x + 68, y - 7, maxf(70.0, card.size.x - 124.0), 7), Color("16282e"), true)
        draw_rect(Rect2(x + 68, y - 7, maxf(70.0, card.size.x - 124.0) * value / 100.0, 7), GREEN if value >= 100.0 else GOLD, true)
        draw_string(font, Vector2(card.end.x - 42, y), "%d" % int(value), HORIZONTAL_ALIGNMENT_RIGHT, 28, 9, TEXT)
        y += 14.0

    if stage == "Operational":
        _draw_certification_mark(card)

func _draw_certification_mark(card: Rect2) -> void:
    var center := Vector2(card.end.x - 22.0, card.position.y - 8.0)
    draw_circle(center, 9.0, GOLD)
    draw_circle(center, 6.0, PANEL)
    draw_line(center + Vector2(-3, 0), center + Vector2(-1, 3), GOLD, 1.5)
    draw_line(center + Vector2(-1, 3), center + Vector2(4, -3), GOLD, 1.5)

func _business_purposes() -> Array:
    var state = get_node_or_null("/root/RenewGameState")
    if state == null:
        return []
    var type := ""
    var catalog = state.get_value("properties", "catalog", [])
    if catalog is Array and not catalog.is_empty():
        var index := clampi(int(state.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
        type = str(catalog[index].get("type", ""))
    var options := {
        "Warehouse": ["Furniture Factory", "Distribution Center", "Wholesale Hub"],
        "Workshop": ["Furniture Factory", "Metalworks", "Construction Workshop"],
        "Commercial Building": ["Retail Store", "Service Office", "Showroom"]
    }
    var result: Array = []
    for name in options.get(type, []):
        result.append({"name": name})
    return result
