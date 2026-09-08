extends Node3D

## RENEW 3D WORLD — 3D-P1 technical prototype.
## Presentation only: simulation truth remains in existing GameState/systems.
## The visible prototype uses real GameState property IDs whenever the catalog is available.

const WORLD_SIZE := Vector3(42.0, 0.0, 30.0)
const GROUND_Y := -0.05
const FALLBACK_PROPERTIES := [
	{"id":"property_hq","name":"Headquarters","type":"Commercial Building"},
	{"id":"property_factory","name":"Factory","type":"Workshop"},
	{"id":"property_warehouse","name":"Warehouse","type":"Warehouse"},
	{"id":"property_resource","name":"Resource Site","type":"Warehouse"}
]

var camera: Camera3D
var selected_entity_id := ""
var selected_label: Label
var status_label: Label
var objects: Array[Node3D] = []
var previous_2d_visibility: Dictionary = {}
var is_open := false
var camera_target := Vector3(0.0, 1.0, 0.0)
var camera_yaw := 0.0
var camera_pitch := -48.0
var camera_distance := 38.0
var camera_dragging := false
var last_pointer := Vector2.ZERO
var map_button: Button

func _ready() -> void:
	visible = false
	_build_world()
	_build_overlay()
	_apply_camera()

func _build_world() -> void:
	var world_environment := Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color("071319")
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color("8fa7aa")
	world_environment.ambient_light_energy = 0.7
	var environment := WorldEnvironment.new()
	environment.environment = world_environment
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	var camera_node := Camera3D.new()
	camera_node.name = "World3DCamera"
	camera_node.current = true
	add_child(camera_node)
	camera = camera_node

	_create_box("Terrain", Vector3(0.0, GROUND_Y, 0.0), Vector3(WORLD_SIZE.x, 0.1, WORLD_SIZE.z), Color("19353b"), "")
	_create_box("Road", Vector3(0.0, 0.02, 0.0), Vector3(WORLD_SIZE.x - 4.0, 0.05, 3.2), Color("0d2026"), "")
	_create_box("RoadWest", Vector3(-10.0, 0.03, 0.0), Vector3(2.4, 0.06, WORLD_SIZE.z - 4.0), Color("0d2026"), "")
	_create_box("RoadEast", Vector3(10.0, 0.03, 0.0), Vector3(2.4, 0.06, WORLD_SIZE.z - 4.0), Color("0d2026"), "")

	var specs := _property_specs()
	var positions := [Vector3(0.0, 2.0, -8.0), Vector3(-11.0, 2.5, 8.0), Vector3(11.0, 2.0, 8.0), Vector3(-14.0, 1.5, -9.0)]
	var sizes := [Vector3(7.0, 4.0, 5.0), Vector3(8.0, 5.0, 7.0), Vector3(7.0, 4.0, 7.0), Vector3(5.0, 3.0, 5.0)]
	var materials := [Color("274b55"), Color("31515a"), Color("3b555c"), Color("3b6259")]
	for i in range(mini(4, specs.size())):
		var entry: Dictionary = specs[i]
		_create_property(str(entry.get("id", "")), str(entry.get("name", "Property")), positions[i], sizes[i], materials[i])
		_create_label(str(entry.get("name", "PROPERTY")).to_upper(), positions[i] + Vector3(0.0, sizes[i].y / 2.0 + 0.6, 0.0))

func _property_specs() -> Array:
	var state := get_node_or_null("/root/RenewGameState")
	if state != null and state.has_method("get_value"):
		var catalog: Variant = state.get_value("properties", "catalog", [])
		if catalog is Array and not catalog.is_empty():
			var result: Array = []
			for entry in catalog:
				if entry is Dictionary and not str(entry.get("id", "")).is_empty():
					result.append(entry.duplicate(true))
					if result.size() == 4:
						break
			if not result.is_empty():
				return result
	return FALLBACK_PROPERTIES.duplicate(true)

func _create_box(node_name: String, position: Vector3, size: Vector3, material_color: Color, entity_id: String) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(material_color)
	mesh_instance.set_meta("entity_id", entity_id)
	add_child(mesh_instance)
	if not entity_id.is_empty():
		var body := StaticBody3D.new()
		body.name = node_name + "Collider"
		body.position = position
		body.set_meta("entity_id", entity_id)
		body.set_meta("display_name", node_name)
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		add_child(body)
	return mesh_instance

func _create_property(entity_id: String, title: String, position: Vector3, size: Vector3, material_color: Color) -> void:
	var property := _create_box(title, position, size, material_color, entity_id)
	property.set_meta("display_name", title)
	property.set_meta("visual_kind", "property")
	objects.append(property)
	_create_box("Foundation", position + Vector3(0.0, -1.8, 0.0), Vector3(size.x + 0.3, 0.15, size.z + 0.3), Color("668083"), "")

func _create_label(text_value: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position
	label.font_size = 32
	label.modulate = Color("e4bd68")
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _material(material_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = material_color
	material.roughness = 0.72
	return material

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var panel := PanelContainer.new()
	panel.name = "World3DStatus"
	panel.position = Vector2(16, 70)
	panel.size = Vector2(430, 158)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var title := Label.new()
	title.text = "RENEW 3D WORLD • TECHNICAL PROTOTYPE"
	title.add_theme_font_size_override("font_size", 15)
	box.add_child(title)
	status_label = Label.new()
	status_label.text = "Strategic region • Select a property"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)
	selected_label = Label.new()
	selected_label.text = "No property selected"
	selected_label.add_theme_font_size_override("font_size", 11)
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(selected_label)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 5)
	box.add_child(controls)
	var zoom_out := _make_overlay_button("−")
	zoom_out.tooltip_text = "Zoom out"
	zoom_out.pressed.connect(_zoom_out)
	controls.add_child(zoom_out)
	var reset := _make_overlay_button("RESET VIEW")
	reset.pressed.connect(_reset_camera)
	controls.add_child(reset)
	var zoom_in := _make_overlay_button("+")
	zoom_in.tooltip_text = "Zoom in"
	zoom_in.pressed.connect(_zoom_in)
	controls.add_child(zoom_in)
	map_button = _make_overlay_button("OPEN PROPERTY MAP")
	map_button.disabled = true
	map_button.pressed.connect(_open_property_map)
	controls.add_child(map_button)

