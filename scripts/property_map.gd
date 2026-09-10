extends Node2D

## District property map: every catalog property drawn from authoritative
## GameState. Owns no gameplay state; selection routes through property_system.
const STEPS := ["cleaning", "repair", "painting", "furnishing"]
const BODY := {"Warehouse": Color("2a3f46"), "Workshop": Color("3a3230"), "Commercial Building": Color("323a4a")}
const ROOF := {"Warehouse": Color("4a6a72"), "Workshop": Color("6a5a4a"), "Commercial Building": Color("5a6a8a")}
const TRIM := Color("d5b56e")
const LIT := Color("ffd97a")
const DARK_WIN := Color("1a2a30")
const BOARD := Color("6a5a3a")
const OWNED_RING := Color("7ed0c3")
const SELECT_RING := Color("e4bd68")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")

var _last_signature := ""

func _ready() -> void:
	queue_redraw()

func _process(_delta: float) -> void:
	var signature := _signature()
	if signature != _last_signature:
		_last_signature = signature
		queue_redraw()

func _state():
	return get_node_or_null("/root/RenewGameState")

func _signature() -> String:
	var state = _state()
	if state == null:
		return "none"
	var catalog = state.get_value("properties", "catalog", [])
	var parts: Array = [str(state.get_value("player", "day", 1)), str(state.get_value("properties", "selected_property", 0)), str(state.get_value("properties", "owned", false))]
	if catalog is Array:
		for entry in catalog:
			if entry is Dictionary:
				parts.append("%s:%d:%d:%d:%d:%s:%d" % [str(entry.get("id", "")), int(entry.get("cleaning", 0)), int(entry.get("repair", 0)), int(entry.get("painting", 0)), int(entry.get("furnishing", 0)), str(entry.get("condition", 0)), int(entry.get("lease_until", 0))])
	return "|".join(parts)

func stage_of(property: Dictionary, owned: bool) -> int:
	if not owned:
		return 0
	if int(property.get("cleaning", 0)) < 100:
		return 0
	if int(property.get("repair", 0)) < 100:
		return 1
	if int(property.get("painting", 0)) < 100:
		return 2
	if int(property.get("furnishing", 0)) < 50:
		return 3
	if int(property.get("furnishing", 0)) < 100:
		return 4
	return 5

func _map_area() -> Rect2:
	var viewport: Vector2 = get_viewport_rect().size
	var top := 64.0
	var bottom: float = viewport.y - 200.0
	var left: float = 16.0
	var width: float = maxf(100.0, viewport.x - 32.0)
	if viewport.x < 700.0:
		top = 112.0
	var hud := get_tree().root.get_node_or_null("Renew/UI/MainHUD") if get_tree() != null and get_tree().root != null else null
	if hud != null:
		var dock: Variant = hud.get("action_dock")
		if dock is Control and (dock as Control).visible:
			bottom = minf(bottom, (dock as Control).get_global_rect().position.y - 8.0)
		var selected: Variant = hud.get("selected_card")
		if selected is Control and selected.visible:
			top = maxf(top, (selected as Control).get_global_rect().end.y + 4.0)
		else:
			var objective: Variant = hud.get("objective_card")
			if objective is Control and objective.visible:
				top = maxf(top, (objective as Control).get_global_rect().end.y + 4.0)
			else:
				top = maxf(top, 212.0)
		var left_rail: Variant = hud.get("left_rail")
		var rail_right: float = 16.0
		if left_rail is Control and left_rail.visible:
			rail_right = maxf(rail_right, (left_rail as Control).get_global_rect().end.x + 4.0)
		elif dock is Control and dock.visible:
			rail_right = maxf(rail_right, (dock as Control).get_global_rect().position.x + 4.0)
		left = rail_right
		width = maxf(100.0, viewport.x - left - 16.0)
	if bottom - top < 90.0:
		bottom = minf(viewport.y - 8.0, top + 90.0)
	return Rect2(left, top, maxf(width, 100.0), maxf(40.0, bottom - top))

func map_rects() -> Array:
	var out: Array = []
	var state = _state()
	if state == null:
		return out
	var catalog = state.get_value("properties", "catalog", [])
	if not catalog is Array or catalog.is_empty():
		return out
	var area := _map_area()
	var count := 0
	for entry in catalog:
		if entry is Dictionary:
			count += 1
	if count <= 0:
		return out
	var cols := 9
	if area.size.x < 900.0:
		cols = 5
	if area.size.x < 500.0:
		cols = 3
	cols = mini(cols, count)
	var rows := int(ceil(float(count) / float(maxi(1, cols))))
	var cell := Vector2(area.size.x / float(cols), area.size.y / float(maxi(1, rows)))
	var index := 0
	for entry in catalog:
		if not entry is Dictionary:
			continue
		var col: int = index % cols
		var row: int = index / cols
		var origin := area.position + Vector2(col * cell.x + 6.0, row * cell.y + 4.0)
		var size := Vector2(maxf(40.0, cell.x - 12.0), maxf(24.0, cell.y - 32.0))
		out.append({"id": str(entry.get("id", "")), "rect": Rect2(origin, size)})
		index += 1
	return out

