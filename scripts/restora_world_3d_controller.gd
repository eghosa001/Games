extends Node3D
class_name RestoraWorld3DController

const VisualState = preload("res://scripts/restora_3d_visual_state.gd")

const LEGACY_WORLD_RENDERER_PATHS := [
    "../World/EmpireController",
    "../World/Corporate",
    "../World/WorldMissions",
    "../World/RegionController",
    "../World/BranchController",
    "../World/RivalSupplyController",
]

@export var poll_interval: float = 0.16
@export var presentation_enabled: bool = true

var _poll_elapsed := 0.0
var _last_snapshot: Dictionary = {}
var _presenter: Node
var _district: Node
var _camera: Camera3D
var _legacy_world_view: CanvasItem
var _legacy_property_map: CanvasItem
var _legacy_world_renderers: Array[CanvasItem] = []
var _camera_target := Vector3(0.0, 1.8, 0.0)
var _camera_base_target := Vector3(0.0, 1.8, 0.0)
var _camera_base_position := Vector3(12.8, 8.4, 14.8)
var _camera_tween: Tween
var _camera_idle_time := 0.0

func _ready() -> void:
    _presenter = get_node_or_null("Properties/ActiveProperty3D")
    _district = get_node_or_null("DistrictDressing/RestoraDistrict3D")
    _camera = get_node_or_null("CameraRig/Camera3D") as Camera3D
    _legacy_world_view = get_node_or_null("../World/WorldView") as CanvasItem
    _legacy_property_map = get_node_or_null("../World/PropertyMap") as CanvasItem
    for path in LEGACY_WORLD_RENDERER_PATHS:
        var renderer := get_node_or_null(path) as CanvasItem
        if renderer != null:
            _legacy_world_renderers.append(renderer)
    _apply_presentation_visibility()
    if not presentation_enabled:
        set_process(false)
        return
    if _camera != null:
        _camera.current = true
        _camera_base_position = _camera.position
        _camera_base_target = _camera_target
        _camera.look_at(_camera_target, Vector3.UP)
    _sync_visuals(false)

func _process(delta: float) -> void:
    if not presentation_enabled:
        return
    _camera_idle_time += delta
    _poll_elapsed += delta
    _update_camera_pose()
    if _poll_elapsed < poll_interval:
        return
    _poll_elapsed = 0.0
    _sync_visuals(true)

func read_visual_snapshot(state: Node) -> Dictionary:
    return VisualState.snapshot_from_game_state(state)

func _sync_visuals(animate: bool) -> void:
    var state := get_node_or_null("/root/RenewGameState")
    var snapshot := read_visual_snapshot(state)
    if snapshot == _last_snapshot:
        return
    var previous := _last_snapshot
    _last_snapshot = snapshot.duplicate(true)
    if _presenter != null and _presenter.has_method("apply_snapshot"):
        _presenter.apply_snapshot(snapshot, animate)
    if _district != null and _district.has_method("apply_snapshot"):
        _district.apply_snapshot(snapshot, animate)
    _update_camera_for_snapshot(previous, snapshot, animate)

func _update_camera_for_snapshot(previous: Dictionary, snapshot: Dictionary, animate: bool) -> void:
    if _camera == null:
        return
    var stage := str(snapshot.get("stage", "neglected"))
    var stage_changed := str(previous.get("stage", "")) != stage
    var property_changed := int(previous.get("selected_property", -1)) != int(snapshot.get("selected_property", 0))
    var business_open := bool(snapshot.get("business_open", false))
    var activity_tier := clampi(int(snapshot.get("activity_tier", 0)), 0, 3)

    var desired_position := Vector3(12.8, 8.4, 14.8)
    var desired_target := Vector3(0.0, 1.8, 0.0)
    var desired_fov := 45.0

    if property_changed:
        desired_position = Vector3(11.2, 7.2, 12.7)
        desired_target = Vector3(0.0, 2.0, 0.1)
        desired_fov = 43.0
    if stage_changed and stage not in ["neglected", "cleaned"]:
        desired_position = Vector3(9.4, 6.4, 10.6)
        desired_target = Vector3(0.0, 2.15, 0.25)
        desired_fov = 41.5
    if stage == "operational" and business_open:
        desired_position = Vector3(10.8, 6.8, 12.0)
        desired_target = Vector3(0.0, 2.0, 1.0)
        desired_fov = 42.0 - float(activity_tier) * 0.55

    if _camera_tween != null and _camera_tween.is_valid():
        _camera_tween.kill()

    _camera_base_position = desired_position
    _camera_base_target = desired_target
    if not animate:
        _camera.position = desired_position
        _camera.fov = desired_fov
        _camera_target = desired_target
        return

    _camera_tween = create_tween().set_parallel(true)
    _camera_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _camera_tween.tween_property(_camera, "position", desired_position, 0.72)
    _camera_tween.tween_property(_camera, "fov", desired_fov, 0.72)
    _camera_tween.tween_method(_set_camera_target, _camera_target, desired_target, 0.72)

func _set_camera_target(value: Vector3) -> void:
    _camera_target = value

func _update_camera_pose() -> void:
    if _camera == null:
        return
    # Subtle presentation drift gives the world depth without turning the
    # management camera into a constantly orbiting cinematic camera.
    if _camera_tween == null or not _camera_tween.is_valid():
        var drift_x := sin(_camera_idle_time * 0.22) * 0.10
        var drift_y := sin(_camera_idle_time * 0.17 + 0.8) * 0.045
        _camera_target = _camera_base_target + Vector3(drift_x, drift_y, 0.0)
    _camera.look_at(_camera_target, Vector3.UP)

func _apply_presentation_visibility() -> void:
    visible = presentation_enabled
    if _camera != null:
        _camera.current = presentation_enabled
    var child_process_mode := Node.PROCESS_MODE_INHERIT if presentation_enabled else Node.PROCESS_MODE_DISABLED
    if _presenter != null:
        _presenter.process_mode = child_process_mode
    if _district != null:
        _district.process_mode = child_process_mode
    if _legacy_world_view != null:
        _legacy_world_view.visible = not presentation_enabled
    if _legacy_property_map != null:
        _legacy_property_map.visible = not presentation_enabled
        _legacy_property_map.set_process(not presentation_enabled)
        _legacy_property_map.set_process_unhandled_input(not presentation_enabled)
    for renderer in _legacy_world_renderers:
        if renderer != null:
            renderer.visible = not presentation_enabled

func set_presentation_enabled(value: bool) -> void:
    presentation_enabled = value
    _apply_presentation_visibility()
    set_process(value)
    if value:
        _sync_visuals(false)
