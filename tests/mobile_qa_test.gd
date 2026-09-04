extends SceneTree

const TARGETS: Array[Vector2i] = [Vector2i(320, 480), Vector2i(360, 640), Vector2i(480, 800), Vector2i(720, 1280), Vector2i(1024, 768)]
const MIN_TOUCH: float = 44.0
const SAVE_LIMIT_MS: float = 1000.0
const FPS_TARGET: float = 30.0
const MEMORY_GROWTH_LIMIT_MB: float = 64.0
var failures: Array[String] = []
var warnings: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    print("RENEW MOBILE QA — automated gate")
    var packed: PackedScene = load("res://scenes/Main.tscn") as PackedScene
    if packed == null: fail("Main.tscn could not be loaded"); _finish(); return
    var scene: Node = packed.instantiate()
    current_scene = scene
    root.add_child(scene)
    await process_frame
    await process_frame
    var hud: Node = scene.get_node_or_null("UI/MainHUD")
    if hud == null: fail("MainHUD missing at UI/MainHUD"); _finish(); return
    var ui_root: Control = hud.get("root") as Control
    if ui_root == null: fail("Mobile HUD root Control is unavailable")
    else:
        _test_responsive_layout(hud, ui_root)
        _test_touch_surface(hud)
        _test_world_tab(hud)
    _test_gameplay_flow(scene, hud)
    _test_save_load()
    await _test_runtime_stability()
    _finish()

func _test_responsive_layout(hud: Node, ui_root: Control) -> void:
    for target: Vector2i in TARGETS:
        ui_root.size = Vector2(target); hud._layout_responsive(); await process_frame
        check("viewport %dx%d accepted" % [target.x, target.y], ui_root.size.x >= target.x - 1.0 and ui_root.size.y >= target.y - 1.0)
        _check_control_inside(hud.get("tabs") as Control, "tabs", target)
        _check_control_inside(hud.get("status_label") as Control, "status", target)
        _check_control_inside(hud.get("action_scroll") as Control, "action scroll", target)
        _check_control_inside(hud.get("feedback_panel") as Control, "feedback", target)
        _check_control_inside(hud.get("goal_label") as Control, "goal", target)
        var tabs: HBoxContainer = hud.get("tabs") as HBoxContainer
        if tabs != null:
            for child: Node in tabs.get_children():
                var button: Button = child as Button
                if button != null: check("%dx%d tab touch target >=44" % [target.x, target.y], button.size.x >= MIN_TOUCH and button.size.y >= MIN_TOUCH)
        var actions: GridContainer = hud.get("actions") as GridContainer
        if actions != null:
            for child: Node in actions.get_children():
                var action_button: Button = child as Button
                if action_button != null: check("%dx%d action touch target >=44" % [target.x, target.y], action_button.size.x >= MIN_TOUCH and action_button.size.y >= MIN_TOUCH)

func _check_control_inside(child: Control, label: String, target: Vector2i) -> void:
    if child == null: fail("%s control missing" % label); return
    var rect: Rect2 = Rect2(child.position, child.size); var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(target)); check("%dx%d %s stays in viewport" % [target.x, target.y, label], bounds.encloses(rect))

func _test_touch_surface(hud: Node) -> void:
    var tabs: HBoxContainer = hud.get("tabs") as HBoxContainer
    check("four mobile tabs exposed", tabs != null and tabs.get_child_count() == 4)
    if tabs == null: return
    for i: int in range(4):
        var tab: Button = tabs.get_child(i) as Button
        if tab == null: fail("tab %d is not a Button" % i); continue
        tab.pressed.emit(); await process_frame; check("touch path switches to tab %d" % i, int(hud.get("active_tab")) == i)

func _test_world_tab(hud: Node) -> void:
    hud._set_tab(3); await process_frame
    var actions: GridContainer = hud.get("actions") as GridContainer
    check("WORLD tab remains selectable", int(hud.get("active_tab")) == 3 and actions != null)
    if actions == null: return
    check("WORLD tab has actionable controls", actions.get_child_count() > 0)

