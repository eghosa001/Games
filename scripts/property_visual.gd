extends Node2D

## Phase 18 presentation layer.
## Reads canonical GameState.properties and renders the same building changing
## continuously as restoration work is performed. It owns no gameplay state.

const STEPS := ["cleaning", "repair", "painting", "furnishing"]

func _process(_delta: float) -> void:
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
    _draw_property(Vector2(650, 585), property, stage)

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

func _draw_property(origin: Vector2, property: Dictionary, stage: String) -> void:
    var type := str(property.get("type", "Warehouse"))
    var cleaning := clampf(float(property.get("cleaning", 0)), 0.0, 100.0)
    var repair := clampf(float(property.get("repair", 0)), 0.0, 100.0)
    var painting := clampf(float(property.get("painting", 0)), 0.0, 100.0)
    var furnishing := clampf(float(property.get("furnishing", 0)), 0.0, 100.0)

    # Every restoration percentage directly affects the presentation.
    # This creates a continuous visual transformation rather than a single
    # sprite/state swap at the end of each task.
    var cleanliness := cleaning / 100.0
    var repair_amount := repair / 100.0
    var paint_amount := painting / 100.0
    var furnish_amount := furnishing / 100.0

    var worn_wall := Color("555d63")
    var finished_wall := Color("b8c4ca")
    var wall := worn_wall.lerp(finished_wall, paint_amount)
    wall = wall.lerp(Color("cbd7dc"), furnish_amount * 0.18)
    var roof := Color("30373d").lerp(Color("47525a"), repair_amount)
    var trim := Color("252b30").lerp(Color("d8e1e5"), paint_amount)

    # Dirt fades continuously during cleaning.
    var dirt_alpha := 1.0 - cleanliness
    var debris_alpha := 1.0 - cleanliness
    var damage_alpha := 1.0 - repair_amount

    var body := Rect2(origin.x - 125, origin.y - 105, 250, 150)
    draw_rect(Rect2(origin.x - 150, origin.y + 45, 300, 12), Color("1a2025"), true)
    draw_rect(body, wall, true)
    draw_colored_polygon(PackedVector2Array([
        Vector2(origin.x - 145, origin.y - 105),
        Vector2(origin.x, origin.y - 160),
        Vector2(origin.x + 145, origin.y - 105)
    ]), roof)
    draw_rect(Rect2(origin.x - 135, origin.y - 96, 270, 8), trim, true)

    # Property type changes the silhouette without creating separate state.
    if type == "Workshop":
        draw_rect(Rect2(origin.x + 82, origin.y - 138, 20, 34), roof, true)
        draw_rect(Rect2(origin.x + 87, origin.y - 151, 10, 15), roof, true)
    elif type == "Commercial Building":
        draw_rect(Rect2(origin.x - 135, origin.y + 28, 270, 12), trim, true)
        draw_rect(Rect2(origin.x - 132, origin.y - 2, 264, 30), wall.darkened(0.12), true)

    var window_count := 4 if type == "Warehouse" else (3 if type == "Workshop" else 5)
    for i in range(window_count):
        var wx := origin.x - float(window_count - 1) * 25.0 + float(i) * 50.0
        var base_light := 0.08 + furnish_amount * 0.72
        if stage == "Operational":
            base_light = 1.0
        var lit := float(i) / maxf(float(window_count - 1), 1.0) <= base_light
        var glass_dark := Color("252c31")
        var glass_light := Color("dcecf2").lerp(Color("f2d27a"), furnish_amount * 0.55)
        draw_rect(Rect2(wx - 13, origin.y - 70, 26, 30), glass_light if lit else glass_dark, true)
        draw_line(Vector2(wx, origin.y - 70), Vector2(wx, origin.y - 40), Color("59656d"), 2.0)
        draw_line(Vector2(wx - 13, origin.y - 55), Vector2(wx + 13, origin.y - 55), Color("59656d"), 2.0)

    # Main entrance becomes cleaner, brighter and more finished over time.
    var door_color := Color("252b30").lerp(Color("33434b"), paint_amount)
    draw_rect(Rect2(origin.x - 28, origin.y - 2, 56, 52), door_color, true)
    if furnish_amount > 0.0:
        var fixture_height := 4.0 + furnish_amount * 14.0
        draw_rect(Rect2(origin.x - 18, origin.y + 12, 36, fixture_height), Color("8a9aa2"), true)
        draw_rect(Rect2(origin.x - 15, origin.y + 20, 30, 16), Color("6c7d85"), true)

    # Cleaning: dirt, weeds and debris disappear progressively.
    if debris_alpha > 0.02:
        var debris_count := int(lerpf(1.0, 8.0, debris_alpha))
        for i in range(debris_count):
            var dx := origin.x - 118.0 + float(i) * 31.0
            var dy := origin.y + 31.0 + float((i * 7) % 9)
            draw_circle(Vector2(dx, dy), 3.0 + debris_alpha * 3.0, Color(0.16, 0.18, 0.19, 0.72 * debris_alpha))
    if dirt_alpha > 0.02:
        var dirt_count := int(lerpf(1.0, 12.0, dirt_alpha))
        for i in range(dirt_count):
            var sx := origin.x - 112.0 + float((i * 37) % 220)
            var sy := origin.y - 82.0 + float((i * 23) % 115)
            draw_circle(Vector2(sx, sy), 2.0 + dirt_alpha * 2.5, Color(0.18, 0.20, 0.20, 0.30 * dirt_alpha))

    # Repairs: cracks and structural damage disappear progressively.
    if damage_alpha > 0.02:
        var crack_count := int(lerpf(1.0, 7.0, damage_alpha))
        for i in range(crack_count):
            var cx := origin.x - 110.0 + float((i * 43) % 205)
            var cy := origin.y - 80.0 + float((i * 29) % 95)
            var crack := Color(0.12, 0.14, 0.15, 0.85 * damage_alpha)
            draw_line(Vector2(cx, cy), Vector2(cx + 12, cy + 8), crack, 2.5)
            draw_line(Vector2(cx + 7, cy + 5), Vector2(cx + 4, cy + 14), crack, 2.0)
        if repair_amount < 0.55:
            draw_line(Vector2(origin.x - 145, origin.y - 105), Vector2(origin.x - 105, origin.y - 125), Color(0.10, 0.12, 0.13, 0.8 * damage_alpha), 4.0)

    # Painting: partially painted facade bands make progress visible before 100%.
    if paint_amount > 0.01 and paint_amount < 0.99:
        var painted_width := 250.0 * paint_amount
        draw_rect(Rect2(origin.x - 125, origin.y - 105, painted_width, 7), Color("d8e1e5"), true)
        draw_rect(Rect2(origin.x - 125, origin.y + 37, painted_width, 5), Color("d8e1e5"), true)
    elif paint_amount >= 0.99:
        draw_rect(Rect2(origin.x - 120, origin.y + 30, 240, 5), Color("d8e1e5"), true)

    # Furnishing: interior fixtures visibly accumulate as the property is fitted out.
    if furnish_amount > 0.0:
        var fixture_count := int(lerpf(1.0, 6.0, furnish_amount))
        for i in range(fixture_count):
            var fx := origin.x - 92.0 + float(i % 3) * 92.0
            var fy := origin.y + 7.0 + float(i / 3) * 17.0
            draw_rect(Rect2(fx - 18, fy, 36, 5), Color("6c7d85"), true)
            draw_rect(Rect2(fx - 14, fy - 5, 28, 5), Color("8a9aa2"), true)

    if stage == "Operational":
        # Final operational cues: active lighting, sign and a clean frontage.
        draw_circle(Vector2(origin.x + 112, origin.y - 130), 7, Color("f2d27a"))
        draw_rect(Rect2(origin.x + 106, origin.y - 123, 12, 20), Color("e8c968"), true)
        draw_rect(Rect2(origin.x - 72, origin.y - 151, 144, 22), Color("33434b"), true)
        var font := ThemeDB.fallback_font
        draw_string(font, Vector2(origin.x - 62, origin.y - 135), "OPEN", HORIZONTAL_ALIGNMENT_CENTER, 124, 12, Color("f2d27a"))

    _draw_status_panel(origin, property, stage)

