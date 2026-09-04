extends SceneTree

const TARGETS := [Vector2i(320, 480), Vector2i(360, 640), Vector2i(480, 800), Vector2i(720, 1280), Vector2i(1024, 768)]
const MIN_TOUCH := 44.0
const SAVE_LIMIT_MS := 1000.0
const FPS_TARGET := 30.0
const MEMORY_GROWTH_LIMIT_MB := 64.0

var failures: Array[String] = []
var warnings: Array[String] = []
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    print("RENEW MOBILE QA — automated gate")
    var scene = load("res://scenes/Main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    var hud = scene.get_node_or_null("UI/MainHUD")
    if hud == null:
        fail("MainHUD missing at UI/MainHUD")
        _finish()
        return

    var ui_root = hud.get("root") as Control
    if ui_root == null:
        fail("Mobile HUD root Control is unavailable")
    else:
        _test_responsive_layout(hud, ui_root)
        _test_touch_surface(hud)
        _test_world_tab(hud)

    _test_gameplay_flow(scene, hud)
    _test_save_load()
    await _test_runtime_stability()
    _finish()

func _test_responsive_layout(hud: Node, ui_root: Control) -> void:
    for target in TARGETS:
        ui_root.size = Vector2(target)
        hud._layout_responsive()
        await process_frame
        check("viewport %dx%d accepted" % [target.x, target.y], ui_root.size.x >= target.x - 1.0 and ui_root.size.y >= target.y - 1.0)
        _check_control_inside(ui_root, hud.get("tabs"), "tabs", target)
        _check_control_inside(ui_root, hud.get("status_panel"), "status", target)
        _check_control_inside(ui_root, hud.get("action_scroll"), "action scroll", target)
        _check_control_inside(ui_root, hud.get("feedback_panel"), "feedback", target)
        _check_control_inside(ui_root, hud.get("goal_label"), "goal", target)
        var tabs = hud.get("tabs") as HBoxContainer
        if tabs != null:
            for child in tabs.get_children():
                if child is Button:
                    check("%dx%d tab touch target >=44" % [target.x, target.y], child.size.x >= MIN_TOUCH and child.size.y >= MIN_TOUCH)
        var actions = hud.get("actions") as GridContainer
        if actions != null:
            for child in actions.get_children():
                if child is Button:
                    check("%dx%d action touch target >=44" % [target.x, target.y], child.size.x >= MIN_TOUCH and child.size.y >= MIN_TOUCH)

func _check_control_inside(_container: Control, child: Control, label: String, target: Vector2i) -> void:
    if child == null:
        fail("%s control missing" % label)
        return
    var rect := Rect2(child.position, child.size)
    var bounds := Rect2(Vector2.ZERO, Vector2(target))
    check("%dx%d %s stays in viewport" % [target.x, target.y, label], bounds.encloses(rect))

func _test_touch_surface(hud: Node) -> void:
    # This exercises the same Button.pressed signal path used by a touch tap,
    # without keyboard input. Physical finger hit-testing remains a device gate.
    var tabs = hud.get("tabs") as HBoxContainer
    check("four mobile tabs exposed", tabs != null and tabs.get_child_count() == 4)
    if tabs == null:
        return
    for i in range(4):
        var tab = tabs.get_child(i) as Button
        if tab == null:
            fail("tab %d is not a Button" % i)
            continue
        tab.pressed.emit()
        await process_frame
        check("touch path switches to tab %d" % i, int(hud.get("active_tab")) == i)

func _test_world_tab(hud: Node) -> void:
    hud._set_tab(3)
    await process_frame
    var actions = hud.get("actions") as GridContainer
    check("WORLD tab remains selectable", int(hud.get("active_tab")) == 3 and actions != null)
    if actions == null:
        return
    var labels: Array[String] = []
    for child in actions.get_children():
        if child is Button:
            labels.append(String(child.text))
    check("WORLD tab has actionable controls", labels.size() > 0)
    if labels.size() == 0:
        warnings.append("WORLD tab contains no currently available actions")

func _test_gameplay_flow(_scene: Node, hud: Node) -> void:
    # Touch-only logical journey. We intentionally avoid key events.
    hud._set_tab(0)
    await process_frame
    var steps := ["INSPECT", "ACQUIRE", "RESTORE", "OPEN BUSINESS"]
    for label in steps:
        var button = _find_button(hud, label)
        check("touch action exists: %s" % label, button != null)
        if button != null:
            button.pressed.emit()
            await process_frame
    hud._set_tab(1)
    await process_frame
    for label in ["HIRE", "BUY INPUTS", "PRODUCE", "PRICE", "END DAY"]:
        var button = _find_button(hud, label)
        check("touch action exists: %s" % label, button != null)
        if button != null:
            button.pressed.emit()
            await process_frame
    var state = get_root().get_node_or_null("RenewGameState")
    check("authoritative GameState remains alive after touch flow", state != null)

func _find_button(hud: Node, label: String) -> Button:
    var actions = hud.get("actions") as GridContainer
    if actions == null:
        return null
    for child in actions.get_children():
        if child is Button and String(child.text) == label:
            return child
    return null

func _test_save_load() -> void:
    var state = get_root().get_node_or_null("RenewGameState")
    check("GameState autoload available for save/load", state != null)
    if state == null:
        return
    var SaveSystem = preload("res://scripts/save_system.gd")
    var started := Time.get_ticks_usec()
    var snapshot: Dictionary = state.capture()
    var capture_ms := float(Time.get_ticks_usec() - started) / 1000.0
    check("GameState capture completes", not snapshot.is_empty())
    check("capture is below 1s", capture_ms < SAVE_LIMIT_MS)
    started = Time.get_ticks_usec()
    var restored := state.restore(snapshot)
    var restore_ms := float(Time.get_ticks_usec() - started) / 1000.0
    check("GameState restore succeeds", restored)
    check("restore is below 1s", restore_ms < SAVE_LIMIT_MS)
    started = Time.get_ticks_usec()
    var saved := SaveSystem.save_game({"domains": snapshot.get("domains", {})})
    var disk_save_ms := float(Time.get_ticks_usec() - started) / 1000.0
    check("disk save succeeds", saved)
    check("disk save is below 1s", disk_save_ms < SAVE_LIMIT_MS)
    started = Time.get_ticks_usec()
    var loaded: Dictionary = SaveSystem.load_game()
    var disk_load_ms := float(Time.get_ticks_usec() - started) / 1000.0
    check("disk load returns valid state", not loaded.is_empty())
    check("disk load is below 1s", disk_load_ms < SAVE_LIMIT_MS)
    print("SAVE/LOAD timings: capture %.1fms, restore %.1fms, disk save %.1fms, disk load %.1fms" % [capture_ms, restore_ms, disk_save_ms, disk_load_ms])

func _test_runtime_stability() -> void:
    var start_memory := _memory_mb()
    var start_frames := Engine.get_process_frames()
    var start_time := Time.get_ticks_msec()
    while Time.get_ticks_msec() - start_time < 3000:
        await process_frame
    var elapsed := maxf(float(Time.get_ticks_msec() - start_time) / 1000.0, 0.001)
    var frames := Engine.get_process_frames() - start_frames
    var measured_fps := float(frames) / elapsed
    var end_memory := _memory_mb()
    print("RUNTIME: %.1f FPS, memory %.1fMB -> %.1fMB" % [measured_fps, start_memory, end_memory])
    if measured_fps > 0.0 and measured_fps < FPS_TARGET:
        fail("runtime FPS %.1f is below %0.0f FPS" % [measured_fps, FPS_TARGET])
    else:
        warnings.append("30 FPS low-end Android requirement is device-dependent; automated run measured %.1f FPS" % measured_fps)
    if start_memory >= 0.0 and end_memory >= 0.0 and end_memory - start_memory > MEMORY_GROWTH_LIMIT_MB:
        fail("memory grew %.1fMB during stability sample" % (end_memory - start_memory))
    else:
        warnings.append("memory stability is a short automated sample; repeat on a physical low-end Android device")

func _memory_mb() -> float:
    if not Performance.has_monitor(Performance.MEMORY_STATIC):
        return -1.0
    return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0

func check(label: String, condition: bool) -> void:
    checks += 1
    if condition:
        print("PASS: %s" % label)
    else:
        fail(label)

func fail(label: String) -> void:
    failures.append(label)
    print("FAIL: %s" % label)

func _finish() -> void:
    print("--- MOBILE QA SUMMARY ---")
    print("Checks: %d | Failures: %d | Warnings: %d" % [checks, failures.size(), warnings.size()])
    for warning in warnings:
        print("WARN: %s" % warning)
    if failures.size() > 0:
        for failure in failures:
            print("FAILED: %s" % failure)
        quit(1)
    else:
        print("AUTOMATED MOBILE QA: PASS")
        quit(0)
