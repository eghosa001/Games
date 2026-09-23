extends SceneTree
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS: "+label)
    else:failed += 1;push_error("FAIL: "+label)
func run()->void:
    root.size=Vector2i(390,844)
    var scene:=load("res://scenes/Main.tscn") as PackedScene
    check(scene!=null,"Main scene loads")
    if scene==null:quit(1);return
    var game:=scene.instantiate();root.add_child(game);current_scene=game
    await process_frame;await process_frame
    var manager:=root.get_node_or_null("RenewUIScreenManager")
    check(manager!=null,"screen manager available")
    var names:=["FinancePanel","PortfolioPanel","CorporationsPanel","AlliancePanel","ContractPanel","NewsPanel","HistoryPanel"]
    for n in names:
        manager.show_screen(n);await process_frame
        check(manager.get_active_screen_name()==n,n+" takes focus")
    manager.show_screen("NoSuchScreen");await process_frame
    check(manager.get_active_screen_name()=="HistoryPanel","unknown screen ignored")
    var esc:=InputEventKey.new();esc.keycode=KEY_ESCAPE;esc.pressed=true;manager._unhandled_input(esc);await process_frame
    check(manager.get_active_screen_name()=="","ESC clears focused screen")
    var hud:=game.get_node("UI/MainHUD")
    var stable:=true
    for view in ["live","operate","empire","world","more","live"]:
        hud.open_figma_view(view);await process_frame
        if str(hud.get("active_view"))!=view:stable=false
    check(stable,"Figma view rebuilds stay stable")
    var buttons:Array=hud.get("mode_buttons")
    var wired:=buttons.size()==5
    for b in buttons:
        if (b as Button).pressed.get_connections().is_empty():wired=false
    check(wired,"five rebuilt navigation buttons remain wired")
    game.queue_free();await process_frame
    print("V97 MODAL FOCUS: %d passed, %d failed" % [passed,failed])
    quit(1 if failed > 0 else 0)
