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

func _press_empire_competition(hud: Node) -> bool:
    hud._set_tab(2)
    await process_frame
    await process_frame
    var found: Button = _buttons(hud).get("Competition")
    if found == null:
        return false
    found.pressed.emit()
    await process_frame
    var manager = get_root().get_node_or_null("RenewUIScreenManager")
    return manager != null and str(manager.get_active_screen_name()) == "CorporationsPanel"

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
    check(hud != null and hud.has_method("_set_tab"), "Authoritative direct-navigation action grid found")
    if hud == null:
        game.free()
        quit(1)
        return

    check(await _press_empire_competition(hud), "Competition workspace reachable through EMPIRE")
    var manager = get_root().get_node_or_null("RenewUIScreenManager")
    if manager != null:
        manager.hide_all_screens()
    var goals_msg := await _key(game, KEY_G)
    check(goals_msg.find("GOALS") >= 0, "GOALS remains reachable through explicit strategy shortcut")
    check(goals_msg.find("Tycoon") >= 0, "GOALS names victory paths")

    hud._set_tab(3)
    await process_frame
    check(not _buttons(hud).has("NEW COMPANY"), "Destructive NEW COMPANY action is not exposed in routine navigation")

    check(((await _key(game, KEY_F)).find("alliance")) >= 0, "KEY_F triggers COMPETE")
    check(((await _key(game, KEY_G)).find("GOALS")) >= 0, "KEY_G triggers GOALS")
    check(((await _key(game, KEY_D)).find("victorious")) >= 0, "KEY_D retains explicit NEW COMPANY shortcut")

    hud._set_tab(2)
    await process_frame
    await process_frame
    var competition: Button = _buttons(hud).get("Competition")
    check(competition != null and competition.custom_minimum_size.y >= 44.0, "Strategic workspace action meets touch sizing")
    check(hud.get("action_grid") != null, "Mobile action container present")
    game.free()
    await process_frame
    print("V51 UX PARITY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)