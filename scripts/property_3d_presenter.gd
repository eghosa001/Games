extends Node3D
class_name Property3DPresenter

var _visual_stage := "neglected"
var _archetype := "warehouse"
var _business_open := false
var _operational_motion_enabled := false
var _activity_tier := 0
var _worker_visual_count := 0
var _built := false
var _motion_time := 0.0
var _building_tween: Tween

var _building_root: Node3D
var _detail_root: Node3D
var _operational_root: Node3D
var _debris_root: Node3D
var _cleaning_root: Node3D
var _repair_root: Node3D
var _furnishing_root: Node3D
var _body: MeshInstance3D
var _roof: MeshInstance3D
var _sign: MeshInstance3D
var _windows: Array[MeshInstance3D] = []
var _loading_details: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _variant_walls: Array[MeshInstance3D] = []
var _variant_glass: Array[MeshInstance3D] = []
var _machinery_parts: Array[Node3D] = []
var _site_workers: Array[Node3D] = []
var _forklift: Node3D
var _forklift_base := Vector3.ZERO
var _archetype_roots: Dictionary = {}

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

func _process(delta: float) -> void:
    if not _built or not _operational_motion_enabled:
        return
    _motion_time += delta
    for index in range(_machinery_parts.size()):
        var part := _machinery_parts[index]
        if part == null or not part.is_visible_in_tree():
            continue
        part.rotation.z += delta * (0.8 + float(index) * 0.22) * (1.0 + float(_activity_tier) * 0.12)
        part.rotation.y = sin(_motion_time * 0.8 + float(index)) * 0.08

    for index in range(_site_workers.size()):
        var worker := _site_workers[index]
        if not worker.visible:
            continue
        var phase := _motion_time * (0.7 + float(index) * 0.05) + float(index) * 0.8
        worker.rotation.y = sin(phase) * 0.42
        worker.position.y = abs(sin(phase * 2.1)) * 0.03

    if _forklift != null and _forklift.visible:
        var travel := (sin(_motion_time * (0.55 + float(_activity_tier) * 0.08)) + 1.0) * 0.5
        _forklift.position = _forklift_base + Vector3(lerpf(0.0, 5.2, travel), 0.0, sin(_motion_time * 0.45) * 0.18)
        _forklift.rotation.y = 0.0 if cos(_motion_time * 0.55) >= 0.0 else PI

func apply_snapshot(snapshot: Dictionary, animate: bool = true) -> void:
    _visual_stage = str(snapshot.get("stage", "neglected")).to_lower()
    _archetype = str(snapshot.get("archetype", "warehouse")).to_lower()
    _business_open = bool(snapshot.get("business_open", false))
    _activity_tier = clampi(int(snapshot.get("activity_tier", 0)), 0, 3)
    _worker_visual_count = clampi(int(snapshot.get("worker_visual_count", 0)), 0, 6)
    _operational_motion_enabled = _visual_stage == "operational" and _business_open
    if not is_inside_tree():
        return
    _build_once()
    _apply_visual_state(animate)

func get_visual_stage() -> String:
    return _visual_stage

func get_archetype() -> String:
    return _archetype

func get_archetype_profile() -> String:
    match _archetype:
        "factory": return "industrial_stack"
        "office": return "vertical_glass"
        "retail": return "storefront_canopy"
        "resource": return "processing_yard"
        _: return "warehouse_bays"

func is_operational_motion_enabled() -> bool:
    return _operational_motion_enabled

func uses_loading_bays() -> bool:
    return _archetype in ["warehouse", "factory"]

