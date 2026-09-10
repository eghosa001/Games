extends SceneTree

const PAGE_COUNTS: Array[int] = [4, 9, 10, 5]
const VIEWPORTS: Array[Vector2i] = [Vector2i(320, 480), Vector2i(360, 640), Vector2i(720, 1280), Vector2i(1024, 768)]
const BANNED_LABELS: Array[String] = [
    "PAST", "HAGGLE", "GOVT DEAL", "BUILD DEAL", "REPUTE",
    "RELATION", "PACT", "POWER", "TECH", "LIVE OPS"
]
const MAX_ACTIONS_PER_PAGE := 6
const MIN_TOUCH := 44.0

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    print("RENEW COMMERCIAL UX GATE")
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
    await _check_page_density_and_language(hud)
    await _check_responsive_touch_design(hud)
    await _check_key_action_reachability(hud)
    _finish()

func _check_primary_navigation(hud: Node) -> void:
    var tabs = hud.get("mode_buttons")
    _check(tabs is Array and tabs.size() == 4, "Exactly four primary simulation sectors")
    if not (tabs is Array) or tabs.size() != 4:
        return
    var expected := ["LIVE", "BUSINESS", "EMPIRE", "WORLD"]
    for i in range(4):
        var button := tabs[i] as Button
        _check(button != null, "Primary sector %d is a button" % i)
        if button != null:
            _check(button.text == expected[i], "Primary sector %d uses clear label %s" % [i, expected[i]])
            _check(button.custom_minimum_size.x >= MIN_TOUCH and button.custom_minimum_size.y >= MIN_TOUCH, "Primary sector %s has >=44px touch target" % expected[i])

func _check_page_density_and_language(hud: Node) -> void:
    for tab in range(PAGE_COUNTS.size()):
        hud._set_tab(tab)
        await process_frame
        for page in range(PAGE_COUNTS[tab]):
            hud._set_page(page)
            await process_frame
            var grid := hud.get("action_grid") as GridContainer
            _check(grid != null, "Tab %d page %d has command grid" % [tab, page])
            if grid == null:
                continue
            var buttons: Array[Button] = []
            for child in grid.get_children():
                if child is Button:
                    buttons.append(child as Button)
            _check(buttons.size() <= MAX_ACTIONS_PER_PAGE, "Tab %d page %d stays at <=%d visible commands" % [tab, page, MAX_ACTIONS_PER_PAGE])
            if page > 0:
                _check(_has_label(buttons, "BACK"), "Tab %d page %d offers predictable BACK navigation" % [tab, page])
            for button in buttons:
                _check(not BANNED_LABELS.has(button.text), "Command '%s' avoids legacy/ambiguous terminology" % button.text)
                _check(button.text.length() <= 22, "Command '%s' is concise" % button.text)
                _check(not button.tooltip_text.strip_edges().is_empty(), "Command '%s' explains itself with a tooltip" % button.text)

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
        _check(grid != null, "%dx%d keeps command grid available" % [target.x, target.y])
        if grid != null:
            for child in grid.get_children():
                if child is Button:
                    var button := child as Button
                    _check(button.size.x >= MIN_TOUCH and button.size.y >= MIN_TOUCH, "%dx%d command '%s' remains touch-friendly" % [target.x, target.y, button.text])
        var dock := hud.get("action_dock") as Control
        _check(_inside_viewport(dock, target), "%dx%d command dock stays inside viewport" % [target.x, target.y])

func _check_key_action_reachability(hud: Node) -> void:
    hud._set_tab(0)
    await process_frame
    _check_current_labels(hud, ["DASHBOARD", "PROPERTY", "OWNERSHIP", "END DAY"], "LIVE overview exposes core loop")

    hud._set_tab(1)
    await process_frame
    _check_current_labels(hud, ["PRODUCTION", "PEOPLE", "COMMERCIAL", "FINANCE"], "BUSINESS overview exposes management pillars")

    hud._set_tab(2)
    await process_frame
    _check_current_labels(hud, ["RIVALS", "ALLIANCES", "GROWTH", "CAPITAL", "TECHNOLOGY"], "EMPIRE overview exposes strategic pillars")

    hud._set_tab(3)
    await process_frame
    _check_current_labels(hud, ["REGIONAL MANAGEMENT", "OPERATIONS", "EMPIRE MANAGEMENT", "EVENTS"], "WORLD overview exposes world-management pillars")

func _check_current_labels(hud: Node, required: Array, description: String) -> void:
    var grid := hud.get("action_grid") as GridContainer
    if grid == null:
        _check(false, description)
        return
    var labels: Array[String] = []
    for child in grid.get_children():
        if child is Button:
            labels.append((child as Button).text)
    var ok := true
    for label in required:
        if not labels.has(str(label)):
            ok = false
    _check(ok, description)

func _has_label(buttons: Array[Button], label: String) -> bool:
    for button in buttons:
        if button.text == label:
            return true
    return false

func _inside_viewport(control: Control, target: Vector2i) -> bool:
    if control == null:
        return false
    var rect := Rect2(control.position, control.size)
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