func _test_gameplay_flow(_scene: Node, hud: Node) -> void:
    hud._set_tab(0); await process_frame
    var steps: Array[String] = ["INSPECT", "ACQUIRE", "RESTORE", "OPEN BUSINESS"]
    for label: String in steps:
        var button: Button = _find_button(hud, label); check("touch action exists: %s" % label, button != null)
        if button != null: button.pressed.emit(); await process_frame
    hud._set_tab(1); await process_frame
    var business_steps: Array[String] = ["HIRE", "BUY INPUTS", "PRODUCE", "PRICE", "END DAY"]
    for label: String in business_steps:
        var button: Button = _find_button(hud, label); check("touch action exists: %s" % label, button != null)
        if button != null: button.pressed.emit(); await process_frame
    var state: Node = get_root().get_node_or_null("RenewGameState"); check("authoritative GameState remains alive after touch flow", state != null)

func _find_button(hud: Node, label: String) -> Button:
    var actions: GridContainer = hud.get("actions") as GridContainer
    if actions == null: return null
    for child: Node in actions.get_children():
        var button: Button = child as Button
        if button != null and button.text == label: return button
    return null

func _test_save_load() -> void:
    var state: Node = get_root().get_node_or_null("RenewGameState"); check("GameState autoload available for save/load", state != null)
    if state == null: return
    var save_system: Script = preload("res://scripts/save_system.gd")
    var started: int = Time.get_ticks_usec(); var snapshot: Dictionary = state.capture() as Dictionary; var capture_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
    check("GameState capture completes", not snapshot.is_empty()); check("capture is below 1s", capture_ms < SAVE_LIMIT_MS)
    started = Time.get_ticks_usec(); var restored: bool = bool(state.restore(snapshot)); var restore_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
    check("GameState restore succeeds", restored); check("restore is below 1s", restore_ms < SAVE_LIMIT_MS)
    started = Time.get_ticks_usec(); var saved: bool = bool(save_system.save_game({"domains": snapshot.get("domains", {})})); var disk_save_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
    check("disk save succeeds", saved); check("disk save is below 1s", disk_save_ms < SAVE_LIMIT_MS)
    started = Time.get_ticks_usec(); var loaded: Dictionary = save_system.load_game() as Dictionary; var disk_load_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
    check("disk load returns valid state", not loaded.is_empty()); check("disk load is below 1s", disk_load_ms < SAVE_LIMIT_MS)
    print("SAVE/LOAD timings: capture %.1fms, restore %.1fms, disk save %.1fms, disk load %.1fms" % [capture_ms, restore_ms, disk_save_ms, disk_load_ms])

func _test_runtime_stability() -> void:
    var start_memory: float = _memory_mb(); var start_frames: int = Engine.get_process_frames(); var start_time: int = Time.get_ticks_msec()
    while Time.get_ticks_msec() - start_time < 3000: await process_frame
    var elapsed: float = maxf(float(Time.get_ticks_msec() - start_time) / 1000.0, 0.001); var frames: int = Engine.get_process_frames() - start_frames; var measured_fps: float = float(frames) / elapsed; var end_memory: float = _memory_mb()
    print("RUNTIME: %.1f FPS, memory %.1fMB -> %.1fMB" % [measured_fps, start_memory, end_memory])
    if measured_fps > 0.0 and measured_fps < FPS_TARGET: fail("runtime FPS %.1f is below %0.0f FPS" % [measured_fps, FPS_TARGET])
    else: warnings.append("30 FPS low-end Android requirement is device-dependent; automated run measured %.1f FPS" % measured_fps)
    if start_memory >= 0.0 and end_memory >= 0.0 and end_memory - start_memory > MEMORY_GROWTH_LIMIT_MB: fail("memory grew %.1fMB during stability sample" % (end_memory - start_memory))
    else: warnings.append("memory stability is a short automated sample; repeat on a physical low-end Android device")

func _memory_mb() -> float:
    return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
func check(label: String, condition: bool) -> void:
    checks += 1
    if condition: print("PASS: %s" % label)
    else: fail(label)
func fail(label: String) -> void:
    failures.append(label); print("FAIL: %s" % label)
func _finish() -> void:
    print("--- MOBILE QA SUMMARY ---"); print("Checks: %d | Failures: %d | Warnings: %d" % [checks, failures.size(), warnings.size()])
    for warning: String in warnings: print("WARN: %s" % warning)
    if not failures.is_empty():
        for failure: String in failures: print("FAILED: %s" % failure)
        quit(1)
    else: print("AUTOMATED MOBILE QA: PASS"); quit(0)