func uses_base_front_windows() -> bool:
    return _archetype in ["warehouse", "factory"]

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

    _cleaning_root = Node3D.new()
    _cleaning_root.name = "CleaningStage"
    add_child(_cleaning_root)

    _repair_root = Node3D.new()
    _repair_root.name = "RepairStage"
    add_child(_repair_root)

    _furnishing_root = Node3D.new()
    _furnishing_root.name = "FurnishingStage"
    add_child(_furnishing_root)

    _make_box("SiteSlab", Vector3(14.0, 0.35, 10.0), Vector3(0.0, 0.0, 0.0), _ground_material, self)
    _body = _make_box("MainBody", Vector3(8.8, 3.8, 5.6), Vector3(0.0, 2.1, 0.0), _wall_dirty, _building_root)
    _roof = _make_box("Roof", Vector3(9.4, 0.45, 6.2), Vector3(0.0, 4.15, 0.0), _roof_dirty, _building_root)

    for i in range(3):
        var loading_door := _make_box("LoadingDoor%d" % i, Vector3(1.65, 2.2, 0.16), Vector3(-2.2 + i * 2.2, 1.55, 2.88), _metal, _detail_root)
        _loading_details.append(loading_door)
    _make_box("OfficeDoor", Vector3(1.1, 2.2, 0.16), Vector3(3.25, 1.45, 2.88), _metal, _detail_root)

    for i in range(4):
        var window := _make_box("Window%d" % i, Vector3(1.1, 0.85, 0.12), Vector3(-3.1 + i * 2.05, 3.0, 2.91), _glass_off, _detail_root)
        _windows.append(window)

    _sign = _make_box("Sign", Vector3(3.3, 0.75, 0.18), Vector3(0.0, 4.55, 2.98), _accent, _detail_root)
    var dock_canopy := _make_box("DockCanopy", Vector3(6.8, 0.18, 1.35), Vector3(-0.4, 3.2, 3.35), _metal, _detail_root)
    _loading_details.append(dock_canopy)
    var side_unit := _make_box("SideUnit", Vector3(1.8, 2.4, 2.0), Vector3(5.0, 1.4, -1.2), _wall_repaired, _detail_root)
    _loading_details.append(side_unit)
    _variant_walls.append(side_unit)

    _build_archetype_variants()

    for i in range(5):
        var chunk := _make_box("Debris%d" % i, Vector3(0.55 + i * 0.08, 0.25, 0.4), Vector3(-4.6 + i * 1.6, 0.35, 3.6 - float(i % 2)), _roof_dirty, _debris_root)
        chunk.rotation.y = float(i) * 0.37

    # Stage-specific visual storytelling. These props are presentation-only and
    # appear strictly from the authoritative restoration stage.
    _make_box("CleaningBin", Vector3(1.15, 0.8, 0.9), Vector3(-4.6, 0.48, 3.45), _metal, _cleaning_root)
    _make_box("CleaningCart", Vector3(1.5, 0.55, 0.75), Vector3(4.4, 0.36, 3.35), _accent, _cleaning_root)
    for x in [-3.8, -1.9, 0.0, 1.9, 3.8]:
        _make_box("ScaffoldPost", Vector3(0.14, 4.2, 0.14), Vector3(x, 2.15, 3.35), _metal, _repair_root)
    for y in [1.0, 2.4, 3.8]:
        _make_box("ScaffoldRail", Vector3(8.0, 0.10, 0.12), Vector3(0.0, y, 3.35), _accent, _repair_root)
    _make_box("MaterialStack", Vector3(2.0, 0.7, 1.15), Vector3(-4.2, 0.5, 2.95), _wall_repaired, _repair_root)

    _make_box("FurnitureCrates", Vector3(2.4, 1.15, 1.35), Vector3(3.8, 0.75, 3.2), _accent, _furnishing_root)
    _make_box("InstallBench", Vector3(2.6, 0.65, 1.0), Vector3(-3.8, 0.5, 3.1), _metal, _furnishing_root)

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

    for index in range(6):
        var worker := _make_site_worker("SiteWorker%d" % index, Vector3(-4.5 + float(index % 3) * 2.2, 0.0, 3.3 + float(index / 3) * 0.9), _operational_root)
        worker.visible = false
        _site_workers.append(worker)

    _forklift = Node3D.new()
    _forklift.name = "Forklift"
    _forklift.position = Vector3(-2.8, 0.0, 3.9)
    _forklift_base = _forklift.position
    _operational_root.add_child(_forklift)
    _make_box("ForkliftBody", Vector3(1.15, 0.72, 0.9), Vector3(0.0, 0.62, 0.0), _accent, _forklift)
    _make_box("ForkliftMast", Vector3(0.12, 1.5, 0.95), Vector3(0.62, 1.0, 0.0), _metal, _forklift)
    _make_box("ForkA", Vector3(0.95, 0.08, 0.10), Vector3(1.0, 0.22, -0.28), _metal, _forklift)
    _make_box("ForkB", Vector3(0.95, 0.08, 0.10), Vector3(1.0, 0.22, 0.28), _metal, _forklift)

