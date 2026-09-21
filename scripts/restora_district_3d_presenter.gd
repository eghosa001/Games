extends Node3D
class_name RestoraDistrict3DPresenter

var _visual_stage := "neglected"
var _archetype := "warehouse"
var _business_open := false
var _activity_enabled := false
var _activity_tier := 0
var _traffic_level := 0
var _worker_visual_count := 0
var _reputation := 0
var _built := false
var _elapsed := 0.0

var _district_root: Node3D
var _construction_root: Node3D
var _operations_root: Node3D
var _truck_a: Node3D
var _truck_b: Node3D
var _workers: Array[Node3D] = []
var _construction_props: Array[Node3D] = []
var _operations_workers: Array[Node3D] = []
var _customer_actors: Array[Node3D] = []
var _street_vehicles: Array[Node3D] = []

var _concrete: StandardMaterial3D
var _dark_metal: StandardMaterial3D
var _brick: StandardMaterial3D
var _office: StandardMaterial3D
var _glass: StandardMaterial3D
var _green: StandardMaterial3D
var _yellow: StandardMaterial3D
var _truck_material: StandardMaterial3D
var _worker_material: StandardMaterial3D
var _lamp_material: StandardMaterial3D
var _car_blue: StandardMaterial3D
var _car_coral: StandardMaterial3D
var _person_blue: StandardMaterial3D
var _person_green: StandardMaterial3D
var _district_sign: Label3D

func _ready() -> void:
    _build_once()
    _apply_visual_state()

func _process(delta: float) -> void:
    if not _built:
        return
    _elapsed += delta
    _animate_construction()
    _animate_operations()

func apply_snapshot(snapshot: Dictionary, _animate: bool = true) -> void:
    _visual_stage = str(snapshot.get("stage", "neglected")).to_lower()
    _archetype = str(snapshot.get("archetype", "warehouse")).to_lower()
    _business_open = bool(snapshot.get("business_open", false))
    _activity_tier = clampi(int(snapshot.get("activity_tier", 0)), 0, 3)
    _traffic_level = clampi(int(snapshot.get("traffic_level", 0)), 0, 3)
    _worker_visual_count = clampi(int(snapshot.get("worker_visual_count", 0)), 0, 6)
    _reputation = maxi(0, int(snapshot.get("reputation", 0)))
    _activity_enabled = _visual_stage == "operational" and _business_open
    if not is_inside_tree():
        return
    _build_once()
    _apply_visual_state()

func get_visual_stage() -> String:
    return _visual_stage

func is_activity_enabled() -> bool:
    return _activity_enabled

func heading_for_x_velocity(x_velocity: float) -> float:
    return PI if x_velocity > 0.0 else 0.0

func _build_once() -> void:
    if _built:
        return
    _built = true
    _create_materials()

    _district_root = Node3D.new()
    _district_root.name = "DistrictGeometry"
    add_child(_district_root)

    _construction_root = Node3D.new()
    _construction_root.name = "ConstructionActivity"
    add_child(_construction_root)

    _operations_root = Node3D.new()
    _operations_root.name = "OperationalActivity"
    add_child(_operations_root)

    _build_neighbors()
    _build_roadside()
    _build_construction_activity()
    _build_operational_activity()

func _create_materials() -> void:
    _concrete = _material(Color("727a73"), 0.0, 0.95)
    _dark_metal = _material(Color("35434a"), 0.45, 0.55)
    _brick = _material(Color("7a5144"), 0.0, 0.92)
    _office = _material(Color("9aa6a3"), 0.05, 0.78)
    _glass = _material(Color("527681"), 0.18, 0.28)
    _green = _material(Color("3f775c"), 0.0, 0.9)
    _yellow = _material(Color("d9a84f"), 0.15, 0.62, true)
    _truck_material = _material(Color("557c8b"), 0.2, 0.58)
    _worker_material = _material(Color("d8863d"), 0.0, 0.82)
    _lamp_material = _material(Color("ffe2a3"), 0.0, 0.35, true)
    _car_blue = _material(Color("4f6fcb"), 0.28, 0.38)
    _car_coral = _material(Color("cc6678"), 0.22, 0.42)
    _person_blue = _material(Color("5578d8"), 0.02, 0.78)
    _person_green = _material(Color("4fa77a"), 0.02, 0.78)

