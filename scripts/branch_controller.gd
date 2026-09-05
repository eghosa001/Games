extends Node2D

const Branches = preload("res://scripts/branches.gd")
const DomainSystem = preload("res://scripts/domain_system.gd")
var parent
var branches=Branches.new()
var state_adapter=DomainSystem.new()
var last_day:=0
var message:=""

func _ready()->void:
    parent=get_tree().root.get_node_or_null("Renew")
    add_child(state_adapter)
    last_day=parent.day
    queue_redraw()

func _process(_delta:float)->void:
    if parent==null: return
    if parent.day!=last_day:
        var region_controller=parent.get_node_or_null("World/RegionController")
        if region_controller!=null:
            var finance=get_tree().root.get_node_or_null("RenewFinanceSystem")
            var finance_before:Dictionary = finance.capture_state() if finance != null else {}
            var branches_before=branches.branches.duplicate(true)
            var result=branches.operate_day(region_controller.regions)
            var profit:=int(result.get("profit",0))
            var settled:Dictionary
            if profit>0:
                settled=state_adapter.receive(profit,"regional branch operating result")
            elif profit<0:
                settled=state_adapter.spend(-profit,"regional branch operating loss")
            else:
                settled={"ok":true}
            if not bool(settled.get("ok",false)):
                branches.branches=branches_before
                if finance != null and not finance_before.is_empty():
                    finance.restore_state(finance_before)
                message=str(settled.get("message","Branch operating result could not be settled."))
            elif int(result["businesses"])>0:
                parent._log("BRANCHES: %d regional businesses generated $%s."%[result["businesses"],_money(profit)])
        last_day=parent.day
    queue_redraw()

func _input(event:InputEvent)->void:
    if not event is InputEventKey or not event.pressed or event.echo or not event.ctrl_pressed: return
    match event.keycode:
        KEY_F6: select_branch(branches.selected+1)
        KEY_F7: launch_selected()
        KEY_F8: stock_selected()
        KEY_F10: hire_selected()
        KEY_F11: upgrade_selected()
        KEY_F12: price_selected()

func select_branch(index:int)->void:
    if branches.branches.is_empty(): return
    var result=branches.select((index%branches.branches.size()+branches.branches.size())%branches.branches.size())
    message=result["message"]

func launch_selected()->void:
    var b=branches.current()
    var region_controller=parent.get_node_or_null("World/RegionController")
    if region_controller==null: return
    var region=int(b["region"])
    if region<0 or region>=region_controller.regions.player_presence.size() or region_controller.regions.player_presence[region]<=0:
        message="Establish a regional presence before opening this branch."
        return
    var before=branches.branches.duplicate(true)
    var result=branches.launch(branches.selected,parent.cash)
    message=result["message"]
    if not result["ok"]: return
    var spend=state_adapter.spend(int(result["cost"]),"regional branch launch")
    if not bool(spend.get("ok",false)):
        branches.branches=before
        message=str(spend.get("message","Branch launch payment failed."))
        return
    parent.reputation+=4
    parent._log("BRANCH OPENED: %s (-$%s)."%[b["name"],_money(int(result["cost"]))])

func stock_selected()->void:
    var b=branches.current()
    if not bool(b["owned"]): message="Launch the branch first."; return
    var region_controller=parent.get_node_or_null("World/RegionController")
    if region_controller==null: return
    var amount:=min(10,parent.finished_goods)
    if amount<=0: message="Produce core goods before stocking a branch."; return
    var origin:=0
    var destination:=int(b["region"])
    if destination<0 or destination>=region_controller.regions.regions.size():
        message="Branch region is invalid."
        return
    var cost:=int(round(region_controller.regions.logistics_cost(amount*45.0,origin,destination)))
    var spend=state_adapter.spend(cost,"branch stock shipment")
    if not bool(spend.get("ok",false)): message=str(spend.get("message","Shipment requires sufficient cash.")); return
    parent.finished_goods-=amount
    var stocked=branches.stock(branches.selected,amount)
    if not bool(stocked.get("ok",false)):
        parent.finished_goods+=amount
        state_adapter.receive(cost,"branch stock shipment refund")
        message=str(stocked.get("message","Branch stocking failed."))
        return
    parent._log("BRANCH SUPPLY: %d goods delivered to %s for $%s."%[amount,b["name"],_money(cost)])
    message="Branch stocked with %d goods."%amount

func hire_selected()->void:
    var before=branches.branches.duplicate(true)
    var result=branches.hire(branches.selected,parent.cash)
    message=result["message"]
    if not result["ok"]: return
    var spend=state_adapter.spend(int(result["cost"]),"regional branch hiring")
    if not bool(spend.get("ok",false)):
        branches.branches=before
        message=str(spend.get("message","Branch hiring payment failed."))
        return
    parent.reputation+=1

func upgrade_selected()->void:
    var before=branches.branches.duplicate(true)
    var result=branches.upgrade(branches.selected,parent.cash)
    message=result["message"]
    if not result["ok"]: return
    var spend=state_adapter.spend(int(result["cost"]),"regional branch upgrade")
    if not bool(spend.get("ok",false)):
        branches.branches=before
        message=str(spend.get("message","Branch upgrade payment failed."))
        return
    parent.reputation+=2

func price_selected()->void:
    var result=branches.change_price(branches.selected,10)
    message=result["message"]

func _money(value:int)->String:
    return str(value)

func _draw()->void:
    if parent==null: return
    draw_rect(Rect2(25,510,800,180),Color("111b23"),true)
    draw_string(ThemeDB.fallback_font,Vector2(45,538),"REGIONAL BRANCHES",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("7891a5"))
    var b=branches.current()
    draw_string(ThemeDB.fallback_font,Vector2(45,565),"CTRL+F6 select | %s | %s"%[b["name"],b["industry"]],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(45,590),"Status: %s | Staff %d | Stock %d | Level %d"%["OPEN" if b["owned"] else "CLOSED",b["employees"],b["stock"],b["level"]],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(45,613),"Price $%d | Quality %d | Last P&L $%s"%[b["price"],b["quality"],_money(int(b["cashflow"]))],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(45,637),"CTRL+F7 launch | CTRL+F8 stock | CTRL+F10 hire | CTRL+F11 upgrade | CTRL+F12 price +" ,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(45,663),message,HORIZONTAL_ALIGNMENT_LEFT,750,12,Color("b7d7ff"))
