extends Node2D

const Regions = preload("res://scripts/regions.gd")
const DomainSystem = preload("res://scripts/domain_system.gd")
var parent
var regions = Regions.new()
var state_adapter = DomainSystem.new()
var message: Variant = ""
var last_day: Variant = 0

func _ready() -> void:
    parent=get_tree().root.get_node_or_null("Renew")
    add_child(state_adapter)
    regions.update_unlocks(parent.reputation)
    regions._normalize()
    last_day=parent.day
    queue_redraw()

func _process(_delta:float)->void:
    if parent == null: return
    regions.update_unlocks(parent.reputation)
    if parent.day != last_day:
        for news in regions.daily_update(parent.day): parent._log("REGION: "+news)
        var income:int = apply_branch_income()
        if income>0: parent._log("REGIONAL REVENUE: $%s from established operations."%_money(income))
        last_day=parent.day
    queue_redraw()

func _input(event:InputEvent)->void:
    if not event is InputEventKey or not event.pressed or event.echo: return
    match event.keycode:
        KEY_F3: select_region(regions.selected+1)
        KEY_F4: select_region(regions.selected-1)
        KEY_F6: establish_region()
        KEY_F7: upgrade_infrastructure()
        KEY_F8: dispatch_goods()
        KEY_F10: establish_trade_route()

func select_region(index:int)->void:
    var count:int=regions.regions.size()
    if count <= 0: return
    index=(index%count+count)%count
    var result=regions.select(index,parent.reputation)
    message=result["message"]
    if result["ok"]: parent._log("REGION: "+message)

func establish_region()->void:
    var before_presence=regions.player_presence.duplicate(true)
    var before_reputation=regions.local_reputation.duplicate(true)
    var result=regions.establish(regions.selected,parent.cash,parent.reputation)
    message=result["message"]
    if not result["ok"]: return
    var spend=state_adapter.spend(int(result["cost"]),"regional operation establishment")
    if not bool(spend.get("ok",false)):
        regions.player_presence=before_presence
        regions.local_reputation=before_reputation
        message=str(spend.get("message","Regional establishment payment failed."))
        return
    parent.reputation+=3
    parent._log("REGIONAL EXPANSION: "+message+" (-$%s)."%_money(int(result["cost"])))

func upgrade_infrastructure()->void:
    var before_infrastructure=regions.infrastructure.duplicate(true)
    var before_reputation=regions.local_reputation.duplicate(true)
    var result=regions.build_infrastructure(regions.selected,parent.cash,parent.reputation)
    message=result["message"]
    if not result["ok"]: return
    var spend=state_adapter.spend(int(result["cost"]),"regional infrastructure upgrade")
    if not bool(spend.get("ok",false)):
        regions.infrastructure=before_infrastructure
        regions.local_reputation=before_reputation
        message=str(spend.get("message","Infrastructure payment failed."))
        return
    parent.reputation+=2
    parent._log("REGIONAL INFRASTRUCTURE: "+message+" (-$%s)."%_money(int(result["cost"])))

func establish_trade_route()->void:
    var origin:int=0; var destination:int=regions.selected
    if destination==origin: message="Select an established region other than the starter region."; return
    var before_routes=regions.trade_routes.duplicate(true)
    var before_reputation=regions.local_reputation.duplicate(true)
    var result=regions.establish_trade_route(origin,destination,parent.cash,parent.reputation)
    message=result["message"]
    if not result["ok"]: return
    var spend=state_adapter.spend(int(result["cost"]),"regional trade corridor")
    if not bool(spend.get("ok",false)):
        regions.trade_routes=before_routes
        regions.local_reputation=before_reputation
        message=str(spend.get("message","Trade corridor payment failed."))
        return
    parent.reputation+=4
    parent._log("TRADE CORRIDOR: "+message+" (-$%s)."%_money(int(result["cost"])))