func _build_archetype_variants() -> void:
    var warehouse := _new_variant_root("WarehouseVariant")
    _make_box("DockFrame", Vector3(7.8, 0.28, 0.35), Vector3(-0.35, 3.45, 3.48), _metal, warehouse)
    var warehouse_rear := _make_box("RearStorage", Vector3(3.0, 2.1, 2.5), Vector3(-3.9, 1.2, -3.8), _wall_repaired, warehouse)
    _variant_walls.append(warehouse_rear)
    _archetype_roots["warehouse"] = warehouse

    var factory := _new_variant_root("FactoryVariant")
    var factory_hall := _make_box("FactoryHall", Vector3(5.4, 2.5, 3.2), Vector3(-2.2, 5.1, -0.7), _wall_repaired, factory)
    _variant_walls.append(factory_hall)
    for x in [-3.4, -1.7, 2.9]:
        _make_cylinder("Stack", 0.42, 4.2, Vector3(x, 6.6, -1.4), _metal, factory)
    _make_cylinder("ProcessTank", 1.0, 2.4, Vector3(4.2, 1.4, -2.0), _metal, factory)
    _make_box("PipeBridge", Vector3(5.2, 0.25, 0.3), Vector3(1.5, 3.4, -2.0), _accent, factory)
    var factory_rotor := Node3D.new()
    factory_rotor.name = "FactoryRotor"
    factory_rotor.position = Vector3(4.2, 3.8, -1.9)
    factory.add_child(factory_rotor)
    _make_box("RotorBladeA", Vector3(2.2, 0.18, 0.22), Vector3.ZERO, _accent, factory_rotor)
    _make_box("RotorBladeB", Vector3(0.18, 2.2, 0.22), Vector3.ZERO, _accent, factory_rotor)
    _machinery_parts.append(factory_rotor)
    _archetype_roots["factory"] = factory

    var office := _new_variant_root("OfficeVariant")
    var office_tower := _make_box("OfficeTower", Vector3(5.4, 6.8, 4.3), Vector3(0.6, 4.7, 0.7), _wall_repaired, office)
    _variant_walls.append(office_tower)
    for floor_index in range(4):
        var glass_band := _make_box("GlassBand%d" % floor_index, Vector3(4.9, 0.58, 0.14), Vector3(0.6, 2.4 + floor_index * 1.4, 2.9), _glass_off, office)
        _variant_glass.append(glass_band)
    _make_box("OfficeCrown", Vector3(5.8, 0.35, 4.7), Vector3(0.6, 8.15, 0.7), _metal, office)
    _archetype_roots["office"] = office

    var retail := _new_variant_root("RetailVariant")
    var storefront_glass := _make_box("StorefrontGlass", Vector3(7.1, 2.15, 0.16), Vector3(0.0, 1.55, 2.98), _glass_off, retail)
    _variant_glass.append(storefront_glass)
    _make_box("RetailCanopy", Vector3(8.4, 0.32, 1.65), Vector3(0.0, 3.2, 3.55), _accent, retail)
    _make_box("RetailPylon", Vector3(1.1, 4.8, 0.6), Vector3(5.7, 2.4, 2.0), _metal, retail)
    _make_box("RetailSign", Vector3(2.1, 1.1, 0.22), Vector3(5.7, 4.5, 2.0), _accent, retail)
    _archetype_roots["retail"] = retail

    var resource := _new_variant_root("ResourceVariant")
    for x in [-3.0, 0.0, 3.0]:
        _make_cylinder("Silo", 0.85, 3.4, Vector3(x, 2.0, -3.2), _metal, resource)
    _make_box("Conveyor", Vector3(6.8, 0.38, 0.65), Vector3(0.0, 4.0, -2.5), _accent, resource)
    var conveyor_support := _make_box("ConveyorSupport", Vector3(0.35, 4.0, 0.35), Vector3(-3.0, 2.0, -2.5), _metal, resource)
    conveyor_support.rotation.z = -0.22
    var conveyor_drum := _make_cylinder("ConveyorDrum", 0.48, 0.9, Vector3(3.0, 4.0, -2.5), _metal, resource)
    conveyor_drum.rotation.x = PI * 0.5
    _machinery_parts.append(conveyor_drum)
    _make_box("ResourceYard", Vector3(5.0, 0.65, 2.8), Vector3(4.2, 0.35, 2.4), _roof_dirty, resource)
    _archetype_roots["resource"] = resource

func _new_variant_root(node_name: String) -> Node3D:
    var root := Node3D.new()
    root.name = node_name
    root.visible = false
    _building_root.add_child(root)
    return root

