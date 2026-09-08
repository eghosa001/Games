extends Node3D

## RENEW 3D WORLD — 3D-P1 technical prototype.
## Presentation only: simulation truth remains in existing GameState/systems.
## This prototype can be toggled without replacing the management interface.

const WORLD_SIZE := Vector3(42.0, 0.0, 30.0)
const GROUND_Y := -0.05

var camera: Camera3D
var selected_entity_id := ""
var selected_label: Label
var status_label: Label
var objects: Array[Node3D] = []
var previous_2d_visibility: Dictionary = {}
var is_open := false

func _ready() -> void:
	visible = false
	_build_world()
	_build_overlay()

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
	camera_node.position = Vector3(0.0, 26.0, 28.0)
	camera_node.rotation_degrees = Vector3(-48.0, 0.0, 0.0)
	camera_node.current = true
	add_child(camera_node)
	camera = camera_node

	_create_box("Terrain", Vector3(0.0, GROUND_Y, 0.0), Vector3(WORLD_SIZE.x, 0.1, WORLD_SIZE.z), Color("19353b"), "")
	_create_box("Road", Vector3(0.0, 0.02, 0.0), Vector3(WORLD_SIZE.x - 4.0, 0.05, 3.2), Color("0d2026"), "")
	_create_box("RoadWest", Vector3(-10.0, 0.03, 0.0), Vector3(2.4, 0.06, WORLD_SIZE.z - 4.0), Color("0d2026"), "")
	_create_box("RoadEast", Vector3(10.0, 0.03, 0.0), Vector3(2.4, 0.06, WORLD_SIZE.z - 4.0), Color("0d2026"), "")

	_create_property("property_hq", "Headquarters", Vector3(0.0, 2.0, -8.0), Vector3(7.0, 4.0, 5.0), Color("274b55"))
	_create_property("property_factory", "Factory", Vector3(-11.0, 2.5, 8.0), Vector3(8.0, 5.0, 7.0), Color("31515a"))
	_create_property("property_warehouse", "Warehouse", Vector3(11.0, 2.0, 8.0), Vector3(7.0, 4.0, 7.0), Color("3b555c"))
	_create_property("property_resource", "Resource Site", Vector3(-14.0, 1.5, -9.0), Vector3(5.0, 3.0, 5.0), Color("3b6259"))

	_create_label("HQ", Vector3(0.0, 4.6, -8.0))
	_create_label("FACTORY", Vector3(-11.0, 5.7, 8.0))
	_create_label("WAREHOUSE", Vector3(11.0, 4.7, 8.0))
	_create_label("RESOURCE", Vector3(-14.0, 3.6, -9.0))

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
	panel.size = Vector2(410, 118)
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
	box.add_child(selected_label)

func open_world() -> void:
	is_open = true
	visible = true
	_sync_2d_world(false)
	status_label.text = "Strategic region • 3D presentation active"

func close_world() -> void:
	is_open = false
	visible = false
	_sync_2d_world(true)
	selected_entity_id = ""
	selected_label.text = "No property selected"

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

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_world()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_at_screen(event.position)
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
	status_label.text = "3D selection bound to an entity ID. Existing management systems remain authoritative."