func dispatch_goods()->void:
    var destination:int=regions.selected; var origin:int=0
    if destination==origin: message="The starter region is already local; choose another region first."; return
    var amount:int=min(10,parent.finished_goods)
    if amount<=0: message="Produce goods before dispatching a regional shipment."; return
    var cost:int=int(round(regions.logistics_cost(amount*45.0,origin,destination)))
    if parent.transport_capacity<amount: message="Fleet capacity is too low. Upgrade transport before shipping."; return
    var spend=state_adapter.spend(cost,"regional freight")
    if not bool(spend.get("ok",false)): message=str(spend.get("message","Regional freight requires sufficient cash.")); return
    parent.finished_goods-=amount
    parent.reputation+=1
    regions.local_reputation[destination] = clamp(float(regions.local_reputation[destination]) + 0.8, -100.0, 100.0)
    parent._log("SHIPMENT: %d goods sent to %s for $%s freight."%[amount,regions.current()["name"],_money(cost)])
    message="Shipment delivered. Regional market is now stocked."

func branch_income()->int:
    var total:int=0
    for i in range(regions.regions.size()):
        if regions.player_presence[i]<=0: continue
        var r=regions.regions[i]
        var market=float(regions.regional_market_size(i))
        var labor=float(regions.labor_cost(i))
        var market_fit:=1.0 if parent.expansion.properties.size() == 0 else 1.0
        var income:int=int(round(850.0*float(r["demand"])*market*market_fit))
        income+=int(regions.infrastructure[i])*250
        income+=int(round(income*regions.trade_route_bonus(i)))
        income+=int(round(income*max(-0.15,min(0.20,regions.local_reputation_score(i)/500.0))))
        income-=int(round(220.0*labor))
        income-=int(round(140.0*float(r["logistics"])))
        income-=int(regions.rival_presence[i]*90.0*float(r["competition"]))
        total+=max(0,income)
    return total

func apply_branch_income()->int:
    var income:int=branch_income()
    if income<=0: return 0
    var received=state_adapter.receive(income,"regional operations revenue")
    if not bool(received.get("ok",false)): return 0
    return income

func _money(value:int)->String: return String.num_int64(value)

func _draw()->void:
    if parent==null: return
    draw_rect(Rect2(845,80,410,330),Color("18242e"),true)
    draw_string(ThemeDB.fallback_font,Vector2(865,108),"WORLD REGIONS",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("7891a5"))
    var r=regions.current(); var unlocked=bool(r.get("unlocked",false))
    draw_string(ThemeDB.fallback_font,Vector2(865,138),"F3/F4  %s"%r["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(865,165),"Tier %d | Unlock REP %d | %s"%[r["tier"],r["rep"],"OPEN" if unlocked else "LOCKED"],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8ee6a8") if unlocked else Color("ffad8f"))
    draw_string(ThemeDB.fallback_font,Vector2(865,190),"Population %s | Market %.2fx"%[String.num_int64(int(r["population"])),regions.regional_market_size()],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font,Vector2(865,213),"Demand %.2fx | Labor %.2fx | Wage %.2fx"%[r["demand"],r["labor_supply"],r["regional_wage"]],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font,Vector2(865,236),"Logistics %.2fx | Competition %.2fx | Rivals %d"%[r["logistics"],r["competition"],r["rival_presence"]],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffad8f"))
    draw_string(ThemeDB.fallback_font,Vector2(865,259),"Local REP %.0f | Businesses %d"%[r["local_reputation"],r["business_count"]],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,282),"Special: %s"%r["special"],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(865,305),"Industry: %s | Resource: %s"%[r["industry"],r["resource"]],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,328),"Presence %d | Infrastructure L%d"%[r["player_presence"],r["infrastructure"]],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(865,350),"Trade %.0f%% | Labor availability %.2fx"%[regions.trade_route_bonus(regions.selected)*100.0,regions.labor_availability()],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,373),message,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,395),"Regional businesses respond to population, wages, demand and competition.",HORIZONTAL_ALIGNMENT_LEFT,370,10,Color("c6d0d8"))
