extends SceneTree

## V5.1: UX parity. GOALS, COMPETE and NEW COMPANY are reachable from the
## authoritative action grid, meet touch sizing, and answer keyboard shortcuts.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _buttons(hud: Node) -> Dictionary:
    var out := {}
    var grid: Node = hud.get("action_grid")
    if grid == null:
        return out
    for child in grid.get_children():
        if child is Button:
            out[str((child as Button).text)] = child
    return out

func _press(game: Node, hud: Node, label: String) -> String:
    hud._set_tab(2 if label != "NEW COMPANY" else 3)
    await process_frame
    await process_frame
    var found: Button = _buttons(hud).get(label)
    if found == null:
        return ""
    found.pressed.emit()
    await process_frame
    return str(game.command_system._state_value("company", "message", ""))

func _key(game: Node, code: Key) -> String:
    var ev := InputEventKey.new()
    ev.keycode = code
    ev.pressed = true
    game._input(ev)
    await process_frame
    return str(game.command_system._state_value("company", "message", ""))

func run() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for parity audit")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var hud: Node = game.get_node_or_null("UI/MainHUD")
    check(hud != null and hud.has_method("_set_tab"), "Authoritative action grid found")
    if hud == null:
        game.free()
        quit(1)
        return

    var compete_msg := await _press(game, hud, "COMPETE")
    check(not compete_msg.is_empty(), "COMPETE reachable from the grid")
    check(compete_msg.find("alliance") >= 0, "COMPETE reports alliance state")
    var goals_msg := await _press(game, hud, "GOALS")
    check(goals_msg.find("GOALS") >= 0, "GOALS reachable from the grid")
    check(goals_msg.find("Tycoon") >= 0, "GOALS names victory paths")
    var company_msg := await _press(game, hud, "NEW COMPANY")
    check(company_msg.find("victorious") >= 0, "NEW COMPANY reachable from the grid")

    check(((await _key(game, KEY_F)).find("alliance")) >= 0, "KEY_F triggers COMPETE")
    check(((await _key(game, KEY_G)).find("GOALS")) >= 0, "KEY_G triggers GOALS")
    check(((await _key(game, KEY_D)).find("victorious")) >= 0, "KEY_D triggers NEW COMPANY")

    hud._set_tab(2)
    await process_frame
    await process_frame
    var small := 0
    for label in ["COMPETE", "GOALS"]:
        var b: Button = _buttons(hud).get(label)
        if b != null and b.custom_minimum_size.y < 44.0:
            small += 1
    hud._set_tab(3)
    await process_frame
    await process_frame
    var nc: Button = _buttons(hud).get("NEW COMPANY")
    if nc != null and nc.custom_minimum_size.y < 44.0:
        small += 1
    check(small == 0, "New actions meet touch sizing")
    check(hud.get("mobile_actions") != null, "Mobile action container present")
    game.free()
    await process_frame
    print("V51 UX PARITY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
