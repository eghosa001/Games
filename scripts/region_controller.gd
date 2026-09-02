extends Node2D

# Region controller: unlock markets, establish presence, infrastructure and trade routes.
var parent: Node
var regions = preload("res://scripts/regions.gd").new()
var branch_income_cache := 0

func _ready() -> void:
    parent = get_parent()
    regions._normalize()
    queue_redraw()

func select_region(index:int)->Dictionary:
    var result=regions.select(index)
    if result["ok"]: queue_redraw()
    return result

func current()->Dictionary:
    return regions.current()

func establish_region()->Dictionary:
    var result=regions.establish(regions.selected,parent.cash,parent.reputation)
    if result["ok"]:
        parent.cash-=int(result["cost"])
        queue_redraw()
    return result

func upgrade_infrastructure()->Dictionary:
    var result=regions.upgrade_infrastructure(regions.selected,parent.cash)
    if result["ok"]:
        parent.cash-=int(result["cost"])
        queue_redraw()
    return result

func establish_trade_route()->Dictionary:
    var result=regions.establish_trade_route(regions.selected,parent.cash)
    if result["ok"]:
        parent.cash-=int(result["cost"])
        queue_redraw()
    return result

func branch_income()->int:
    var total:=0
    for i in range(regions.regions.size()):
        if regions.player_presence[i]<=0: continue
        var r=regions.regions[i]
        var income:int=int(round(850.0*float(r["demand"])*float(regions.market_levels[i])))
        income+=int(regions.infrastructure[i])*250
        income+=int(round(income*regions.trade_route_bonus(i)))
        income-=int(round(220.0*float(r["labor"])))
        income-=int(round(140.0*float(r["logistics"])))
        income-=int(regions.rival_presence[i])*90
        total+=max(0,income)
    return total

func apply_branch_income()->int:
    var income:int=branch_income()
    if income>0: parent.cash+=income
    return income

func _money(value:int)->String:
    return String.num_int64(value)

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
