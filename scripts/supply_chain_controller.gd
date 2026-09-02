extends Node2D

const SupplyChain = preload("res://scripts/supply_chain.gd")
var parent
var supply=SupplyChain.new()
var message:=""
var last_day:=0

func _ready()->void:
    parent=get_parent()
    supply._normalize()
    last_day=parent.day
    queue_redraw()

func _process(_delta:float)->void:
    if parent==null: return
    if parent.day!=last_day:
        var result=supply.daily_network_update(parent.expansion,parent.transport_capacity)
        for note in result["disruptions"]: parent._log("SUPPLY: "+note)
        var checks=supply.daily_business_check(parent.expansion)
        if int(result["generated"])>0:
            parent._log("SUPPLY NETWORK: %d resource units generated; %d moved into company stock."%[result["generated"],result["moved"]])
        if int(checks["count"])>0:
            parent._log("SUPPLY SHORTAGE: %d operating businesses need inputs."%checks["count"])
        supply.reset_day()
        last_day=parent.day
    queue_redraw()

func market_buy(resource:String)->void:
    var result=supply.acquire_from_market(resource,10,parent.cash,parent.get_node("RegionController").regions)
    message=result["message"]
    if result["ok"]:
        parent.cash-=int(result["cost"])
        parent._log("SPOT MARKET: "+result["message"])

func supply_selected_expansion()->void:
    var p=parent.expansion.selected(parent.selected_expansion)
    if p.is_empty() or not bool(p.get("owned",false)):
        message="Own the selected expansion first."; return
    var result=supply.supply_business(p,1,parent.transport_capacity)
    message=result["message"]
    if result["ok"]: parent._log("SUPPLY CHAIN: "+result["message"])

func supply_resource_to_network()->void:
    var idx=0
    var result=supply.move_from_site(parent.expansion.resource_sites[idx],10,parent.transport_capacity)
    message=result["message"]
    if result["ok"]: parent._log("RESOURCE LOGISTICS: "+result["message"])

func _money(value:int)->String:
    return "%,d"%value

func _draw()->void:
    if parent==null: return
    draw_rect(Rect2(845,370,410,135),Color("18242e"),true)
    draw_string(ThemeDB.fallback_font,Vector2(865,397),"SUPPLY NETWORK",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("7891a5"))
    draw_string(ThemeDB.fallback_font,Vector2(865,423),"Materials %d | Packaging %d"%[int(supply.network_stock.get("materials",0)),int(supply.network_stock.get("packaging",0))],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(865,445),"Fuel %d | Food %d | Disruption %d%%"%[int(supply.network_stock.get("fuel",0)),int(supply.network_stock.get("food",0)),supply.disruption_level],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(865,468),"Spot market: 10 units | Transport cap %d"%parent.transport_capacity,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font,Vector2(865,489),message,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color("8ee6a8"))