func _make_overlay_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(58, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 10)
	return button

func open_world() -> void:
	is_open = true
	visible = true
	_sync_2d_world(false)
	status_label.text = "Strategic region • 3D presentation active"
	_apply_camera()

func close_world() -> void:
	is_open = false
	visible = false
	_sync_2d_world(true)
	selected_entity_id = ""
	selected_label.text = "No property selected"
	map_button.disabled = true
	camera_dragging = false

func toggle_world() -> void:
	if is_open:
		close_world()
	else:
		open_world()

func _sync_2d_world(should_show: bool) -> void:
	var root := get_node_or_null("/root/Renew/World")
	if root == null:
		return
	var presentation_nodes := ["PremiumWorldBackdrop", "PremiumIndustrialScene", "PremiumRestorationScene", "RichWorldScenery", "PropertyVisual", "WorldView", "PropertyMap"]
	if should_show:
		for node_name in previous_2d_visibility:
			var restore_node := root.get_node_or_null(node_name)
			if restore_node != null:
				restore_node.visible = bool(previous_2d_visibility[node_name])
		previous_2d_visibility.clear()
		return
	for node_name in presentation_nodes:
		var node := root.get_node_or_null(node_name)
		if node == null:
			continue
		previous_2d_visibility[node_name] = node.visible
		node.visible = false

func _apply_camera() -> void:
	if camera == null:
		return
	camera_pitch = clampf(camera_pitch, -78.0, -25.0)
	camera_distance = clampf(camera_distance, 18.0, 55.0)
	var yaw := deg_to_rad(camera_yaw)
	var pitch := deg_to_rad(camera_pitch)
	var offset := Vector3(cos(pitch) * sin(yaw), -sin(pitch), cos(pitch) * cos(yaw)) * camera_distance
	camera.position = camera_target + offset
	camera.look_at(camera_target, Vector3.UP)

func _reset_camera() -> void:
	camera_yaw = 0.0
	camera_pitch = -48.0
	camera_distance = 38.0
	_apply_camera()

func _zoom_in() -> void:
	camera_distance = maxf(18.0, camera_distance - 4.0)
	_apply_camera()

func _zoom_out() -> void:
	camera_distance = minf(55.0, camera_distance + 4.0)
	_apply_camera()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_world()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				last_pointer = click.position
				camera_dragging = true
				_select_at_screen(click.position)
			else:
				camera_dragging = false
			get_viewport().set_input_as_handled()
			return
		if click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
			get_viewport().set_input_as_handled()
			return
		if click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and camera_dragging:
		var motion: InputEventMouseMotion = event
		camera_yaw -= motion.relative.x * 0.35
		camera_pitch = clampf(camera_pitch - motion.relative.y * 0.22, -78.0, -25.0)
		_apply_camera()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			last_pointer = touch.position
			camera_dragging = true
			_select_at_screen(touch.position)
		else:
			camera_dragging = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and camera_dragging:
		var drag: InputEventScreenDrag = event
		camera_yaw -= drag.relative.x * 0.35
		camera_pitch = clampf(camera_pitch - drag.relative.y * 0.22, -78.0, -25.0)
		_apply_camera()
		get_viewport().set_input_as_handled()

func _select_at_screen(screen_position: Vector2) -> void:
	if camera == null:
		return
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		selected_entity_id = ""
		selected_label.text = "No property selected"
		status_label.text = "Strategic region • Select a property"
		map_button.disabled = true
		return
	var collider: Object = hit.get("collider")
	if collider == null or not collider.has_meta("entity_id"):
		return
	var entity_id := str(collider.get_meta("entity_id"))
	if entity_id.is_empty():
		return
	selected_entity_id = entity_id
	var display_name := str(collider.get_meta("display_name", entity_id))
	selected_label.text = "Selected: %s  [%s]" % [display_name, entity_id]
	map_button.disabled = false
	_bind_selection_to_state(entity_id)

func _bind_selection_to_state(entity_id: String) -> void:
	var state := get_node_or_null("/root/RenewGameState")
	if state == null or not state.has_method("get_value") or not state.has_method("set_value"):
		status_label.text = "3D selection: %s • simulation state unavailable" % entity_id
		return
	var catalog: Variant = state.get_value("properties", "catalog", [])
	if not catalog is Array:
		status_label.text = "3D selection: %s" % entity_id
		return
	for index in range(catalog.size()):
		var entry: Variant = catalog[index]
		if entry is Dictionary and str(entry.get("id", "")) == entity_id:
			state.set_value("properties", "selected_property", index)
			status_label.text = "Selected property is synchronized with GameState."
			return
	status_label.text = "Prototype object selected: %s" % entity_id

func _open_property_map() -> void:
	if selected_entity_id.is_empty():
		return
	var root := get_node_or_null("/root/Renew/World")
	if root == null:
		return
	var property_map := root.get_node_or_null("PropertyMap")
	if property_map == null:
		return
	close_world()
	property_map.visible = true
	if property_map.has_method("queue_redraw"):
		property_map.queue_redraw()
	status_label.text = ""
