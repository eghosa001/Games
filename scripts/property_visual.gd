extends Node2D

## Phase 18/19 presentation layer.
## Reads canonical GameState.properties and businesses. It owns no gameplay state.

const STEPS := ["cleaning", "repair", "painting", "furnishing"]

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var state = get_node_or_null("/root/RenewGameState")
    if state == null: return
    var catalog = state.get_value("properties", "catalog", [])
    if not catalog is Array or catalog.is_empty(): return
    var index: Variant = clampi(int(state.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    var property: Dictionary = catalog[index]
    var owned: Variant = bool(state.get_value("properties", "owned", false))
    var stage: Variant = _visual_stage(property, owned)
    _sync_scene_art(stage)
    _draw_property(Vector2(650, 585), property, stage)

func _sync_scene_art(stage: String) -> void:
    var scene_art := get_node_or_null("../PremiumRestorationScene")
    if scene_art == null:
        return
    var active := stage != "Operational"
    scene_art.visible = active
    if not active:
        return
    var progress := _stage_progress(stage)
    scene_art.modulate = Color(1.0, 1.0, 1.0, 0.72 + progress * 0.24)
    var target_scale := 0.84 + progress * 0.08
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
    if not owned: return "Abandoned"
    if int(property.get("cleaning", 0)) < 100: return "Abandoned"
    if int(property.get("repair", 0)) < 100: return "Cleaned"
    if int(property.get("painting", 0)) < 100: return "Repaired"
    if int(property.get("furnishing", 0)) < 50: return "Painted"
    if int(property.get("furnishing", 0)) < 100: return "Furnished"
    return "Operational"

func _draw_property(origin: Vector2, property: Dictionary, stage: String) -> void:
    var type: Variant = str(property.get("type", "Warehouse"))
    var cleaning: Variant = clampf(float(property.get("cleaning", 0)), 0.0, 100.0)
    var repair: Variant = clampf(float(property.get("repair", 0)), 0.0, 100.0)
    var painting: Variant = clampf(float(property.get("painting", 0)), 0.0, 100.0)
    var furnishing: Variant = clampf(float(property.get("furnishing", 0)), 0.0, 100.0)
    var cleanliness: Variant = cleaning / 100.0
    var repair_amount: Variant = repair / 100.0
    var paint_amount: Variant = painting / 100.0
    var furnish_amount: Variant = furnishing / 100.0

    var wall: Variant = Color("555d63").lerp(Color("b8c4ca"), paint_amount).lerp(Color("cbd7dc"), furnish_amount * 0.18)
    var roof: Variant = Color("30373d").lerp(Color("47525a"), repair_amount)
    var trim: Variant = Color("252b30").lerp(Color("d8e1e5"), paint_amount)
    var dirt_alpha: Variant = 1.0 - cleanliness
    var debris_alpha: Variant = 1.0 - cleanliness
    var damage_alpha: Variant = 1.0 - repair_amount
    var body: Variant = Rect2(origin.x - 125, origin.y - 105, 250, 150)

    draw_rect(Rect2(origin.x - 150, origin.y + 45, 300, 12), Color("1a2025"), true)
    draw_rect(body, wall, true)
    draw_colored_polygon(PackedVector2Array([Vector2(origin.x - 145, origin.y - 105), Vector2(origin.x, origin.y - 160), Vector2(origin.x + 145, origin.y - 105)]), roof)
    draw_rect(Rect2(origin.x - 135, origin.y - 96, 270, 8), trim, true)

    if type == "Workshop":
        draw_rect(Rect2(origin.x + 82, origin.y - 138, 20, 34), roof, true)
        draw_rect(Rect2(origin.x + 87, origin.y - 151, 10, 15), roof, true)
    elif type == "Commercial Building":
        draw_rect(Rect2(origin.x - 135, origin.y + 28, 270, 12), trim, true)
        draw_rect(Rect2(origin.x - 132, origin.y - 2, 264, 30), wall.darkened(0.12), true)

    var window_count: Variant = 4 if type == "Warehouse" else (3 if type == "Workshop" else 5)
    for i in range(window_count):
        var wx: Variant = origin.x - float(window_count - 1) * 25.0 + float(i) * 50.0
        var light_threshold: Variant = 0.08 + furnish_amount * 0.72
        if stage == "Operational": light_threshold = 1.0
        var lit: Variant = float(i) / maxf(float(window_count - 1), 1.0) <= light_threshold
        var glass: Variant = Color("dcecf2").lerp(Color("f2d27a"), furnish_amount * 0.55) if lit else Color("252c31")
        draw_rect(Rect2(wx - 13, origin.y - 70, 26, 30), glass, true)
        draw_line(Vector2(wx, origin.y - 70), Vector2(wx, origin.y - 40), Color("59656d"), 2.0)
        draw_line(Vector2(wx - 13, origin.y - 55), Vector2(wx + 13, origin.y - 55), Color("59656d"), 2.0)

    var door_color: Variant = Color("252b30").lerp(Color("33434b"), paint_amount)
    draw_rect(Rect2(origin.x - 28, origin.y - 2, 56, 52), door_color, true)
    if furnish_amount > 0.0:
        draw_rect(Rect2(origin.x - 18, origin.y + 12, 36, 4.0 + furnish_amount * 14.0), Color("8a9aa2"), true)
        draw_rect(Rect2(origin.x - 15, origin.y + 20, 30, 16), Color("6c7d85"), true)

    if debris_alpha > 0.02:
        var debris_count: Variant = int(lerpf(1.0, 8.0, debris_alpha))
        for i in range(debris_count):
            var dx: Variant = origin.x - 118.0 + float(i) * 31.0
            var dy: Variant = origin.y + 31.0 + float((i * 7) % 9)
            draw_circle(Vector2(dx, dy), 3.0 + debris_alpha * 3.0, Color(0.16, 0.18, 0.19, 0.72 * debris_alpha))
    if dirt_alpha > 0.02:
        var dirt_count: Variant = int(lerpf(1.0, 12.0, dirt_alpha))
        for i in range(dirt_count):
            var sx: Variant = origin.x - 112.0 + float((i * 37) % 220)
            var sy: Variant = origin.y - 82.0 + float((i * 23) % 115)
            draw_circle(Vector2(sx, sy), 2.0 + dirt_alpha * 2.5, Color(0.18, 0.20, 0.20, 0.30 * dirt_alpha))

    if damage_alpha > 0.02:
        var crack_count: Variant = int(lerpf(1.0, 7.0, damage_alpha))
        for i in range(crack_count):
            var cx: Variant = origin.x - 110.0 + float((i * 43) % 205)
            var cy: Variant = origin.y - 80.0 + float((i * 29) % 95)
            var crack: Variant = Color(0.12, 0.14, 0.15, 0.85 * damage_alpha)
            draw_line(Vector2(cx, cy), Vector2(cx + 12, cy + 8), crack, 2.5)
            draw_line(Vector2(cx + 7, cy + 5), Vector2(cx + 4, cy + 14), crack, 2.0)
        if repair_amount < 0.55:
            draw_line(Vector2(origin.x - 145, origin.y - 105), Vector2(origin.x - 105, origin.y - 125), Color(0.10, 0.12, 0.13, 0.8 * damage_alpha), 4.0)

    if paint_amount > 0.01 and paint_amount < 0.99:
        var painted_width: Variant = 250.0 * paint_amount
        draw_rect(Rect2(origin.x - 125, origin.y - 105, painted_width, 7), Color("d8e1e5"), true)
        draw_rect(Rect2(origin.x - 125, origin.y + 37, painted_width, 5), Color("d8e1e5"), true)
    elif paint_amount >= 0.99:
        draw_rect(Rect2(origin.x - 120, origin.y + 30, 240, 5), Color("d8e1e5"), true)

    if furnish_amount > 0.0:
        var fixture_count: Variant = int(lerpf(1.0, 6.0, furnish_amount))
        for i in range(fixture_count):
            var fx: Variant = origin.x - 92.0 + float(i % 3) * 92.0
            var fy: Variant = origin.y + 7.0 + float(i / 3) * 17.0
            draw_rect(Rect2(fx - 18, fy, 36, 5), Color("6c7d85"), true)
            draw_rect(Rect2(fx - 14, fy - 5, 28, 5), Color("8a9aa2"), true)

    if stage == "Operational":
        draw_circle(Vector2(origin.x + 112, origin.y - 130), 7, Color("f2d27a"))
        draw_rect(Rect2(origin.x + 106, origin.y - 123, 12, 20), Color("e8c968"), true)
        draw_rect(Rect2(origin.x - 72, origin.y - 151, 144, 22), Color("33434b"), true)
        var operational_font: Variant = ThemeDB.fallback_font
        draw_string(operational_font, Vector2(origin.x - 62, origin.y - 135), "OPEN", HORIZONTAL_ALIGNMENT_CENTER, 124, 12, Color("f2d27a"))

    _draw_status_panel(origin, property, stage)

func _draw_status_panel(origin: Vector2, property: Dictionary, stage: String) -> void:
    var font: Variant = ThemeDB.fallback_font
    var state = get_node_or_null("/root/RenewGameState")
    var business_open: Variant = bool(state.get_value("businesses", "business_open", false)) if state != null else false
    var panel_height: Variant = 104.0 if not (stage == "Operational" and not business_open) else 174.0
    var panel: Variant = Rect2(origin.x - 150, origin.y + 112, 300, panel_height)
    draw_rect(panel, Color(0.05, 0.07, 0.08, 0.94), true)
    draw_rect(Rect2(panel.position, Vector2(panel.size.x, 2)), Color("9fb3c8"), true)
    draw_string(font, Vector2(panel.position.x + 12, panel.position.y + 21), stage, HORIZONTAL_ALIGNMENT_LEFT, 276, 18, Color.WHITE)
    draw_string(font, Vector2(panel.position.x + 12, panel.position.y + 40), str(property.get("name", "Property")), HORIZONTAL_ALIGNMENT_LEFT, 276, 12, Color("9fb3c8"))

    var y: Variant = panel.position.y + 56.0
    for step in STEPS:
        var progress: Variant = clampf(float(property.get(step, 0)), 0.0, 100.0)
        draw_string(font, Vector2(panel.position.x + 12, y + 2), step.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, 70, 10, Color("d8e1e5"))
        draw_rect(Rect2(panel.position.x + 82, y - 6, 150, 9), Color("252c31"), true)
        draw_rect(Rect2(panel.position.x + 82, y - 6, 150.0 * progress / 100.0, 9), Color("8ea7b5"), true)
        draw_string(font, Vector2(panel.position.x + 238, y + 2), "%d%%" % int(progress), HORIZONTAL_ALIGNMENT_LEFT, 45, 10, Color("d8e1e5"))
        y += 12.0

    if stage == "Operational" and not business_open:
        var purposes: Variant = _business_purposes()
        draw_string(font, Vector2(panel.position.x + 12, panel.position.y + 120), "Choose what this building becomes", HORIZONTAL_ALIGNMENT_LEFT, 276, 11, Color.WHITE)
        for i in range(purposes.size()):
            var purpose: Dictionary = purposes[i]
            draw_string(font, Vector2(panel.position.x + 12, panel.position.y + 138 + i * 14), "%d  %s" % [i + 4, purpose.get("name", "Business")], HORIZONTAL_ALIGNMENT_LEFT, 276, 10, Color("d8e1e5"))
        return
    draw_string(font, Vector2(panel.position.x + 12, panel.position.y + 100), "Physical state follows restoration progress", HORIZONTAL_ALIGNMENT_LEFT, 276, 10, Color("9fb3c8"))

func _business_purposes() -> Array:
    var state = get_node_or_null("/root/RenewGameState")
    if state == null: return []
    var type: Variant = ""
    var catalog = state.get_value("properties", "catalog", [])
    if catalog is Array and not catalog.is_empty():
        var index: Variant = clampi(int(state.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
        type = str(catalog[index].get("type", ""))
    var options: Variant = {
        "Warehouse": ["Furniture Factory", "Distribution Center", "Wholesale Hub"],
        "Workshop": ["Furniture Factory", "Metalworks", "Construction Workshop"],
        "Commercial Building": ["Retail Store", "Service Office", "Showroom"]
    }
    var result: Array = []
    for name in options.get(type, []): result.append({"name":name})
    return result