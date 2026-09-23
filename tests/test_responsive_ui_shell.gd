extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("_run")
func check(label:String,ok:bool)->void:
    checks+=1
    if ok:print("PASS: "+label)
    else:failures.append(label);push_error("FAIL: "+label)
func _inside(c:Control,size:Vector2)->bool:
    return c!=null and Rect2(Vector2.ZERO,size).encloses(c.get_global_rect())
func _run()->void:
    var packed:=load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads",packed!=null)
    if packed==null:quit(1);return
    root.size=Vector2i(390,844)
    var game:=packed.instantiate();root.add_child(game);current_scene=game
    await process_frame;await process_frame
    var hud:=game.get_node_or_null("UI/MainHUD")
    check("MainHUD resolves",hud!=null)
    for target in [Vector2i(320,568),Vector2i(390,844),Vector2i(480,800)]:
        root.size=target;await process_frame;hud._layout_responsive();await process_frame
        var scroll:=hud.get("mobile_scroll") as Control
        var nav:=hud.get("bottom_nav") as Control
        check("%s mobile scroll contained" % target,_inside(scroll,Vector2(target)))
        check("%s mobile nav contained" % target,_inside(nav,Vector2(target)))
        var buttons:Array=hud.get("mode_buttons")
        check("%s five tabs" % target,buttons.size()==5)
        for b in buttons:
            check("%s tab touch >=44" % target,(b as Button).size.y>=44.0)
    root.size=Vector2i(1280,720);await process_frame;hud._layout_responsive();await process_frame
    check("desktop uses executive Figma canvas",hud.get("root").get_node_or_null("DesktopExecutive")!=null)
    check("desktop has no legacy action dock",hud.get("root").find_child("ActionDock",true,false)==null)
    var manager:=root.get_node_or_null("RenewUIScreenManager")
    check("screen manager resolves",manager!=null)
    if manager!=null:
        for screen in ["CorporationsPanel","ContractPanel","TechnologyPanel","HeadquartersPanel","HistoryPanel","SaveLoadPanel"]:
            manager.show_screen(screen);await process_frame
            check("opens deep screen "+screen,manager.get_active_screen_name()==screen)
            manager.hide_all_screens();await process_frame
    game.queue_free();await process_frame
    print("RESPONSIVE FIGMA SHELL: %d checks, %d failures" % [checks,failures.size()])
    quit(1 if not failures.is_empty() else 0)
