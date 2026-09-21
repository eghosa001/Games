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
var _environment_node: WorldEnvironment
var _sun: DirectionalLight3D
var _sky_fill: DirectionalLight3D
var _property_rim: OmniLight3D
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
    if _presenter != null and _presenter.has_signal("property_interacted"):
        var interaction := Callable(self, "_on_property_interacted")
        if not _presenter.is_connected("property_interacted", interaction):
            _presenter.connect("property_interacted", interaction)
    _camera = get_node_or_null("CameraRig/Camera3D") as Camera3D
    _environment_node = get_node_or_null("Environment") as WorldEnvironment
    _sun = get_node_or_null("Sun") as DirectionalLight3D
    _sky_fill = get_node_or_null("SkyFill") as DirectionalLight3D
    _property_rim = get_node_or_null("PropertyRim") as OmniLight3D
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

func _on_property_interacted(_stage: String, business_open: bool) -> void:
    var game := get_tree().root.get_node_or_null("Renew")
    if game == null:
        return

    # Direct-manipulation core loop: tapping the property advances the current
    # meaningful property action instead of forcing a menu detour.
    if not bool(game.get("inspected")):
        if game.has_method("inspect_property"):
            game.inspect_property()
        return
    if not bool(game.get("owned")):
        if game.has_method("acquire_property"):
            game.acquire_property()
        return
    if str(game.get("stage")).to_lower() != "operational":
        if game.has_method("restore_property"):
            game.restore_property()
        return

    if not business_open:
        var hud := get_tree().root.get_node_or_null("Renew/UI/MainHUD")
        if hud != null and hud.has_method("_open_business_choices"):
            hud.call("_open_business_choices")
        return

    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen("BusinessOperationsPanel")

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
    _update_environment_for_snapshot(snapshot, animate)
    _update_camera_for_snapshot(previous, snapshot, animate)

func _update_environment_for_snapshot(snapshot: Dictionary, animate: bool) -> void:
    var phase := str(snapshot.get("economy_phase", "expansion")).to_lower()
    var prosperity := clampi(int(snapshot.get("prosperity_tier", 0)), 0, 3)
    var event_count := maxi(0, int(snapshot.get("active_event_count", 0)))
    var event_category := str(snapshot.get("active_event_category", "")).to_lower()

    var background := Color("09122a")
    var ambient := Color("9dadd8")
    var ambient_energy := 0.70
    var sun_color := Color("ffe7c2")
    var sun_energy := 1.20
    var fill_color := Color("7d9cff")
    var fill_energy := 0.32
    var rim_color := Color("70a8ff")
    var rim_energy := 0.68 + float(prosperity) * 0.08

    match phase:
        "boom":
            background = Color("10234a")
            ambient = Color("b9c8ff")
            ambient_energy = 0.82
            sun_color = Color("ffe5a8")
            sun_energy = 1.34
            fill_energy = 0.40
        "recession":
            background = Color("07101d")
            ambient = Color("8290b6")
            ambient_energy = 0.55
            sun_color = Color("c8d1e3")
            sun_energy = 0.92
            fill_color = Color("6679a8")
            fill_energy = 0.24
            rim_energy = 0.48
        "recovery":
            background = Color("0b1b32")
            ambient = Color("9dbed0")
            ambient_energy = 0.72
            sun_color = Color("f5e2bd")
            sun_energy = 1.18
        "overheating":
            background = Color("24152a")
            ambient = Color("d7a9b3")
            ambient_energy = 0.72
            sun_color = Color("ffd0aa")
            sun_energy = 1.28
            fill_color = Color("b17188")

    if event_count > 0:
        if event_category in ["energy", "finance", "supply_chain", "production"]:
            background = background.lerp(Color("341923"), 0.40)
            ambient = ambient.lerp(Color("ffb280"), 0.32)
            rim_color = Color("ff9b68")
            rim_energy += 0.18
        else:
            background = background.lerp(Color("0c2f2c"), 0.28)
            ambient = ambient.lerp(Color("86d8c3"), 0.24)
            rim_color = Color("7fe3c3")

    if _environment_node != null and _environment_node.environment != null:
        var environment := _environment_node.environment
        environment.background_color = background
        environment.ambient_light_color = ambient
        environment.ambient_light_energy = ambient_energy

    _apply_light_state(_sun, sun_color, sun_energy, animate)
    _apply_light_state(_sky_fill, fill_color, fill_energy, animate)
    _apply_light_state(_property_rim, rim_color, rim_energy, animate)

func _apply_light_state(light: Light3D, color: Color, energy: float, animate: bool) -> void:
    if light == null:
        return
    if not animate or bool(ProjectSettings.get_setting("renew/ui/reduce_motion", false)):
        light.light_color = color
        light.light_energy = energy
        return
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(light, "light_color", color, 0.45)
    tween.tween_property(light, "light_energy", energy, 0.45)

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
