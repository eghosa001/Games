extends SceneTree

const TARGETS:Array[Vector2i]=[Vector2i(320,480),Vector2i(360,640),Vector2i(390,844),Vector2i(480,800),Vector2i(720,1280),Vector2i(1024,768)]
const MIN_TOUCH:=48.0
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
    # Exercise explicit logical viewport sizes; project Android scaling is tested separately.
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
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
        var layout_kind:=str(hud.get("_layout_kind"))
        if layout_kind=="mobile":
            var nav:=hud.get("bottom_nav") as Control
            var scroll:=hud.get("mobile_scroll") as Control
            check("%s bottom nav contained" % target,_inside(nav,target))
            check("%s production content contained" % target,_inside(scroll,target))
            var buttons:Array=hud.get("mode_buttons")
            check("%s five primary destinations" % target,buttons.size()==5)
            for b in buttons:
                check("%s nav target >=48" % target,(b as Button).size.y>=MIN_TOUCH)
        elif layout_kind=="tablet":
            check("%s tablet executive canvas" % target,hud.get("root").get_node_or_null("TabletLive")!=null)
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

    var inspect:=_find_button(hud.get("mobile_content"),"INSPECT PROPERTY")
    check("opening action exists: INSPECT PROPERTY",inspect!=null)
    if inspect!=null:
        inspect.pressed.emit();await process_frame;await process_frame

    var acquire:=_find_button(hud.get("mobile_content"),"ACQUIRE PROPERTY")
    check("opening action exists: ACQUIRE PROPERTY",acquire!=null)
    if acquire!=null:
        acquire.pressed.emit();await process_frame;await process_frame

    # New restoration is one priced confirmation per stage, not the old
    # compulsory Plan -> Review -> Confirm chain.
    for stage_index in range(4):
        hud.open_figma_view("property");await process_frame
        var restore_entry:=_find_button(hud.get("mobile_content"),"RESTORE NEXT STAGE")
        check("restoration stage %d has a direct action" % (stage_index+1),restore_entry!=null)
        if restore_entry==null:break
        restore_entry.pressed.emit();await process_frame;await process_frame
        check("restoration stage %d opens the cost confirmation" % (stage_index+1),str(hud.get("active_view"))=="restoration_confirm")
        var confirm:=_find_button(hud.get("mobile_content"),"CONFIRM WORK")
        check("restoration stage %d confirm action exists" % (stage_index+1),confirm!=null)
        if confirm==null:break
        confirm.pressed.emit();await process_frame;await process_frame

    var state:=root.get_node_or_null("RenewGameState")
    check("restoration reaches Operational",state!=null and str(state.get_value("properties","stage",""))=="Operational")
    check("restoration completion is visible",str(hud.get("active_view"))=="restoration_complete")
    var start_business:=_find_button(hud.get("mobile_content"),"START BUSINESS")
    check("Start Business CTA exists",start_business!=null)
    if start_business!=null:start_business.pressed.emit();await process_frame
    check("Operations view opens",str(hud.get("active_view"))=="operate")

    var choose:=_find_button(hud.get("mobile_content"),"OPEN YOUR BUSINESS")
    check("Easy Play can launch the business",choose!=null)
    if choose!=null:
        choose.pressed.emit();await process_frame
        var purpose:=_find_button(hud.get("mobile_content"),"Purpose0",true)
        check("business purpose option exists",purpose!=null)
        if purpose!=null:purpose.pressed.emit();await process_frame;await process_frame
    check("business becomes operational",bool(game.business_open))

    var quick:=_find_button(hud.get("mobile_content"),"EasyPlayAction",true)
    check("Business has a visible one-tap production action",quick!=null and not quick.disabled)
    if quick!=null:
        quick.pressed.emit();await process_frame;await process_frame
        if int(state.get_value("production","finished_goods",0))==0:
            quick=_find_button(hud.get("mobile_content"),"EasyPlayAction",true)
            if quick!=null:quick.pressed.emit();await process_frame;await process_frame
    check("guided action produces actual inventory",state!=null and int(state.get_value("production","finished_goods",0))>0)
    quick=_find_button(hud.get("mobile_content"),"EasyPlayAction",true)
    check("ready inventory exposes direct selling",quick!=null and quick.text=="SELL YOUR GOODS")
    if quick!=null:quick.pressed.emit();await process_frame;await process_frame
    check("one-tap selling earns real sales",state!=null and int(state.get_value("economy","last_sales",0))>0)

func _exercise_primary_views(hud:Node)->void:
    var expected:=["live","operate","property","finance","more"]
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
# Focused validation: RESTORA mobile overlap, touch scroll and navigation hierarchy.
# Focused rerun: typed mobile UX layout fix.
