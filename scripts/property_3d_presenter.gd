extends Node3D
class_name Property3DPresenter

var _visual_stage := "neglected"
var _archetype := "warehouse"
var _business_open := false
var _built := false

var _building_root: Node3D
var _detail_root: Node3D
var _operational_root: Node3D
var _debris_root: Node3D
var _body: MeshInstance3D
var _roof: MeshInstance3D
var _sign: MeshInstance3D
var _windows: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []

var _wall_dirty: StandardMaterial3D
var _wall_repaired: StandardMaterial3D
var _wall_painted: StandardMaterial3D
var _roof_dirty: StandardMaterial3D
var _roof_clean: StandardMaterial3D
var _metal: StandardMaterial3D
var _glass_off: StandardMaterial3D
var _glass_on: StandardMaterial3D
var _accent: StandardMaterial3D
var _ground_material: StandardMaterial3D

func _ready() -> void:
    _build_once()
    _apply_visual_state(false)

func apply_snapshot(snapshot: Dictionary, animate: bool = true) -> void:
    _visual_stage = str(snapshot.get("stage", "neglected")).to_lower()
    _archetype = str(snapshot.get("archetype", "warehouse")).to_lower()
    _business_open = bool(snapshot.get("business_open", false))
    if not is_inside_tree():
        return
    _build_once()
    _apply_visual_state(animate)

func get_visual_stage() -> String:
    return _visual_stage

func get_archetype() -> String:
    return _archetype

func _build_once() -> void:
    if _built:
        return
    _built = true
    _create_materials()

    _building_root = Node3D.new()
    _building_root.name = "Building"
    add_child(_building_root)

    _detail_root = Node3D.new()
    _detail_root.name = "Details"
    _building_root.add_child(_detail_root)

    _operational_root = Node3D.new()
    _operational_root.name = "Operational"
    _building_root.add_child(_operational_root)

    _debris_root = Node3D.new()
    _debris_root.name = "Debris"
    add_child(_debris_root)

    _make_box("SiteSlab", Vector3(14.0, 0.35, 10.0), Vector3(0.0, 0.0, 0.0), _ground_material, self)
    _body = _make_box("MainBody", Vector3(8.8, 3.8, 5.6), Vector3(0.0, 2.1, 0.0), _wall_dirty, _building_root)
    _roof = _make_box("Roof", Vector3(9.4, 0.45, 6.2), Vector3(0.0, 4.15, 0.0), _roof_dirty, _building_root)

    for i in range(3):
        _make_box("LoadingDoor%d" % i, Vector3(1.65, 2.2, 0.16), Vector3(-2.2 + i * 2.2, 1.55, 2.88), _metal, _detail_root)
    _make_box("OfficeDoor", Vector3(1.1, 2.2, 0.16), Vector3(3.25, 1.45, 2.88), _metal, _detail_root)

    for i in range(4):
        var window := _make_box("Window%d" % i, Vector3(1.1, 0.85, 0.12), Vector3(-3.1 + i * 2.05, 3.0, 2.91), _glass_off, _detail_root)
        _windows.append(window)

    _sign = _make_box("Sign", Vector3(3.3, 0.75, 0.18), Vector3(0.0, 4.55, 2.98), _accent, _detail_root)

    _make_box("DockCanopy", Vector3(6.8, 0.18, 1.35), Vector3(-0.4, 3.2, 3.35), _metal, _detail_root)
    _make_box("SideUnit", Vector3(1.8, 2.4, 2.0), Vector3(5.0, 1.4, -1.2), _wall_repaired, _detail_root)

    for i in range(5):
        var chunk := _make_box("Debris%d" % i, Vector3(0.55 + i * 0.08, 0.25, 0.4), Vector3(-4.6 + i * 1.6, 0.35, 3.6 - float(i % 2)), _roof_dirty, _debris_root)
        chunk.rotation.y = float(i) * 0.37

    _make_box("Pallets", Vector3(1.6, 0.45, 1.1), Vector3(4.3, 0.45, 3.1), _metal, _operational_root)
    _make_box("DispatchCrate", Vector3(1.0, 0.85, 0.9), Vector3(2.9, 0.65, 3.2), _accent, _operational_root)

    for x in [-2.6, 2.6]:
        var light := OmniLight3D.new()
        light.name = "WorkLight"
        light.position = Vector3(x, 4.0, 3.8)
        light.light_color = Color("ffd98a")
        light.light_energy = 1.7
        light.omni_range = 5.5
        light.shadow_enabled = false
        _operational_root.add_child(light)
        _lights.append(light)

func _create_materials() -> void:
    _wall_dirty = _material(Color("4d514b"), 0.08, 0.96)
    _wall_repaired = _material(Color("768079"), 0.04, 0.86)
    _wall_painted = _material(Color("d7d0b8"), 0.02, 0.72)
    _roof_dirty = _material(Color("403f3a"), 0.12, 0.95)
    _roof_clean = _material(Color("4e6670"), 0.28, 0.68)
    _metal = _material(Color("3e5660"), 0.58, 0.46)
    _glass_off = _material(Color("4b6670"), 0.18, 0.38)
    _glass_on = _material(Color("ffdca0"), 0.12, 0.32, true)
    _accent = _material(Color("e3b955"), 0.32, 0.42, true)
    _ground_material = _material(Color("59615a"), 0.0, 1.0)

func _material(color: Color, metallic: float, roughness: float, emissive: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    if emissive:
        material.emission_enabled = true
        material.emission = color * 0.55
        material.emission_energy_multiplier = 0.75
    return material

func _make_box(node_name: String, size: Vector3, position: Vector3, material: Material, parent: Node) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.position = position
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _apply_visual_state(animate: bool) -> void:
    if not _built:
        return
    var rank := _stage_rank(_visual_stage)
    _debris_root.visible = rank < 1
    _roof.visible = rank >= 2 or rank == 0
    _detail_root.visible = rank >= 2
    _sign.visible = rank >= 3
    _operational_root.visible = rank >= 4

    if rank <= 0:
        _body.material_override = _wall_dirty
        _roof.material_override = _roof_dirty
    elif rank == 1:
        _body.material_override = _wall_repaired
        _roof.material_override = _roof_dirty
    elif rank == 2:
        _body.material_override = _wall_repaired
        _roof.material_override = _roof_clean
    else:
        _body.material_override = _wall_painted
        _roof.material_override = _roof_clean

    var active := rank >= 5 and _business_open
    for window in _windows:
        window.material_override = _glass_on if active else _glass_off
    for light in _lights:
        light.visible = active

    var target_scale := _archetype_scale(_archetype)
    if animate:
        _building_root.scale = target_scale * 0.965
        var tween := create_tween()
        tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(_building_root, "scale", target_scale, 0.34)
    else:
        _building_root.scale = target_scale

func _stage_rank(stage_name: String) -> int:
    match stage_name:
        "cleaned": return 1
        "repaired": return 2
        "painted": return 3
        "furnished": return 4
        "operational": return 5
        _: return 0

func _archetype_scale(archetype: String) -> Vector3:
    match archetype:
        "factory": return Vector3(1.18, 1.15, 1.08)
        "office": return Vector3(0.84, 1.35, 0.86)
        "retail": return Vector3(1.06, 0.82, 0.92)
        "resource": return Vector3(1.14, 0.76, 1.20)
        _: return Vector3.ONE
