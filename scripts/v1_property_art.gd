extends Node2D

## V1 production art pass.
## Deterministic, engine-native visual language for the three property families.
## Gameplay state remains authoritative in RenewGameState; this node only renders it.

const STAGE_NAMES := ["Abandoned", "Cleaned", "Repaired", "Painted", "Furnished", "Operational"]
const STAGE_COLORS := [Color("46515a"), Color("596872"), Color("71818a"), Color("8f9da1"), Color("aab7b7"), Color("c4cdca")]
const BG := Color("0b141b")
const GROUND := Color("14222b")
const GRID := Color(0.32, 0.40, 0.44, 0.16)
const INK := Color("182229")
const WHITE := Color("edf3f4")
const MUTED := Color("9fb3c0")
const ACCENT := Color("e5c66f")
const POSITIVE := Color("8ee6a8")

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var state = get_node_or_null("/root/RenewGameState")
    if state == null: return
    var catalog = state.get_value("properties", "catalog", [])
    if not catalog is Array or catalog.is_empty(): return
    var index := clampi(int(state.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    var property: Dictionary = catalog[index]
    var owned: bool = bool(state.get_value("properties", "owned", false))
    var stage_index: int = _stage_index(property, owned)
    var viewport_center := Vector2(650, 430)
    _draw_environment(viewport_center, stage_index)
    _draw_property(viewport_center, property, stage_index)
    _draw_label(viewport_center, property, stage_index)

func _stage_index(property: Dictionary, owned: bool) -> int:
    if not owned: return 0
    var cleaning := float(property.get("cleaning", 0))
    var repair := float(property.get("repair", 0))
    var painting := float(property.get("painting", 0))
    var furnishing := float(property.get("furnishing", 0))
    if cleaning < 100.0: return 0
    if repair < 100.0: return 1
    if painting < 100.0: return 2
    if furnishing < 50.0: return 3
    if furnishing < 100.0: return 4
    return 5

func _progress(property: Dictionary, key: String) -> float:
    return clampf(float(property.get(key, 0)), 0.0, 100.0) / 100.0

func _draw_environment(o: Vector2, stage: int) -> void:
    draw_rect(Rect2(420, 100, 460, 500), BG, true)
    draw_rect(Rect2(420, 390, 460, 210), GROUND, true)
    for x in range(440, 881, 40): draw_line(Vector2(x, 390), Vector2(x, 600), GRID, 1.0)
    for y in range(410, 601, 40): draw_line(Vector2(420, y), Vector2(880, y), GRID, 1.0)
    draw_rect(Rect2(o.x - 205, o.y + 151, 410, 12), Color("0a1015"), true)
    draw_rect(Rect2(o.x - 184, o.y + 138, 368, 3), Color(0.55, 0.66, 0.70, 0.18), true)
    if stage >= 4:
        _draw_tree(Vector2(o.x - 188, o.y + 125), 0.9)
        _draw_tree(Vector2(o.x + 188, o.y + 125), 0.75)
    if stage == 5: draw_circle(Vector2(o.x + 175, o.y - 15), 24, Color(0.90, 0.78, 0.42, 0.08))

func _draw_property(o: Vector2, property: Dictionary, stage: int) -> void:
    var type := str(property.get("type", "Warehouse"))
    var clean := _progress(property, "cleaning")
    var repair := _progress(property, "repair")
    var paint := _progress(property, "painting")
    var furnish := _progress(property, "furnishing")
    var wall: Color = STAGE_COLORS[stage]
    var trim: Color = Color("2b3941").lerp(Color("e4e8e5"), paint)
    var roof: Color = Color("27333a").lerp(Color("52636c"), repair)
    var body := Rect2(o.x - 150, o.y - 105, 300, 210)
    _draw_ellipse_custom(Vector2(o.x, o.y + 112), Vector2(176, 18), Color(0, 0, 0, 0.34))
    if type == "Workshop": _draw_workshop(o, body, wall, roof, trim, stage, repair, paint, furnish)
    elif type == "Commercial Building": _draw_commercial(o, body, wall, roof, trim, stage, repair, paint, furnish)
    else: _draw_warehouse(o, body, wall, roof, trim, stage, repair, paint, furnish)
    _draw_damage(o, body, 1.0 - clean, 1.0 - repair)
    _draw_stage_accents(o, body, stage, furnish)

func _draw_warehouse(o: Vector2, body: Rect2, wall: Color, roof: Color, trim: Color, stage: int, repair: float, paint: float, furnish: float) -> void:
    draw_rect(body, wall, true)
    draw_colored_polygon(PackedVector2Array([Vector2(o.x - 170, o.y - 105), Vector2(o.x, o.y - 158), Vector2(o.x + 170, o.y - 105)]), roof)
    draw_rect(Rect2(o.x - 160, o.y - 105, 320, 10), trim, true); draw_rect(Rect2(o.x - 160, o.y + 76, 320, 14), trim, true)
    for i in range(5): _draw_window(Vector2(o.x - 120.0 + i * 60.0, o.y - 56), 28, 38, stage >= 4, furnish)
    draw_rect(Rect2(o.x - 44, o.y + 8, 88, 97), Color("243038"), true)
    draw_rect(Rect2(o.x - 38, o.y + 15, 76, 78), Color("32424a").lerp(Color("4b5f68"), furnish), true)
    if stage >= 4: draw_rect(Rect2(o.x - 28, o.y + 25, 56, 8), ACCENT, true)
    if stage == 5:
        draw_rect(Rect2(o.x - 62, o.y - 131, 124, 25), Color("263841"), true)
        draw_string(ThemeDB.fallback_font, Vector2(o.x - 53, o.y - 113), "RENEW GOODS", HORIZONTAL_ALIGNMENT_CENTER, 106, 11, WHITE)

func _draw_workshop(o: Vector2, body: Rect2, wall: Color, roof: Color, trim: Color, stage: int, repair: float, paint: float, furnish: float) -> void:
    draw_rect(body, wall, true)
    draw_colored_polygon(PackedVector2Array([Vector2(o.x - 165, o.y - 105), Vector2(o.x - 120, o.y - 154), Vector2(o.x + 165, o.y - 112), Vector2(o.x + 165, o.y - 105)]), roof)
    draw_rect(Rect2(o.x + 92, o.y - 138, 25, 33), roof.darkened(0.15), true); draw_rect(Rect2(o.x + 97, o.y - 153, 15, 18), roof.darkened(0.25), true)
    draw_rect(Rect2(o.x - 154, o.y - 100, 308, 9), trim, true)
    for i in range(3): _draw_window(Vector2(o.x - 105 + i * 105, o.y - 55), 38, 45, stage >= 4, furnish)
    draw_rect(Rect2(o.x - 62, o.y - 8, 124, 113), Color("26343b"), true); draw_rect(Rect2(o.x - 52, o.y + 3, 104, 92), Color("354850").lerp(Color("536a72"), furnish), true)
    if stage >= 3: draw_line(Vector2(o.x - 48, o.y + 22), Vector2(o.x + 48, o.y + 22), trim, 5)
    if stage == 5: draw_circle(Vector2(o.x + 130, o.y + 65), 8, ACCENT)

func _draw_commercial(o: Vector2, body: Rect2, wall: Color, roof: Color, trim: Color, stage: int, repair: float, paint: float, furnish: float) -> void:
    draw_rect(body, wall, true); draw_rect(Rect2(o.x - 162, o.y - 108, 324, 16), roof, true); draw_rect(Rect2(o.x - 162, o.y + 38, 324, 13), trim, true); draw_rect(Rect2(o.x - 162, o.y + 72, 324, 33), Color("25343b"), true)
    for i in range(4): _draw_window(Vector2(o.x - 118.0 + i * 78.0, o.y - 48), 54, 52, stage >= 4, furnish)
    draw_rect(Rect2(o.x - 36, o.y + 52, 72, 53), Color("1e2a30"), true)
    if stage >= 3: draw_rect(Rect2(o.x - 122, o.y + 10, 244, 18), Color("324750").lerp(Color("556e76"), furnish), true)
    if stage == 5:
        draw_rect(Rect2(o.x - 70, o.y - 132, 140, 24), Color("263841"), true)
        draw_string(ThemeDB.fallback_font, Vector2(o.x - 58, o.y - 115), "RENEW MARKET", HORIZONTAL_ALIGNMENT_CENTER, 116, 11, WHITE)

func _draw_window(p: Vector2, w: float, h: float, lit: bool, furnish: float) -> void:
    var glass: Color = Color("1b2a31")
    if lit: glass = Color("b7cbd0").lerp(Color("f0d37c"), furnish * 0.75)
    draw_rect(Rect2(p.x - w / 2, p.y - h / 2, w, h), INK, true); draw_rect(Rect2(p.x - w / 2 + 4, p.y - h / 2 + 4, w - 8, h - 8), glass, true)
    draw_line(Vector2(p.x, p.y - h / 2 + 4), Vector2(p.x, p.y + h / 2 - 4), Color(0.3, 0.4, 0.43, 0.8), 2); draw_line(Vector2(p.x - w / 2 + 4, p.y), Vector2(p.x + w / 2 - 4, p.y), Color(0.3, 0.4, 0.43, 0.8), 2)

func _draw_damage(o: Vector2, body: Rect2, dirt: float, damage: float) -> void:
    if dirt > 0.02:
        for i in range(int(lerpf(1, 12, dirt))):
            var x: float = body.position.x + 16 + fmod(i * 47.0, body.size.x - 32); var y: float = body.position.y + 18 + fmod(i * 29.0, body.size.y - 36)
            draw_circle(Vector2(x, y), 2.0 + dirt * 2.0, Color(0.08, 0.11, 0.12, 0.22 * dirt))
    if damage > 0.02:
        for i in range(int(lerpf(1, 7, damage))):
            var x: float = body.position.x + 20 + fmod(i * 61.0, body.size.x - 40); var y: float = body.position.y + 20 + fmod(i * 37.0, body.size.y - 40); var c := Color(0.08, 0.10, 0.11, 0.8 * damage)
            draw_line(Vector2(x, y), Vector2(x + 15, y + 10), c, 2.2); draw_line(Vector2(x + 10, y + 7), Vector2(x + 5, y + 17), c, 1.6)
        if damage > 0.5:
            for i in range(3): draw_rect(Rect2(body.position.x + 20 + i * 105, body.position.y + 145, 44, 5), Color(0.1, 0.12, 0.12, 0.5), true)

func _draw_stage_accents(o: Vector2, body: Rect2, stage: int, furnish: float) -> void:
    if stage >= 1:
        for p in [Vector2(o.x - 178, o.y + 116), Vector2(o.x + 170, o.y + 118)]: draw_circle(p, 8, Color("344b3d"))
    if stage >= 3: draw_rect(Rect2(o.x - 145, o.y + 108, 290, 6), Color("65767b"), true)
    if stage >= 4: draw_rect(Rect2(o.x - 130, o.y + 117, 70, 7), POSITIVE.darkened(0.2), true); draw_rect(Rect2(o.x + 60, o.y + 117, 70, 7), POSITIVE.darkened(0.2), true)
    if stage == 5:
        draw_circle(Vector2(o.x - 158, o.y + 112), 5, POSITIVE); draw_circle(Vector2(o.x + 158, o.y + 112), 5, POSITIVE); draw_rect(Rect2(o.x - 98, o.y + 132, 196, 4), POSITIVE, true)

func _draw_label(o: Vector2, property: Dictionary, stage: int) -> void:
    var panel := Rect2(o.x - 205, o.y + 170, 410, 82)
    draw_rect(panel, Color(0.045, 0.07, 0.09, 0.96), true); draw_rect(Rect2(panel.position, Vector2(panel.size.x, 3)), ACCENT if stage == 5 else Color("718793"), true)
    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(panel.position.x + 16, panel.position.y + 24), STAGE_NAMES[stage].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 180, 15, WHITE)
    draw_string(font, Vector2(panel.position.x + 16, panel.position.y + 45), str(property.get("name", "Property")), HORIZONTAL_ALIGNMENT_LEFT, 260, 12, MUTED)
    draw_string(font, Vector2(panel.position.x + 16, panel.position.y + 66), "RESTORATION %d / 6" % (stage + 1), HORIZONTAL_ALIGNMENT_LEFT, 180, 10, Color("8197a3"))
    for i in range(6): draw_circle(Vector2(panel.position.x + 290 + i * 16, panel.position.y + 60), 4.5, POSITIVE if i <= stage else Color("26343b"))

func _draw_tree(p: Vector2, scale: float) -> void:
    draw_rect(Rect2(p.x - 3 * scale, p.y, 6 * scale, 22 * scale), Color("4c4435"), true)
    draw_circle(p + Vector2(-9, -4) * scale, 13 * scale, Color("365443")); draw_circle(p + Vector2(7, -8) * scale, 15 * scale, Color("3f654c")); draw_circle(p + Vector2(0, -18) * scale, 12 * scale, Color("4c7455"))

func _draw_ellipse_custom(center: Vector2, radius: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    for i in range(25):
        var a: float = TAU * float(i) / 24.0
        points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
    draw_colored_polygon(points, color)