func _create_materials() -> void:
    _wall_dirty = _material(Color("4d514b"), 0.08, 0.96)
    _wall_repaired = _material(Color("768079"), 0.04, 0.86)
    _wall_painted = _material(Color("d7d0b8"), 0.02, 0.72)
    _roof_dirty = _material(Color("403f3a"), 0.12, 0.95)
    _roof_clean = _material(Color("4e6670"), 0.28, 0.68)
    _metal = _material(Color("3e5660"), 0.58, 0.46)
    _glass_off = _material(Color("4b6670"), 0.18, 0.38)
    _glass_on = _material(Color("ffdca0"), 0.12, 0.32, true)
    _accent = _material(Color("e3b955"), 0.32, 0.42)
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

func _make_cylinder(node_name: String, radius: float, height: float, position: Vector3, material: Material, parent: Node) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 10
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.position = position
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _make_site_worker(node_name: String, position: Vector3, parent: Node) -> Node3D:
    var worker := Node3D.new()
    worker.name = node_name
    worker.position = position
    parent.add_child(worker)
    _make_box("Body", Vector3(0.34, 0.78, 0.28), Vector3(0.0, 0.92, 0.0), _accent, worker)
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.21
    head_mesh.height = 0.42
    head_mesh.radial_segments = 8
    head_mesh.rings = 4
    var head := MeshInstance3D.new()
    head.name = "Head"
    head.mesh = head_mesh
    head.position = Vector3(0.0, 1.46, 0.0)
    head.material_override = _wall_painted
    worker.add_child(head)
    _make_box("HardHat", Vector3(0.42, 0.11, 0.36), Vector3(0.0, 1.65, 0.0), _accent, worker)
    return worker

func _apply_visual_state(animate: bool) -> void:
    if not _built:
        return
    var rank := _stage_rank(_visual_stage)
    _debris_root.visible = rank < 1
    _cleaning_root.visible = rank == 1
    _repair_root.visible = rank in [2, 3]
    _furnishing_root.visible = rank == 4
    _roof.visible = true
    _detail_root.visible = rank >= 2
    _operational_root.visible = rank >= 4
    _apply_archetype_visibility()
    _sign.visible = rank >= 3 and uses_loading_bays()

    var wall_material: StandardMaterial3D = _wall_dirty
    var roof_material: StandardMaterial3D = _roof_dirty
    if rank == 1:
        wall_material = _wall_repaired
    elif rank == 2:
        wall_material = _wall_repaired
        roof_material = _roof_clean
    elif rank >= 3:
        wall_material = _wall_painted
        roof_material = _roof_clean
    _body.material_override = wall_material
    _roof.material_override = roof_material
    for surface in _variant_walls:
        surface.material_override = wall_material

    var active := rank >= 5 and _business_open
    var glass_material: StandardMaterial3D = _glass_on if active else _glass_off
    for window in _windows:
        window.material_override = glass_material
    for window in _variant_glass:
        window.material_override = glass_material
    for light in _lights:
        light.visible = active
    for index in range(_site_workers.size()):
        _site_workers[index].visible = active and index < _worker_visual_count
    if _forklift != null:
        _forklift.visible = active and uses_loading_bays() and _activity_tier >= 2
    set_process(_operational_motion_enabled)

    var target_scale := _archetype_scale(_archetype)
    if _building_tween != null and _building_tween.is_valid():
        _building_tween.kill()
    if animate:
        _building_root.scale = target_scale * 0.965
        _building_tween = create_tween()
        _building_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        _building_tween.tween_property(_building_root, "scale", target_scale, 0.34)
    else:
        _building_root.scale = target_scale

func _apply_archetype_visibility() -> void:
    var target := _archetype if _archetype_roots.has(_archetype) else "warehouse"
    for key in _archetype_roots.keys():
        var root = _archetype_roots[key]
        if root is Node3D:
            root.visible = str(key) == target
    for detail in _loading_details:
        if detail != null:
            detail.visible = uses_loading_bays()
    for window in _windows:
        window.visible = uses_base_front_windows()

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
        "factory": return Vector3(1.08, 1.02, 1.03)
        "office": return Vector3(0.88, 0.90, 0.88)
        "retail": return Vector3(1.05, 0.86, 0.95)
        "resource": return Vector3(1.04, 0.90, 1.08)
        _: return Vector3.ONE
