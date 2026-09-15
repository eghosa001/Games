extends SceneTree

## UX parity now means every strategic pillar is reachable through the authored
## four-sector shell without exposing destructive/debug commands in routine play.
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
    var grid := hud.get("action_grid") as GridContainer
    if grid == null: return out
    for child in grid.get_children():
        if child is Button:
            var b := child as Button
            out[b.text.split("\n")[0].strip_edges()] = b
    return out

func _key(game: Node, code: Key) -> String:
    var ev := InputEventKey.new(); ev.keycode = code; ev.pressed = true
    game._input(ev)
    await process_frame
    return str(game.command_system._state_value("company", "message", ""))

func run() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for parity audit")
    if scene == null: quit(1); return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var hud: Node = game.get_node_or_null("UI/MainHUD")
    check(hud != null and hud.has_method("_set_tab"), "Authoritative focused action shell found")
    if hud == null: game.free(); quit(1); return

    hud._set_tab(2)
    await process_frame
    var empire := _buttons(hud)
    check(empire.has("Portfolio & projects"), "EMPIRE exposes portfolio strategy")
    check(empire.has("Expansion"), "EMPIRE exposes expansion strategy")
    check(empire.has("Competition"), "EMPIRE exposes competitive strategy")
    check(not empire.has("NEW COMPANY"), "Destructive NEW COMPANY action is not exposed in routine navigation")

    var manager := root.get_node_or_null("RenewUIScreenManager")
    if empire.has("Competition"):
        (empire["Competition"] as Button).pressed.emit()
        await process_frame
        check(manager != null and manager.get_active_screen_name() == "CorporationsPanel", "Competition opens focused corporations workspace")
        if manager != null: manager.hide_all_screens()

    hud._set_tab(3)
    await process_frame
    var world := _buttons(hud)
    for label in ["Regions", "Supply network", "Opportunities", "Intelligence"]:
        check(world.has(label), "WORLD exposes %s" % label)

    check(((await _key(game, KEY_F)).find("alliance")) >= 0, "KEY_F retains explicit compete shortcut")
    check(((await _key(game, KEY_G)).find("GOALS")) >= 0, "KEY_G retains explicit goals shortcut")
    check(((await _key(game, KEY_D)).find("victorious")) >= 0, "KEY_D retains explicit new-company shortcut")

    hud._set_tab(2)
    await process_frame
    var small := 0
    for b in _buttons(hud).values():
        if b is Button and ((b as Button).custom_minimum_size.y < 48.0 or (b as Button).focus_mode != Control.FOCUS_ALL): small += 1
    check(small == 0, "Strategic actions meet premium touch and focus sizing")

    game.free()
    await process_frame
    print("FOCUSED UX PARITY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)