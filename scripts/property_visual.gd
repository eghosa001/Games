extends Node2D

## Phase 18 presentation layer.
## Reads canonical GameState.properties and renders the same building changing
## through the restoration sequence. It owns no gameplay state.

const STEPS := ["cleaning", "repair", "painting", "furnishing"]

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var state = get_node_or_null("/root/RenewGameState")
    if state == null: return
    var catalog = state.get_value("properties", "catalog", [])
    if not catalog is Array or catalog.is_empty(): return
    var index := clampi(int(state.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    var property: Dictionary = catalog[index]
    var owned := bool(state.get_value("properties", "owned", false))
    var stage := _visual_stage(property, owned)
    _draw_property(Vector2(650, 585), property, stage)

func _visual_stage(property: Dictionary, owned: bool) -> String:
    if not owned: return "Abandoned"
    if int(property.get("cleaning", 0)) < 100: return "Abandoned"
    if int(property.get("repair", 0)) < 100: return "Cleaned"
    if int(property.get("painting", 0)) < 100: return "Repaired"
    if int(property.get("furnishing", 0)) < 50: return "Painted"
    if int(property.get("furnishing", 0)) < 100: return "Furnished"
    return "Operational"

func _draw_property(origin: Vector2, property: Dictionary, stage: String) -> void:
    var type := str(property.get("type", "Warehouse"))
    var body := Rect2(origin.x - 125, origin.y - 105, 250, 150)
    var wall := Color("555d63")
    var roof := Color("30373d")
    var trim := Color("252b30")
    if stage in ["Cleaned", "Repaired"]: wall = Color("707b82")
    if stage in ["Painted", "Furnished", "Operational"]:
        wall = Color("b8c4ca")
        roof = Color("47525a")
        trim = Color("d8e1e5")

    draw_rect(Rect2(origin.x - 150, origin.y + 45, 300, 12), Color("1a2025"), true)
    draw_rect(body, wall, true)
    draw_colored_polygon(PackedVector2Array([Vector2(origin.x - 145, origin.y - 105), Vector2(origin.x, origin.y - 160), Vector2(origin.x + 145, origin.y - 105)]), roof)
    draw_rect(Rect2(origin.x - 135, origin.y - 96, 270, 8), trim, true)

    var window_count := 4 if type == "Warehouse" else (3 if type == "Workshop" else 5)
    for i in range(window_count):
        var wx := origin.x - float(window_count - 1) * 25.0 + float(i) * 50.0
        var lit := stage == "Operational" or (stage in ["Furnished"] and i % 2 == 0)
        draw_rect(Rect2(wx - 13, origin.y - 70, 26, 30), Color("dcecf2") if lit else Color("252c31"), true)
        draw_line(Vector2(wx, origin.y - 70), Vector2(wx, origin.y - 40), Color("59656d"), 2.0)
        draw_line(Vector2(wx - 13, origin.y - 55), Vector2(wx + 13, origin.y - 55), Color("59656d"), 2.0)

    draw_rect(Rect2(origin.x - 28, origin.y - 2, 56, 52), trim if stage != "Operational" else Color("33434b"), true)
    if stage == "Furnished" or stage == "Operational":
        draw_rect(Rect2(origin.x - 18, origin.y + 12, 36, 4), Color("8a9aa2"), true)
        draw_rect(Rect2(origin.x - 15, origin.y + 20, 30, 16), Color("6c7d85"), true)

    if stage == "Abandoned":
        for x in [-95, -40, 20, 75]:
            draw_line(Vector2(origin.x + x, origin.y - 80), Vector2(origin.x + x + 14, origin.y - 55), Color("20262a"), 3.0)
        draw_circle(Vector2(origin.x - 92, origin.y + 15), 7, Color("687075"))
        draw_circle(Vector2(origin.x + 105, origin.y + 18), 5, Color("687075"))
    elif stage == "Cleaned":
        draw_rect(Rect2(origin.x - 115, origin.y + 28, 230, 5), Color("8c989d"), true)
    elif stage == "Repaired":
        draw_line(Vector2(origin.x - 125, origin.y - 35), Vector2(origin.x - 85, origin.y - 8), Color("9aa6ab"), 4.0)
        draw_line(Vector2(origin.x + 85, origin.y - 8), Vector2(origin.x + 125, origin.y - 35), Color("9aa6ab"), 4.0)
    elif stage in ["Painted", "Furnished", "Operational"]:
        draw_rect(Rect2(origin.x - 120, origin.y + 30, 240, 5), Color("d8e1e5"), true)

    if stage == "Operational":
        draw_circle(Vector2(origin.x + 112, origin.y - 130), 7, Color("f2d27a"))
        draw_rect(Rect2(origin.x + 106, origin.y - 123, 12, 20), Color("e8c968"), true)

    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(origin.x - 145, origin.y + 78), stage, HORIZONTAL_ALIGNMENT_LEFT, 290, 16, Color.WHITE)
    draw_string(font, Vector2(origin.x - 145, origin.y + 98), type, HORIZONTAL_ALIGNMENT_LEFT, 290, 12, Color("9fb3c8"))
