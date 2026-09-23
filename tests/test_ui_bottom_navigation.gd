extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS: "+label)
    else:failed += 1;push_error("FAIL: "+label)
func _run()->void:
    root.size=Vector2i(390,844)
    var p:=load("res://scenes/Main.tscn") as PackedScene
    var game:=p.instantiate();root.add_child(game);current_scene=game
    await process_frame;await process_frame
    var hud:=game.get_node("UI/MainHUD")
    var nav:=hud.get("bottom_nav") as Control
    check(nav!=null,"bottom navigation exists")
    check(nav.position==Vector2(12,758),"bottom navigation matches Figma position")
    check(nav.size==Vector2(366,70),"bottom navigation matches Figma size")
    var buttons:Array=hud.get("mode_buttons")
    var expected:=["LIVE","OPERATE","EMPIRE","WORLD","MORE"]
    check(buttons.size()==5,"five navigation items")
    for i in range(5):
        var b:=buttons[i] as Button
        var l:=b.get_node("NavLabel") as Label
        check(l.text==expected[i],"nav label "+expected[i])
        check(b.size.y>=48.0,"48px touch target "+expected[i])\n        check(b.focus_mode==Control.FOCUS_ALL,"keyboard focus "+expected[i])
        b.pressed.emit();await process_frame
        check(int(hud.get("active_tab"))==i,"touch switches "+expected[i])
    game.queue_free();await process_frame
    print("BOTTOM NAV: %d passed, %d failed" % [passed,failed])
    quit(1 if failed > 0 else 0)
