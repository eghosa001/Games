extends SceneTree
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if ok: passed += 1; print("PASS: " + label)
    else: failed += 1; push_error("FAIL: " + label)
func run() -> void:
    root.size = Vector2i(390,844)
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene parses")
    if packed == null: quit(1); return
    var game := packed.instantiate(); root.add_child(game); current_scene=game
    await process_frame; await process_frame
    var hud := game.get_node_or_null("UI/MainHUD")
    check(hud != null, "Figma production HUD exists")
    var expected := ["LIVE","OPERATE","EMPIRE","WORLD","MORE"]
    var buttons: Array = hud.get("mode_buttons") if hud != null else []
    check(buttons.size()==5, "five primary Figma destinations")
    for i in range(mini(buttons.size(),5)):
        var label := (buttons[i] as Button).get_node_or_null("NavLabel") as Label
        check(label != null and label.text==expected[i], "destination %d is %s" % [i,expected[i]])
    var manager := root.get_node_or_null("RenewUIScreenManager")
    check(manager != null, "screen manager exists")
    for view in ["live","operate","empire","world","more","finance","portfolio","intelligence","settings","property"]:
        hud.open_figma_view(view); await process_frame
        check(str(hud.get("active_view"))==view, "Figma view opens: "+view)
    if manager != null:
        for screen in ["CorporationsPanel","ContractPanel","TechnologyPanel","HeadquartersPanel","HistoryPanel","SaveLoadPanel"]:
            manager.show_screen(screen); await process_frame
            check(manager.get_active_screen_name()==screen, "deep workspace opens: "+screen)
            manager.hide_all_screens()
    game.queue_free(); await process_frame
    print("COMMAND DECK UI TEST: %d passed, %d failed" % [passed,failed])
    quit(1 if failed > 0 else 0)
