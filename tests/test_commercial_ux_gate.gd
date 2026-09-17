extends SceneTree

const VIEWPORTS: Array[Vector2i] = [Vector2i(320, 480), Vector2i(360, 640), Vector2i(720, 1280), Vector2i(1024, 768)]
const BANNED_PRIMARY_LABELS: Array[String] = ["END DAY", "PAST", "HAGGLE", "GOVT DEAL", "BUILD DEAL", "REPUTE", "RELATION", "PACT", "POWER", "TECH", "LIVE OPS"]
const MAX_VISIBLE_ACTIONS := 10
const MIN_TOUCH := 44.0

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    print("RESTORA COMMERCIAL UX GATE")
    var packed := load("res://scenes/Main.tscn") as PackedScene
    _check(packed != null, "Main scene loads")
    if packed == null:
        _finish()
        return

    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var hud := game.get_node_or_null("UI/MainHUD")
    _check(hud != null, "Main HUD exists")
    if hud == null:
        _finish()
        return

    await _check_primary_navigation(hud)
    await _check_direct_action_density(hud)
    await _check_responsive_touch_design(hud)
    await _check_workspace_reachability(hud)
    game.queue_free()
    await process_frame
    _finish()

func _check_primary_navigation(hud: Node) -> void:
    var tabs = hud.get("mode_buttons")
    _check(tabs is Array and tabs.size() == 4, "Exactly four primary simulation sectors")
    if not (tabs is Array) or tabs.size() != 4:
        return
    var expected := ["HOME", "BUSINESS", "EMPIRE", "WORLD"]
    for i in range(4):
        var button := tabs[i] as Button
        _check(button != null, "Primary sector %d is a button" % i)
        if button != null:
            _check(button.text == expected[i], "Primary sector %d uses clear label %s" % [i, expected[i]])
            _check(button.custom_minimum_size.y >= MIN_TOUCH, "Primary sector %s has >=44px touch height" % expected[i])

func _buttons(hud: Node) -> Array[Button]:
    var result: Array[Button] = []
    var grid := hud.get("action_grid") as GridContainer
    if grid == null:
        return result
    for child in grid.get_children():
        if child is Button and child.visible:
            result.append(child as Button)
    return result

func _primary_line(button: Button) -> String:
    return button.text.split("\n")[0].strip_edges()

func _check_direct_action_density(hud: Node) -> void:
    for tab in range(4):
        hud._set_tab(tab)
        await process_frame
        await process_frame
        var buttons := _buttons(hud)
        _check(not buttons.is_empty(), "Tab %d exposes direct actions" % tab)
        _check(buttons.size() <= MAX_VISIBLE_ACTIONS, "Tab %d keeps visible decisions focused" % tab)
        for button in buttons:
            var label := _primary_line(button)
            _check(not BANNED_PRIMARY_LABELS.has(label.to_upper()), "Action '%s' avoids obsolete terminology" % label)
            _check(label.length() <= 24, "Action '%s' has a concise primary label" % label)
            _check(button.custom_minimum_size.y >= MIN_TOUCH, "Action '%s' remains touch-sized" % label)

func _check_responsive_touch_design(hud: Node) -> void:
    var ui_root := hud.get("root") as Control
    _check(ui_root != null, "Responsive HUD root exists")
    if ui_root == null:
        return
    for target in VIEWPORTS:
        ui_root.size = Vector2(target)
        hud._layout_responsive()
        await process_frame
        var grid := hud.get("action_grid") as GridContainer
        _check(grid != null and grid.columns == 2, "%dx%d keeps the compact two-column action grid" % [target.x, target.y])
        for button in _buttons(hud):
            _check(button.size.x >= MIN_TOUCH and button.size.y >= MIN_TOUCH, "%dx%d action '%s' remains touch-friendly" % [target.x, target.y, _primary_line(button)])
        var dock := hud.get("action_dock") as Control
        _check(_inside_viewport(dock, target), "%dx%d command dock stays inside viewport" % [target.x, target.y])

func _check_workspace_reachability(hud: Node) -> void:
    var required := {
        0: ["Company overview", "Properties", "Save & settings"],
        1: ["Operations", "People & demand", "Market & customers", "Finance & contracts"],
        2: ["Portfolio & projects", "Expansion", "Competition"],
        3: ["Regions", "Supply network", "Opportunities", "Intelligence"],
    }
    for tab in required.keys():
        hud._set_tab(int(tab))
        await process_frame
        await process_frame
        var labels: Array[String] = []
        for button in _buttons(hud):
            labels.append(_primary_line(button))
        var ok := true
        for label in required[tab]:
            if not labels.has(str(label)):
                ok = false
        _check(ok, "Tab %d exposes its core workspaces" % int(tab))

func _inside_viewport(control: Control, target: Vector2i) -> bool:
    if control == null:
        return false
    var rect := control.get_global_rect()
    return Rect2(Vector2.ZERO, Vector2(target)).encloses(rect)

func _check(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("PASS: %s" % label)
    else:
        failures.append(label)
        push_error("FAIL: %s" % label)

func _finish() -> void:
    print("--- COMMERCIAL UX SUMMARY ---")
    print("Checks: %d | Failures: %d" % [checks, failures.size()])
    for failure in failures:
        print("FAILED: %s" % failure)
    quit(1 if not failures.is_empty() else 0)
