extends SceneTree
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS: "+label)
    else:failed+=1;push_error("FAIL: "+label)
func run()->void:
    root.size=Vector2i(390,844)
    var scene:=load("res://scenes/Main.tscn") as PackedScene
    check(scene!=null,"Main scene loads")
    if scene==null:quit(1);return
    var game:=scene.instantiate();root.add_child(game);current_scene=game
    await process_frame;await process_frame
    var manager:=root.get_node_or_null("RenewUIScreenManager")
    for n in ["DashboardPanel","FinancePanel","PortfolioPanel","CorporationsPanel"]:
        check(game.get_node_or_null("UI/"+n)!=null,"deep screen mounted: "+n)
    game.cash=250000;game.day=1;game.inspect_property();game.acquire_property()
    var ledger:=game.get_node("UI/FinancePanel");ledger._refresh(true)
    check(str(ledger.overview_label.text).to_lower().find("cash")>=0,"legacy deep Finance still binds ledger")
    var portfolio:=game.get_node("UI/PortfolioPanel");portfolio._refresh(true)
    check(not str(portfolio.list_label.text).is_empty(),"legacy deep Portfolio still binds assets")
    var network:=game.get_node("UI/CorporationsPanel");network._refresh(true)
    check(str(network.list_label.text).find("Apex")>=0,"corporation network still live")
    var hud:=game.get_node("UI/MainHUD")
    hud.open_figma_view("finance");await process_frame
    check(str(hud.get("active_view"))=="finance","Figma Finance is primary runtime")
    var content:=hud.get("mobile_content") as Control
    check(content.get_node_or_null("Transactions")!=null,"Figma Finance transaction surface exists")
    hud.open_figma_view("portfolio");await process_frame
    content=hud.get("mobile_content")
    check(content.get_node_or_null("OwnedAssets")!=null,"Figma Portfolio asset surface exists")
    hud.open_figma_view("more");await process_frame
    content=hud.get("mobile_content")
    check(content.find_children("MoreTile*","Panel",false,false).size()==9,"MORE owns production management routes")
    if manager!=null:
        manager.show_screen("CorporationsPanel");await process_frame
        check(manager.get_active_screen_name()=="CorporationsPanel","deep corporation screen still opens")
    game.queue_free();await process_frame
    print("V9 SCREENS: %d passed, %d failed" % [passed,failed])
    quit(1 if failed>0 else 0)
