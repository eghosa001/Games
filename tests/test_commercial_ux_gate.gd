extends SceneTree
const VIEWPORTS := [Vector2i(320,568),Vector2i(390,844),Vector2i(480,800)]
var failures:Array[String]=[]
var checks:=0
func _initialize()->void: call_deferred("_run")
func check(label:String, ok:bool)->void:
    checks+=1
    if ok: print("PASS: "+label)
    else: failures.append(label); push_error("FAIL: "+label)
func _inside(c:Control,size:Vector2i)->bool:
    return c!=null and Rect2(Vector2.ZERO,Vector2(size)).encloses(c.get_global_rect())
func _run()->void:
    # Exercise explicit logical viewport sizes; project Android scaling is tested separately.
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.size=Vector2i(390,844)
    var p:=load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads",p!=null)
    if p==null: quit(1); return
    var game:=p.instantiate();root.add_child(game);current_scene=game
    await process_frame;await process_frame
    var hud:=game.get_node_or_null("UI/MainHUD")
    check("Main HUD exists",hud!=null)
    var expected:=["LIVE","OPERATE","EMPIRE","WORLD","MORE"]
    var tabs:Array=hud.get("mode_buttons")
    check("exactly five primary destinations",tabs.size()==5)
    for i in range(mini(5,tabs.size())):
        var b:=tabs[i] as Button
        var l:=b.get_node_or_null("NavLabel") as Label
        check("destination label "+expected[i],l!=null and l.text==expected[i])
        check("destination touch target "+expected[i],b.size.y>=48.0)
    for view in ["live","operate","empire","world","more"]:
        hud.open_figma_view(view);await process_frame
        check(view+" is directly reachable",str(hud.get("active_view"))==view)
    for target in VIEWPORTS:
        root.size=target;await process_frame;hud._layout_responsive();await process_frame
        if hud.get("bottom_nav")!=null:
            check("%s navigation contained" % target,_inside(hud.get("bottom_nav") as Control,target))
        if hud.get("mobile_scroll")!=null:
            check("%s content contained" % target,_inside(hud.get("mobile_scroll") as Control,target))
    root.size=Vector2i(390,844);hud.open_figma_view("more");await process_frame
    var content:=hud.get("mobile_content") as Control
    check("More exposes nine command tiles",content.find_children("MoreTile*","Panel",false,false).size()==9)
    check("legacy HOME label absent",not _tree_has_text(content,"HOME"))

    hud.open_figma_view("settings");await process_frame
    content=hud.get("mobile_content") as Control
    for control_name in ["MusicValue","SfxValue","PremiumView","RestoreButton","AutosaveState","Privacy","MotionToggleHit","RewardsToggleHit"]:
        var control:=content.find_child(control_name,true,false) as Control
        check(control_name+" has 48px touch height",control!=null and control.size.y>=48.0)
    var rewards:=content.find_child("RewardsToggleHit",true,false) as Button
    check("rewarded offers entry exists",rewards!=null)
    if rewards!=null: rewards.pressed.emit();await process_frame
    check("rewarded offers use a dedicated opt-in view",str(hud.get("active_view"))=="rewards")
    content=hud.get("mobile_content") as Control
    check("Sponsor Grant offer is explained",content.find_child("Reward_sponsor_grant",true,false)!=null)
    check("Market Research offer is explained",content.find_child("Reward_market_research",true,false)!=null)

    game.queue_free();await process_frame
    print("COMMERCIAL UX: %d checks, %d failures" % [checks,failures.size()])
    quit(1 if not failures.is_empty() else 0)
func _tree_has_text(node:Node,wanted:String)->bool:
    if node is Label and (node as Label).text==wanted:return true
    if node is Button and (node as Button).text==wanted:return true
    for child in node.get_children():
        if _tree_has_text(child,wanted):return true
    return false