func _material(color: Color, metallic: float, roughness: float, emissive: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    if emissive:
        material.emission_enabled = true
        material.emission = color * 0.65
        material.emission_energy_multiplier = 0.8
    return material

func _build_neighbors() -> void:
    _make_box("LeftWarehouse", Vector3(6.0, 3.1, 4.8), Vector3(-10.2, 1.45, -2.2), _brick, _district_root)
    _make_box("LeftRoof", Vector3(6.4, 0.32, 5.2), Vector3(-10.2, 3.15, -2.2), _dark_metal, _district_root)
    _make_box("RightOffice", Vector3(4.8, 5.4, 4.2), Vector3(9.6, 2.6, -2.8), _office, _district_root)
    for floor_index in range(3):
        for col in range(2):
            _make_box("OfficeWindow%d_%d" % [floor_index, col], Vector3(1.25, 0.65, 0.12), Vector3(8.45 + col * 2.1, 1.35 + floor_index * 1.45, -0.64), _glass, _district_root)
    _make_box("UtilityBuilding", Vector3(4.0, 2.4, 3.4), Vector3(10.6, 1.1, 4.0), _dark_metal, _district_root)

func _build_roadside() -> void:
    for x in [-10.0, -5.0, 5.0, 10.0]:
        _make_box("LampPost", Vector3(0.12, 3.2, 0.12), Vector3(x, 1.55, 5.7), _dark_metal, _district_root)
        _make_box("LampHead", Vector3(0.55, 0.18, 0.22), Vector3(x, 3.18, 5.7), _lamp_material, _district_root)
    for x in [-11.2, -7.7, 7.5, 11.3]:
        var tree := Node3D.new()
        tree.name = "StreetTree"
        tree.position = Vector3(x, 0.0, 3.2)
        _district_root.add_child(tree)
        _make_box("Trunk", Vector3(0.28, 1.45, 0.28), Vector3(0.0, 0.72, 0.0), _dark_metal, tree)
        _make_sphere("Crown", 0.9, Vector3(0.0, 1.85, 0.0), _green, tree)
    _make_box("FenceLeft", Vector3(5.5, 0.9, 0.12), Vector3(-9.6, 0.45, 2.0), _dark_metal, _district_root)
    _make_box("FenceRight", Vector3(5.5, 0.9, 0.12), Vector3(9.6, 0.45, 2.0), _dark_metal, _district_root)

    # Lightweight district detail: lane markers, benches and planters improve
    # scale/readability without introducing expensive imported meshes.
    for x in [-10.5, -6.0, -1.5, 3.0, 7.5]:
        _make_box("LaneMarker", Vector3(2.0, 0.03, 0.12), Vector3(x, 0.04, 7.0), _yellow, _district_root)
    for x in [-7.5, 7.5]:
        _make_box("BenchSeat", Vector3(1.8, 0.12, 0.55), Vector3(x, 0.55, 4.3), _office, _district_root)
        _make_box("BenchLegA", Vector3(0.12, 0.55, 0.12), Vector3(x - 0.6, 0.28, 4.3), _dark_metal, _district_root)
        _make_box("BenchLegB", Vector3(0.12, 0.55, 0.12), Vector3(x + 0.6, 0.28, 4.3), _dark_metal, _district_root)
    for x in [-4.2, 4.2]:
        _make_box("Planter", Vector3(1.1, 0.55, 1.1), Vector3(x, 0.28, 3.15), _concrete, _district_root)
        _make_sphere("PlanterShrub", 0.62, Vector3(x, 1.0, 3.15), _green, _district_root)

    # Branded district furniture and transit cues make the environment read as
    # a designed place rather than a collection of primitive boxes.
    _make_box("BusShelterRoof", Vector3(3.0, 0.14, 1.25), Vector3(-7.3, 2.25, 4.8), _dark_metal, _district_root)
    _make_box("BusShelterBack", Vector3(3.0, 1.65, 0.12), Vector3(-7.3, 1.35, 4.25), _glass, _district_root)
    for x in [-8.6, -6.0]:
        _make_box("BusShelterPost", Vector3(0.10, 2.2, 0.10), Vector3(x, 1.1, 4.8), _dark_metal, _district_root)

    _make_box("DistrictSignBase", Vector3(3.6, 1.25, 0.26), Vector3(7.5, 1.15, 4.55), _dark_metal, _district_root)
    _district_sign = Label3D.new()
    _district_sign.name = "DistrictBrand"
    _district_sign.text = "RESTORA DISTRICT"
    _district_sign.font_size = 28
    _district_sign.pixel_size = 0.006
    _district_sign.position = Vector3(7.5, 1.18, 4.72)
    _district_sign.modulate = Color("ffe8a3")
    _district_sign.outline_modulate = Color(0.02, 0.04, 0.09, 0.9)
    _district_sign.outline_size = 5
    _district_root.add_child(_district_sign)

func _build_construction_activity() -> void:
    for index in range(3):
        var worker := _make_worker("Builder%d" % index, Vector3(-2.8 + index * 2.6, 0.0, 3.9), _construction_root)
        _workers.append(worker)
    for index in range(4):
        var cone := _make_box("Barrier%d" % index, Vector3(0.5, 0.65, 0.5), Vector3(-3.0 + index * 2.0, 0.33, 4.8), _yellow, _construction_root)
        _construction_props.append(cone)
    _make_box("Skip", Vector3(2.2, 0.9, 1.4), Vector3(-5.0, 0.45, 3.7), _dark_metal, _construction_root)

func _build_operational_activity() -> void:
    _truck_a = _make_truck("DeliveryTruckA", Vector3(-8.0, 0.0, 7.0))
    _truck_a.rotation.y = heading_for_x_velocity(1.0)
    _operations_root.add_child(_truck_a)
    _truck_b = _make_truck("DeliveryTruckB", Vector3(5.5, 0.0, 7.0))
    _truck_b.rotation.y = heading_for_x_velocity(-1.0)
    _truck_b.scale = Vector3(0.85, 0.85, 0.85)
    _operations_root.add_child(_truck_b)
    _make_box("DispatchPallets", Vector3(2.4, 0.6, 1.3), Vector3(4.8, 0.3, 3.9), _yellow, _operations_root)

    # Small actor pools are reused and visibility-scaled from authoritative
    # activity data, keeping mobile draw/animation costs predictable.
    for index in range(6):
        var worker := _make_worker("Operator%d" % index, Vector3(-4.0 + float(index % 3) * 2.0, 0.0, 3.2 + float(index / 3) * 1.05), _operations_root)
        worker.visible = false
        _operations_workers.append(worker)

    for index in range(4):
        var customer := _make_worker("Visitor%d" % index, Vector3(-6.5 + float(index) * 1.6, 0.0, 4.7), _operations_root)
        customer.scale = Vector3(0.86, 0.86, 0.86)
        customer.visible = false
        _customer_actors.append(customer)

    for index in range(3):
        var car := _make_car("StreetCar%d" % index, Vector3(-9.0 + float(index) * 5.5, 0.0, 7.0))
        car.visible = false
        _operations_root.add_child(car)
        _street_vehicles.append(car)

func _make_truck(node_name: String, position: Vector3) -> Node3D:
    var truck := Node3D.new()
    truck.name = node_name
    truck.position = position
    _make_box("Cargo", Vector3(2.8, 1.55, 1.45), Vector3(0.25, 1.15, 0.0), _truck_material, truck)
    _make_box("CargoStripe", Vector3(2.3, 0.16, 1.48), Vector3(0.25, 1.35, 0.0), _yellow, truck)
    _make_box("Cab", Vector3(1.05, 1.25, 1.45), Vector3(-1.65, 0.9, 0.0), _office, truck)
    for x in [-1.55, 0.85]:
        for z in [-0.66, 0.66]:
            _make_cylinder("Wheel", 0.34, 0.22, Vector3(x, 0.35, z), _dark_metal, truck)
    return truck

func _make_car(node_name: String, position: Vector3) -> Node3D:
    var car := Node3D.new()
    car.name = node_name
    car.position = position
    var variant := int(node_name.unicode_at(node_name.length() - 1)) if node_name.length() > 0 else 0
    var body_material: StandardMaterial3D = _car_blue if variant % 2 == 0 else _car_coral
    _make_box("Body", Vector3(1.85, 0.58, 0.95), Vector3(0.0, 0.58, 0.0), body_material, car)
    _make_box("BumperFront", Vector3(0.12, 0.22, 0.88), Vector3(-0.98, 0.48, 0.0), _dark_metal, car)
    _make_box("BumperRear", Vector3(0.12, 0.22, 0.88), Vector3(0.98, 0.48, 0.0), _dark_metal, car)
    _make_box("Cabin", Vector3(0.9, 0.48, 0.82), Vector3(-0.15, 1.02, 0.0), _glass, car)
    for x in [-0.62, 0.62]:
        for z in [-0.43, 0.43]:
            _make_cylinder("Wheel", 0.22, 0.16, Vector3(x, 0.28, z), _dark_metal, car)
    return car

func _make_worker(node_name: String, position: Vector3, parent: Node) -> Node3D:
    var worker := Node3D.new()
    worker.name = node_name
    worker.position = position
    parent.add_child(worker)
    var variant := int(node_name.unicode_at(node_name.length() - 1)) if node_name.length() > 0 else 0
    var is_builder := node_name.begins_with("Builder")
    var clothing: StandardMaterial3D = _worker_material if is_builder else (_person_blue if variant % 2 == 0 else _person_green)
    _make_box("Body", Vector3(0.36, 0.78, 0.30), Vector3(0.0, 0.9, 0.0), clothing, worker)
    _make_box("ArmL", Vector3(0.09, 0.50, 0.09), Vector3(-0.25, 0.92, 0.0), clothing, worker)
    _make_box("ArmR", Vector3(0.09, 0.50, 0.09), Vector3(0.25, 0.92, 0.0), clothing, worker)
    _make_sphere("Head", 0.2, Vector3(0.0, 1.42, 0.0), _office, worker)
    if is_builder:
        _make_box("Helmet", Vector3(0.46, 0.12, 0.38), Vector3(0.0, 1.6, 0.0), _yellow, worker)
        _make_box("SafetyVest", Vector3(0.38, 0.18, 0.32), Vector3(0.0, 1.0, 0.0), _yellow, worker)
    else:
        _make_box("Hair", Vector3(0.34, 0.10, 0.30), Vector3(0.0, 1.58, 0.0), _dark_metal, worker)
    return worker

func _apply_visual_state() -> void:
    if not _built:
        return
    var rank := _stage_rank(_visual_stage)
    _construction_root.visible = rank >= 1 and rank < 5
    _operations_root.visible = _activity_enabled
    if _district_sign != null:
        _district_sign.modulate.a = 0.78 + minf(0.18, float(_reputation) / 500.0)
    if _activity_enabled:
        for index in range(_operations_workers.size()):
            _operations_workers[index].visible = index < _worker_visual_count
        var visible_customers := clampi(_activity_tier + (1 if _reputation >= 50 else 0), 0, _customer_actors.size())
        for index in range(_customer_actors.size()):
            _customer_actors[index].visible = index < visible_customers
        for index in range(_street_vehicles.size()):
            _street_vehicles[index].visible = index < _traffic_level
    set_process(_construction_root.visible or _activity_enabled)

func _animate_construction() -> void:
    if not _construction_root.visible:
        return
    for index in range(_workers.size()):
        var worker := _workers[index]
        worker.rotation.y = sin(_elapsed * 1.2 + float(index)) * 0.22
        worker.position.y = sin(_elapsed * 2.2 + float(index) * 0.7) * 0.035
    for index in range(_construction_props.size()):
        _construction_props[index].rotation.y = sin(_elapsed * 0.6 + float(index)) * 0.035

func _animate_operations() -> void:
    if not _activity_enabled:
        return

    var speed_boost := 1.0 + float(_activity_tier) * 0.12
    if _truck_a != null:
        _truck_a.position.x = -12.0 + fmod(_elapsed * 1.4 * speed_boost, 24.0)
    if _truck_b != null:
        _truck_b.position.x = 12.0 - fmod(_elapsed * 1.0 * speed_boost, 24.0)

    for index in range(_operations_workers.size()):
        var worker := _operations_workers[index]
        if not worker.visible:
            continue
        var phase := _elapsed * (0.55 + float(index) * 0.04) + float(index) * 0.85
        worker.position.x += sin(phase) * 0.004
        worker.position.z += cos(phase * 0.73) * 0.003
        worker.rotation.y = sin(phase * 0.8) * 0.35
        worker.position.y = abs(sin(phase * 2.2)) * 0.025

    for index in range(_customer_actors.size()):
        var customer := _customer_actors[index]
        if not customer.visible:
            continue
        var t := fmod(_elapsed * (0.08 + float(index) * 0.008) + float(index) * 0.21, 1.0)
        customer.position.x = lerpf(-7.0, 5.8, t)
        customer.position.z = 4.5 + sin(t * TAU + float(index)) * 0.35
        customer.rotation.y = heading_for_x_velocity(1.0)

    for index in range(_street_vehicles.size()):
        var car := _street_vehicles[index]
        if not car.visible:
            continue
        var direction := 1.0 if index % 2 == 0 else -1.0
        var base_t := fmod(_elapsed * (0.10 + 0.018 * float(index)) * speed_boost + float(index) * 0.31, 1.0)
        var t := base_t if direction > 0.0 else 1.0 - base_t
        car.position.x = lerpf(-13.0, 13.0, t)
        car.position.z = 7.55 + float(index % 2) * 0.55
        car.rotation.y = heading_for_x_velocity(direction)
    if _district_sign != null:
        _district_sign.modulate.a = 0.78 + 0.10 * sin(_elapsed * 1.1) + minf(0.10, float(_reputation) / 700.0)

func _stage_rank(stage_name: String) -> int:
    match stage_name:
        "cleaned": return 1
        "repaired": return 2
        "painted": return 3
        "furnished": return 4
        "operational": return 5
        _: return 0

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

func _make_sphere(node_name: String, radius: float, position: Vector3, material: Material, parent: Node) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 8
    mesh.rings = 4
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
    mesh.radial_segments = 8
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.position = position
    instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    instance.material_override = material
    parent.add_child(instance)
    return instance
