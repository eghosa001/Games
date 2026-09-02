extends Node2D

const Regions = preload("res://scripts/regions.gd")
var parent
var regions = Regions.new()
var message := ""
var last_day := 0

func _ready() -> void:
    parent=get_parent()
    regions.update_unlocks(parent.reputation)
    regions._normalize()
    last_day=parent.day
    queue_redraw()

func _process(_delta:float)->void:
    if parent == null: return
    regions.update_unlocks(parent.reputation)
    if parent.day != last_day:
        for news in regions.daily_update(parent.day): parent._log("REGION: "+news)
        var income:=apply_branch_income()
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

func select_region(index:int)->void:
    var count=regions.regions.size()
    index=(index%count+count)%count
    var result=regions.select(index,parent.reputation)
    message=result["message"]
    if result["ok"]: parent._log("REGION: "+message)

func establish_region()->void:
    var result=regions.establish(regions.selected,parent.cash,parent.reputation)
    message=result["message"]
    if not result["ok"]: return
    parent.cash-=int(result["cost"])
    parent.reputation+=3
    parent._log("REGIONAL EXPANSION: "+message+" (-$%s)."%_money(int(result["cost"])))

func upgrade_infrastructure()->void:
    var result=regions.build_infrastructure(regions.selected,parent.cash,parent.reputation)
    message=result["message"]
    if not result["ok"]: return
    parent.cash-=int(result["cost"])
    parent.reputation+=2
    parent._log("REGIONAL INFRASTRUCTURE: "+message+" (-$%s)."%_money(int(result["cost"])))

func dispatch_goods()->void:
    var destination:=regions.selected
    var origin:=0
    if destination==origin:
        message="The starter region is already local; choose another region first."
        return
    var amount:=min(10,parent.finished_goods)
    if amount<=0:
        message="Produce goods before dispatching a regional shipment."
        return
    var cost:=int(round(regions.logistics_cost(amount*45.0,origin,destination)))
    if parent.transport_capacity<amount:
        message="Fleet capacity is too low. Upgrade transport before shipping."
        return
    if parent.cash<cost:
        message="Regional freight requires $%s."%_money(cost)
        return
    parent.cash-=cost
    parent.finished_goods-=amount
    parent.reputation+=1
    parent._log("SHIPMENT: %d goods sent to %s for $%s freight."%[amount,regions.current()["name"],_money(cost)])
    message="Shipment delivered. Regional market is now stocked."

func branch_income()->int:
    var total:=0
    for i in range(regions.regions.size()):
        if regions.player_presence[i]<=0: continue
        var r=regions.regions[i]
        var income:=int(round(850.0*float(r["demand"])*float(regions.market_levels[i])))
        income+=int(regions.infrastructure[i])*250
        income-=int(round(220.0*float(r["labor"])))
        income-=int(round(140.0*float(r["logistics"])))
        income-=int(regions.rival_presence[i])*90
        total+=max(0,income)
    return total

func apply_branch_income()->int:
    var income:=branch_income()
    if income>0: parent.cash+=income
    return income

func _money(value:int)->String:
    return "%,d"%value

func _draw()->void:
    if parent==null: return
    draw_rect(Rect2(845,80,410,285),Color("18242e"),true)
    draw_string(ThemeDB.fallback_font,Vector2(865,108),"WORLD REGIONS",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("7891a5"))
    var r=regions.current()
    var unlocked=bool(r.get("unlocked",false))
    draw_string(ThemeDB.fallback_font,Vector2(865,138),"F3/F4  %s"%r["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(865,165),"Tier %d | Unlock REP %d | %s"%[r["tier"],r["rep"],"OPEN" if unlocked else "LOCKED"],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8ee6a8") if unlocked else Color("ffad8f"))
    draw_string(ThemeDB.fallback_font,Vector2(865,190),"Demand %.2fx | Market %.2fx"%[r["demand"],regions.market_levels[regions.selected]],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font,Vector2(865,214),"Logistics %.2fx | Labor %.2fx"%[r["logistics"],r["labor"]],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font,Vector2(865,238),"Competition %.2fx | Rivals %d"%[r["competition"],regions.rival_presence[regions.selected]],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffad8f"))
    draw_string(ThemeDB.fallback_font,Vector2(865,262),"Special: %s"%r["special"],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(865,286),"Industry: %s | Resource: %s"%[r["industry"],r["resource"]],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,310),"Presence %d | Infrastructure L%d"%[regions.player_presence[regions.selected],regions.infrastructure[regions.selected]],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(865,334),"F6 establish | F7 infrastructure | F8 dispatch",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,353),message,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color("8ee6a8"))
