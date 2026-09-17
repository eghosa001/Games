extends Node3D
class_name RestoraWorld3DController

const VisualState = preload("res://scripts/restora_3d_visual_state.gd")

@export var poll_interval: float = 0.16
@export var presentation_enabled: bool = true

var _poll_elapsed := 0.0
var _last_snapshot: Dictionary = {}
var _presenter: Node
var _camera: Camera3D
var _camera_target := Vector3(0.0, 1.8, 0.0)

func _ready() -> void:
    _presenter = get_node_or_null("Properties/ActiveProperty3D")
    _camera = get_node_or_null("CameraRig/Camera3D") as Camera3D
    if not presentation_enabled:
        visible = false
        set_process(false)
        return
    visible = true
    if _camera != null:
        _camera.current = true
        _camera.look_at(_camera_target, Vector3.UP)
    _sync_visuals(false)

func _process(delta: float) -> void:
    if not presentation_enabled:
        return
    _poll_elapsed += delta
    if _poll_elapsed < poll_interval:
        if _camera != null:
            _camera.look_at(_camera_target, Vector3.UP)
        return
    _poll_elapsed = 0.0
    _sync_visuals(true)
    if _camera != null:
        _camera.look_at(_camera_target, Vector3.UP)

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
    _update_camera_for_snapshot(previous, snapshot, animate)

func _update_camera_for_snapshot(previous: Dictionary, snapshot: Dictionary, animate: bool) -> void:
    if _camera == null:
        return
    var stage := str(snapshot.get("stage", "neglected"))
    var stage_changed := str(previous.get("stage", "")) != stage
    var property_changed := int(previous.get("selected_property", -1)) != int(snapshot.get("selected_property", 0))
    var desired := Vector3(10.8, 7.8, 12.4)
    if stage_changed and stage not in ["neglected", "cleaned"]:
        desired = Vector3(8.4, 6.0, 9.4)
    elif property_changed:
        desired = Vector3(9.4, 6.8, 10.8)
    if not animate:
        _camera.position = desired
        return
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(_camera, "position", desired, 0.55)

func set_presentation_enabled(value: bool) -> void:
    presentation_enabled = value
    visible = value
    set_process(value)
    if value:
        _sync_visuals(false)
