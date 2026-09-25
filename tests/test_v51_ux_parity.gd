extends SceneTree
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS: "+label)
    else:failed += 1;push_error("FAIL: "+label)
func _key(game:Node,code:Key)->String:
    var ev:=InputEventKey.new();ev.keycode=code;ev.pressed=true;game._input(ev);await process_frame
    return str(game.command_system._state_value("company","message",""))
func run()->void:
    root.size=Vector2i(390,844)
    var scene:=load("res://scenes/Main.tscn") as PackedScene
    check(scene!=null,"Main scene loads")
    if scene==null:quit(1);return
    var game:=scene.instantiate();root.add_child(game);current_scene=game
    await process_frame;await process_frame
    var hud:=game.get_node("UI/MainHUD")
    hud.open_figma_view("more");await process_frame
    var content:=hud.get("mobile_content") as Control
    var hit:=content.find_child("OpenCorporationsPanel",true,false) as Button
    check(hit!=null,"Corporations command is present in MORE")
    var corp:=hit.get_parent() as Control if hit!=null else null
    check(hit!=null and hit.size.y>=44.0,"Corporations command is touch reachable")
    if hit!=null:hit.pressed.emit();await process_frame
    var manager:=root.get_node_or_null("RenewUIScreenManager")
    check(manager!=null and manager.get_active_screen_name()=="CorporationsPanel","Corporations opens from MORE")
    if manager!=null:manager.hide_all_screens()
    var goals:=await _key(game,KEY_G)
    check(goals.find("GOALS")>=0,"GOALS explicit shortcut remains")
    check(goals.find("Tycoon")>=0,"GOALS names victory paths")
    check(((await _key(game,KEY_F)).find("alliance"))>=0,"KEY_F triggers alliance competition")
    check(((await _key(game,KEY_D)).find("victorious"))>=0,"KEY_D retains explicit new dynasty guard")
    hud.open_figma_view("more");await process_frame
    check(not _has_text(hud.get("mobile_content"),"NEW COMPANY"),"destructive NEW COMPANY absent from routine commands")
    game.queue_free();await process_frame
    print("V51 UX PARITY: %d passed, %d failed" % [passed,failed])
    quit(1 if failed > 0 else 0)
func _has_text(node:Node,wanted:String)->bool:
    if node is Label and (node as Label).text.find(wanted)>=0:return true
    if node is Button and (node as Button).text.find(wanted)>=0:return true
    for c in node.get_children():
        if _has_text(c,wanted):return true
    return false