func _draw_status_panel(origin: Vector2, property: Dictionary, stage: String) -> void:
    var font := ThemeDB.fallback_font
    var panel := Rect2(origin.x - 150, origin.y + 112, 300, 104)
    draw_rect(panel, Color(0.05, 0.07, 0.08, 0.94), true)
    draw_rect(Rect2(panel.position, Vector2(panel.size.x, 2)), Color("9fb3c8"), true)
    draw_string(font, Vector2(panel.position.x + 12, panel.position.y + 21), stage, HORIZONTAL_ALIGNMENT_LEFT, 276, 18, Color.WHITE)
    draw_string(font, Vector2(panel.position.x + 12, panel.position.y + 40), str(property.get("name", "Property")), HORIZONTAL_ALIGNMENT_LEFT, 276, 12, Color("9fb3c8"))

    var y := panel.position.y + 56.0
    for step in STEPS:
        var progress := clampf(float(property.get(step, 0)), 0.0, 100.0)
        var label := step.capitalize()
        draw_string(font, Vector2(panel.position.x + 12, y + 2), label, HORIZONTAL_ALIGNMENT_LEFT, 70, 10, Color("d8e1e5"))
        draw_rect(Rect2(panel.position.x + 82, y - 6, 150, 9), Color("252c31"), true)
        draw_rect(Rect2(panel.position.x + 82, y - 6, 150.0 * progress / 100.0, 9), Color("8ea7b5"), true)
        draw_string(font, Vector2(panel.position.x + 238, y + 2), "%d%%" % int(progress), HORIZONTAL_ALIGNMENT_LEFT, 45, 10, Color("d8e1e5"))
        y += 12.0

    draw_string(font, Vector2(panel.position.x + 12, panel.position.y + 100), "Physical state follows restoration progress", HORIZONTAL_ALIGNMENT_LEFT, 276, 10, Color("9fb3c8"))
