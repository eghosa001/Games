extends Node2D

## Flat property overview board.
## Properties are management records with upgrade/restoration levels.
## No building/world rendering is used here.

const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const GOLD := Color("e4bd68")
const GREEN := Color("7ed0c3")
const BORDER := Color("355057")
const SURFACE := Color("102027")
const SURFACE_ALT := Color("162a31")
const TRACK := Color("20363d")

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
	var parts: Array = [str(state.get_value("player", "day", 1)), str(state.get_value("properties", "selected_property", 0))]
	if catalog is Array:
		for entry in catalog:
			if entry is Dictionary:
				parts.append("%s:%s:%s:%d:%d:%d:%d:%s:%d" % [str(entry.get("id", "")), str(entry.get("owned", false)), str(entry.get("inspected", false)), int(entry.get("cleaning", 0)), int(entry.get("repair", 0)), int(entry.get("painting", 0)), int(entry.get("furnishing", 0)), str(entry.get("condition", 0)), int(entry.get("lease_until", 0))])
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

func _restoration_percent(property: Dictionary) -> int:
	var total := 0
	for step in ["cleaning", "repair", "painting", "furnishing"]:
		total += clampi(int(property.get(step, 0)), 0, 100)
	return int(round(float(total) / 4.0))

func _map_area() -> Rect2:
	var viewport := get_viewport_rect().size
	var top := 210.0 if viewport.x >= 700.0 else 190.0
	var bottom := viewport.y - 180.0
	var left := 18.0
	var right := viewport.x - 18.0
	var hud := get_tree().root.get_node_or_null("Renew/UI/MainHUD") if get_tree() != null and get_tree().root != null else null
	if hud != null:
		var dock: Variant = hud.get("action_dock")
		if dock is Control and dock.visible:
			bottom = minf(bottom, (dock as Control).get_global_rect().position.y - 10.0)
		var rail: Variant = hud.get("left_rail")
		if rail is Control and rail.visible:
			left = maxf(left, (rail as Control).get_global_rect().end.x + 10.0)
	return Rect2(left, top, maxf(140.0, right - left), maxf(80.0, bottom - top))

func map_rects() -> Array:
	var out: Array = []
	var state = _state()
	if state == null:
		return out
	var catalog = state.get_value("properties", "catalog", [])
	if not catalog is Array or catalog.is_empty():
		return out
	var area := _map_area()
	var count: int = catalog.size()
	var cols: int = 3 if area.size.x >= 980.0 else (2 if area.size.x >= 600.0 else 1)
	cols = mini(cols, count)
	var rows := int(ceil(float(count) / float(maxi(cols, 1))))
	var gap := 10.0
	var cell_w := (area.size.x - gap * float(cols - 1)) / float(maxi(cols, 1))
	var cell_h := maxf(84.0, (area.size.y - gap * float(rows - 1)) / float(maxi(rows, 1)))
	for i in range(count):
		var col := i % cols
		var row := i / cols
		var rect := Rect2(area.position + Vector2(float(col) * (cell_w + gap), float(row) * (cell_h + gap)), Vector2(cell_w, cell_h))
		out.append({"id": str(catalog[i].get("id", "")), "rect": rect})
	return out

func _draw() -> void:
	var state = _state()
	if state == null:
		return
	var catalog = state.get_value("properties", "catalog", [])
	if not catalog is Array or catalog.is_empty():
		return
	var selected := int(state.get_value("properties", "selected_property", 0))
	var business_open := bool(state.get_value("businesses", "business_open", false))
	var origin_property_id := str(state.get_value("businesses", "origin_property_id", ""))
	var day := int(state.get_value("player", "day", 1))
	var font := ThemeDB.fallback_font
	for i in range(map_rects().size()):
		var slot: Dictionary = map_rects()[i]
		var entry: Dictionary = catalog[i]
		var rect: Rect2 = slot["rect"]
		var owned := bool(entry.get("owned", false))
		var stage := stage_of(entry, owned)
		var progress := _restoration_percent(entry)
		var selected_card := i == selected
		draw_rect(rect, SURFACE_ALT if selected_card else SURFACE, true)
		draw_rect(rect, GOLD if selected_card else BORDER, false, 2.0 if selected_card else 1.0)
		var pad := 14.0
		draw_string(font, rect.position + Vector2(pad, 23), str(entry.get("name", "Property")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - pad * 2.0, 13, TEXT)
		var status := _stage_caption(stage, business_open and owned and str(entry.get("id", "")) == origin_property_id)
		if not owned and bool(entry.get("inspected", false)):
			status = "SURVEYED"
		draw_string(font, rect.position + Vector2(pad, 43), "%s  •  %s" % [str(entry.get("type", "Property")), status], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - pad * 2.0, 10, MUTED)
		var bar := Rect2(rect.position + Vector2(pad, rect.size.y - 27), Vector2(maxf(40.0, rect.size.x - pad * 2.0), 7.0))
		draw_rect(bar, TRACK, true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(progress) / 100.0, bar.size.y)), GREEN if progress >= 100 else GOLD, true)
		draw_string(font, rect.position + Vector2(pad, rect.size.y - 36), "UPGRADE %d/6  •  %d%%" % [stage + 1, progress], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - pad * 2.0, 9, TEXT)
		if int(entry.get("lease_until", 0)) > day:
			draw_string(font, rect.position + Vector2(rect.size.x - 84, 23), "LEASED", HORIZONTAL_ALIGNMENT_RIGHT, 70, 9, GOLD)

func _stage_caption(stage: int, operating: bool) -> String:
	if operating and stage >= 5:
		return "OPERATING"
	return ["ABANDONED", "CLEANED", "REPAIRED", "PAINTED", "FURNISHED", "RESTORED"][clampi(stage, 0, 5)]

func _unhandled_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var select := false
	if event is InputEventMouseButton:
		select = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		point = event.position
	elif event is InputEventScreenTouch:
		select = event.pressed
		point = event.position
	if not select:
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
		for index in range(catalog.size()):
			if catalog[index] is Dictionary and str(catalog[index].get("id", "")) == property_id:
				state.set_value("properties", "selected_property", index)
				return