func _draw() -> void:
	var state = _state()
	if state == null:
		return
	var catalog = state.get_value("properties", "catalog", [])
	if not catalog is Array or catalog.is_empty():
		return
	var owned := bool(state.get_value("properties", "owned", false))
	var selected := int(state.get_value("properties", "selected_property", 0))
	var business_open := bool(state.get_value("businesses", "business_open", false))
	var day := int(state.get_value("player", "day", 1))
	var font: Font = ThemeDB.fallback_font
	var index := 0
	for slot in map_rects():
		var entry: Dictionary = catalog[index] if index < catalog.size() and catalog[index] is Dictionary else {}
		if entry.is_empty():
			continue
		var rect: Rect2 = slot["rect"]
		var stage := stage_of(entry, owned and index == selected)
		_draw_building(rect, str(entry.get("type", "Warehouse")), stage, int(entry.get("condition", 0)))
		if owned and index == selected:
			draw_rect(rect.grow(4.0), OWNED_RING, false, 2.0)
		if index == selected:
			draw_rect(rect.grow(8.0), SELECT_RING, false, 1.5)
		if int(entry.get("lease_until", 0)) > day:
			draw_string(font, rect.position + Vector2(4, -6), "LEASED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TRIM)
		draw_string(font, rect.position + Vector2(0, rect.size.y + 14), str(entry.get("name", "?")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 10, TEXT)
		var caption := _stage_caption(stage, business_open and owned and index == selected)
		draw_string(font, rect.position + Vector2(0, rect.size.y + 27), caption, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 9, MUTED)
		index += 1

func _stage_caption(stage: int, operating: bool) -> String:
	if operating and stage >= 5:
		return "OPERATING"
	match stage:
		0:
			return "ABANDONED"
		1:
			return "CLEANED"
		2:
			return "REPAIRED"
		3:
			return "PAINTED"
		4:
			return "FURNISHED"
	return "RESTORED"

func _draw_building(rect: Rect2, building_type: String, stage: int, condition: int) -> void:
	var body: Color = BODY.get(building_type, BODY["Warehouse"])
	var roof: Color = ROOF.get(building_type, ROOF["Warehouse"])
	if stage == 0:
		var gloom := 0.35 + 0.45 * clampf(float(condition) / 100.0, 0.0, 1.0)
		body = body.lerp(Color("0a0f12"), 1.0 - gloom)
		roof = roof.lerp(Color("0a0f12"), 1.0 - gloom)
	var w := rect.size
	var base := Rect2(rect.position + Vector2(0, w.y * 0.30), Vector2(w.x, w.y * 0.70))
	draw_rect(base, body, true)
	draw_rect(base, roof, false, 2.0)
	match building_type:
		"Warehouse":
			draw_colored_polygon(PackedVector2Array([rect.position + Vector2(-4, w.y * 0.30), rect.position + Vector2(w.x + 4, w.y * 0.30), rect.position + Vector2(w.x * 0.78, 0), rect.position + Vector2(w.x * 0.22, 0)]), roof)
		"Workshop":
			draw_rect(Rect2(rect.position + Vector2(w.x * 0.68, 0), Vector2(w.x * 0.16, w.y * 0.34)), roof, true)
		_:
			draw_rect(Rect2(rect.position + Vector2(0, w.y * 0.22), Vector2(w.x, w.y * 0.10)), roof, true)
	var floors := 2 if building_type == "Commercial Building" else 1
	for floor in range(floors):
		var wy: float = base.position.y + 10.0 + floor * (base.size.y / 2.0)
		var count := 4 if building_type == "Warehouse" else 3
		for i in range(count):
			var wx: float = base.position.x + 8.0 + i * ((base.size.x - 16.0) / float(count))
			var lit := stage >= 4 and ((i + floor) % 2 == 0)
			var broken := stage == 0 and ((i + floor) % 3 == 0)
			var win := Rect2(wx, wy, (base.size.x - 16.0) / float(count) - 6.0, 16.0)
			draw_rect(win, LIT if lit else DARK_WIN, true)
			if broken:
				draw_line(win.position, win.position + win.size, BOARD, 2.0)
				draw_line(win.position + Vector2(win.size.x, 0), win.position + Vector2(0, win.size.y), BOARD, 2.0)
	var door := Rect2(base.position + Vector2(base.size.x / 2.0 - 9.0, base.size.y - 24.0), Vector2(18, 24))
	draw_rect(door, DARK_WIN if stage < 2 else roof, true)
	if stage == 0:
		draw_line(door.position, door.position + door.size, BOARD, 3.0)
	if stage >= 3:
		draw_line(base.position + Vector2(0, 2), base.position + Vector2(base.size.x, 2), TRIM, 2.0)
	if stage >= 5:
		var sign := Rect2(rect.position + Vector2(w.x * 0.2, w.y * 0.30 - 14.0), Vector2(w.x * 0.6, 12.0))
		draw_rect(sign, TRIM, true)
	if stage > 0 and stage < 5:
		var bar := Rect2(rect.position + Vector2(0, w.y + 2.0), Vector2(w.x, 4.0))
		draw_rect(bar, Color("17282e"), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * (float(stage) / 5.0), bar.size.y)), TRIM, true)

func _unhandled_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var is_selection := false
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		is_selection = click.pressed and click.button_index == MOUSE_BUTTON_LEFT
		if is_selection:
			point = click.position
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		is_selection = touch.pressed
		if is_selection:
			point = touch.position
	if not is_selection:
		return
	for slot in map_rects():
		if (slot["rect"] as Rect2).has_point(point):
			_select_property(str(slot["id"]))
			get_viewport().set_input_as_handled()
			return

func _select_property(property_id: String) -> void:
	var scene = get_tree().current_scene if get_tree() != null else null
	if scene != null:
		var commands = scene.get_node_or_null("GameplayCommandSystem")
		if commands != null:
			var property_system = commands.get("property_system")
			if property_system != null and property_system.has_method("select_property"):
				property_system.select_property(property_id)
				return
	var state = _state()
	if state == null:
		return
	var catalog = state.get_value("properties", "catalog", [])
	if catalog is Array:
		for index in range((catalog as Array).size()):
			if (catalog as Array)[index] is Dictionary and str(((catalog as Array)[index] as Dictionary).get("id", "")) == property_id:
				state.set_value("properties", "selected_property", index)
				return
