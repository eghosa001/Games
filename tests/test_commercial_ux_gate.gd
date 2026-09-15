extends SceneTree

const VIEWPORTS: Array[Vector2i] = [Vector2i(320, 568), Vector2i(390, 844), Vector2i(720, 1280), Vector2i(1024, 768)]
const BANNED_LABELS: Array[String] = [
    "PAST", "HAGGLE", "GOVT DEAL", "BUILD DEAL", "REPUTE",
    "RELATION", "PACT", "POWER", "TECH", "LIVE OPS", "END DAY"
]
const MAX_ACTIONS_PER_SECTOR := 8
const MIN_TOUCH := 48.0

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
    await _check_sector_density_and_language(hud)
    await _check_responsive_touch_design(hud)
    await _check_key_action_reachability(hud)
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
            _check(button.text == expected[i], "Primary sector %d uses authored label %s" % [i, expected[i]])
            _check(button.custom_minimum_size.y >= MIN_TOUCH, "Primary sector %s has >=48px touch target" % expected[i])
            _check(button.focus_mode == Control.FOCUS_ALL, "Primary sector %s supports keyboard/gamepad focus" % expected[i])

func _check_sector_density_and_language(hud: Node) -> void:
    for tab in range(4):
        hud._set_tab(tab)
        await process_frame
        var grid := hud.get("action_grid") as GridContainer
        _check(grid != null, "Sector %d has command grid" % tab)
        if grid == null:
            continue
        var buttons := _buttons(grid)
        _check(buttons.size() <= MAX_ACTIONS_PER_SECTOR, "Sector %d avoids command-wall density" % tab)
        for button in buttons:
            var label := _primary_label(button)
            _check(not BANNED_LABELS.has(label.to_upper()), "Command '%s' avoids legacy/developer terminology" % label)
            _check(label.length() <= 28, "Command '%s' stays concise" % label)
            _check(not button.tooltip_text.strip_edges().is_empty(), "Command '%s' explains itself with a tooltip" % label)
            _check(button.focus_mode == Control.FOCUS_ALL, "Command '%s' is focus-navigable" % label)
            _check(button.custom_minimum_size.y >= MIN_TOUCH, "Command '%s' has a premium touch target" % label)

func _check_responsive_touch_design(hud: Node) -> void:
    var ui_root := hud.get("root") as Control
    var action_scroll := hud.get("action_scroll") as Control
    _check(ui_root != null, "Responsive HUD root exists")
    _check(action_scroll != null, "Scrollable action viewport exists")
    if ui_root == null:
        return
    for target in VIEWPORTS:
        ui_root.size = Vector2(target)
        hud._layout_responsive()
        await process_frame
        var grid := hud.get("action_grid") as GridContainer
        _check(grid != null, "%dx%d keeps command grid available" % [target.x, target.y])
        if grid != null:
            _check(grid.columns == (1 if target.x < 420 else 2), "%dx%d uses readable action columns" % [target.x, target.y])
            for button in _buttons(grid):
                _check(button.size.y >= MIN_TOUCH, "%dx%d command '%s' remains touch-friendly" % [target.x, target.y, _primary_label(button)])
        if action_scroll != null:
            _check(_inside_viewport(action_scroll, target), "%dx%d action viewport stays inside the screen" % [target.x, target.y])

func _check_key_action_reachability(hud: Node) -> void:
    hud._set_tab(0)
    await process_frame
    _check_current_labels(hud, ["Company overview", "Properties", "Save & settings"], "HOME exposes core company loop")

    hud._set_tab(1)
    await process_frame
    _check_current_any(hud, ["Operations", "Choose the company"], "BUSINESS exposes an operating or launch path")

    hud._set_tab(2)
    await process_frame
    _check_current_labels(hud, ["Portfolio & projects", "Expansion", "Competition"], "EMPIRE exposes strategic pillars")

    hud._set_tab(3)
    await process_frame
    _check_current_labels(hud, ["Regions", "Supply network", "Opportunities", "Intelligence"], "WORLD exposes world-management pillars")

func _buttons(grid: GridContainer) -> Array[Button]:
    var out: Array[Button] = []
    for child in grid.get_children():
        if child is Button:
            out.append(child as Button)
    return out

func _primary_label(button: Button) -> String:
    return button.text.split("\n")[0].strip_edges()

func _current_labels(hud: Node) -> Array[String]:
    var labels: Array[String] = []
    var grid := hud.get("action_grid") as GridContainer
    if grid == null:
        return labels
    for button in _buttons(grid):
        labels.append(_primary_label(button))
    return labels

func _check_current_labels(hud: Node, required: Array, description: String) -> void:
    var labels := _current_labels(hud)
    var ok := true
    for label in required:
        if not labels.has(str(label)):
            ok = false
    _check(ok, description)

func _check_current_any(hud: Node, required: Array, description: String) -> void:
    var labels := _current_labels(hud)
    var ok := false
    for label in required:
        if labels.has(str(label)):
            ok = true
    _check(ok, description)

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
        print("FAIL: %s" % label)

func _finish() -> void:
    print("--- COMMERCIAL UX SUMMARY ---")
    print("Checks: %d | Failures: %d" % [checks, failures.size()])
    for failure in failures:
        print("FAILED: %s" % failure)
    quit(1 if not failures.is_empty() else 0)