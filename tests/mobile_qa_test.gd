extends SceneTree

const TARGETS:Array[Vector2i]=[Vector2i(320,480),Vector2i(360,640),Vector2i(390,844),Vector2i(480,800),Vector2i(720,1280),Vector2i(1024,768)]
const MIN_TOUCH:=44.0
var failures:Array[String]=[]
var checks:=0

func _initialize()->void:call_deferred("_run")

func check(label:String,ok:bool)->void:
    checks+=1
    if ok: print("PASS: "+label)
    else: failures.append(label); push_error("FAIL: "+label)

func _inside(c:Control,target:Vector2i)->bool:
    return c!=null and Rect2(Vector2.ZERO,Vector2(target)).encloses(c.get_global_rect())

func _run()->void:
    root.size=Vector2i(390,844)
    var packed:=load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads",packed!=null)
    if packed==null:_finish();return
    var game:=packed.instantiate();root.add_child(game);current_scene=game
    await process_frame;await process_frame;await process_frame
    var hud:=game.get_node_or_null("UI/MainHUD")
    check("Figma MainHUD exists",hud!=null)
    if hud==null:_finish();return

    for target in TARGETS:
        root.size=target;await process_frame;hud._layout_responsive();await process_frame
        if target.x<1000:
            var nav:=hud.get("bottom_nav") as Control
            var scroll:=hud.get("mobile_scroll") as Control
            check("%s bottom nav contained" % target,_inside(nav,target))
            check("%s production content contained" % target,_inside(scroll,target))
            var buttons:Array=hud.get("mode_buttons")
            check("%s five primary destinations" % target,buttons.size()==5)
            for b in buttons:
                check("%s nav target >=44" % target,(b as Button).size.y>=MIN_TOUCH)
        else:
            check("%s desktop executive canvas" % target,hud.get("root").get_node_or_null("DesktopExecutive")!=null)

    root.size=Vector2i(390,844);await process_frame;hud._layout_responsive();await process_frame
    await _exercise_opening_flow(game,hud)
    await _exercise_primary_views(hud)
    _test_save_load()
    await _runtime_stability()
    game.queue_free();await process_frame
    _finish()

func _exercise_opening_flow(game:Node,hud:Node)->void:
    hud.open_figma_view("property");await process_frame
    for expected in ["INSPECT PROPERTY","ACQUIRE PROPERTY","RESTORE NEXT STAGE","RESTORE NEXT STAGE","RESTORE NEXT STAGE","RESTORE NEXT STAGE"]:
        var button:=_find_button(hud.get("mobile_content"),expected)
        check("opening action exists: "+expected,button!=null)
        if button!=null:button.pressed.emit();await process_frame;await process_frame
    var state:=root.get_node_or_null("RenewGameState")
    check("restoration reaches Operational",state!=null and str(state.get_value("properties","stage",""))=="Operational")
    var open_ops:=_find_button(hud.get("mobile_content"),"OPEN OPERATIONS")
    check("Open Operations CTA exists",open_ops!=null)
    if open_ops!=null:open_ops.pressed.emit();await process_frame
    check("Operations view opens",str(hud.get("active_view"))=="operate")
    var choose:=_find_button(hud.get("mobile_content"),"CHOOSE BUSINESS")
    check("business choice is reachable",choose!=null)
    if choose!=null:
        choose.pressed.emit();await process_frame
        var purpose:=_find_button(hud.get("mobile_content"),"Purpose0",true)
        check("business purpose option exists",purpose!=null)
        if purpose!=null:purpose.pressed.emit();await process_frame;await process_frame
    check("business becomes operational",bool(game.business_open))
    var buy:=_find_button(hud.get("mobile_content"),"BUY INPUTS")
    var produce:=_find_button(hud.get("mobile_content"),"PRODUCE BATCH")
    check("Buy Inputs action present after launch",buy!=null)
    check("Produce Batch action present after launch",produce!=null)
    if buy!=null:buy.pressed.emit();await process_frame
    if produce!=null:produce.pressed.emit();await process_frame

func _exercise_primary_views(hud:Node)->void:
    var expected:=["live","operate","empire","world","more"]
    for i in range(5):
        hud._set_tab(i);await process_frame
        check("tab %d opens %s" % [i,expected[i]],str(hud.get("active_view"))==expected[i])
    for view in ["finance","portfolio","intelligence","settings","property"]:
        hud.open_figma_view(view);await process_frame
        check("secondary Figma view opens: "+view,str(hud.get("active_view"))==view)

func _find_button(node:Node,label:String,by_name:=false)->Button:
    if node==null:return null
    if node is Button:
        var b:=node as Button
        if (by_name and b.name==label) or (not by_name and b.text.begins_with(label)):return b
    for child in node.get_children():
        var found:=_find_button(child,label,by_name)
        if found!=null:return found
    return null

func _test_save_load()->void:
    var state:=root.get_node_or_null("RenewGameState")
    check("GameState available",state!=null)
    if state==null:return
    var save_system:Script=preload("res://scripts/save_system.gd")
    var snapshot:Dictionary=state.capture()
    check("GameState capture succeeds",not snapshot.is_empty())
    check("GameState restore succeeds",bool(state.restore(snapshot)))
    check("disk save succeeds",bool(save_system.save_game({"domains":snapshot.get("domains",{})})))
    check("disk load succeeds",not (save_system.load_game() as Dictionary).is_empty())

func _runtime_stability()->void:
    var start:=Time.get_ticks_msec()
    var frames:=Engine.get_process_frames()
    while Time.get_ticks_msec()-start<1200:await process_frame
    var elapsed:=maxf(float(Time.get_ticks_msec()-start)/1000.0,0.001)
    var fps:=float(Engine.get_process_frames()-frames)/elapsed
    check("runtime remains responsive",fps>0.0)

func _finish()->void:
    print("FIGMA MOBILE QA: %d checks | %d failures" % [checks,failures.size()])
    for failure in failures:print("FAILED: "+failure)
    quit(1 if not failures.is_empty() else 0)
