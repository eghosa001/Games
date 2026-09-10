extends SceneTree

## V5.1: UX parity. Strategic actions remain reachable through the focused
## hierarchy, while the destructive NEW COMPANY action stays off the routine
## command grid and remains available through its explicit shortcut.
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

func _press_empire_rival_action(game: Node, hud: Node, label: String) -> String:
    hud._set_tab(2)
    hud._set_page(1)
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
    current_scene = game
    await process_frame
    await process_frame
    var hud: Node = game.get_node_or_null("UI/MainHUD")
    check(hud != null and hud.has_method("_set_tab") and hud.has_method("_set_page"), "Authoritative hierarchical action grid found")
    if hud == null:
        game.free()
        quit(1)
        return

    var compete_msg := await _press_empire_rival_action(game, hud, "COMPETE")
    check(not compete_msg.is_empty(), "COMPETE reachable through EMPIRE > RIVALS")
    check(compete_msg.find("alliance") >= 0, "COMPETE reports alliance state")
    var goals_msg := await _press_empire_rival_action(game, hud, "GOALS")
    check(goals_msg.find("GOALS") >= 0, "GOALS reachable through EMPIRE > RIVALS")
    check(goals_msg.find("Tycoon") >= 0, "GOALS names victory paths")

    hud._set_tab(3)
    await process_frame
    check(not _buttons(hud).has("NEW COMPANY"), "Destructive NEW COMPANY action is not exposed in routine navigation")

    check(((await _key(game, KEY_F)).find("alliance")) >= 0, "KEY_F triggers COMPETE")
    check(((await _key(game, KEY_G)).find("GOALS")) >= 0, "KEY_G triggers GOALS")
    check(((await _key(game, KEY_D)).find("victorious")) >= 0, "KEY_D retains explicit NEW COMPANY shortcut")

    hud._set_tab(2)
    hud._set_page(1)
    await process_frame
    await process_frame
    var small := 0
    for label in ["COMPETE", "GOALS"]:
        var b: Button = _buttons(hud).get(label)
        if b == null or b.custom_minimum_size.y < 44.0:
            small += 1
    check(small == 0, "Strategic actions meet touch sizing")
    check(hud.get("mobile_actions") != null, "Mobile action container present")
    game.free()
    await process_frame
    print("V51 UX PARITY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)