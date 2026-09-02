extends Node2D

const SupplyChain = preload("res://scripts/supply_chain.gd")
const SupplyContracts = preload("res://scripts/supply_contracts.gd")
var parent
var supply=SupplyChain.new()
var contracts=SupplyContracts.new()
var message:=""
var last_day:=0

func _ready()->void:
    parent=get_parent()
    supply._normalize()
    contracts._normalize()
    last_day=parent.day
    queue_redraw()

func _process(_delta:float)->void:
    if parent==null: return
    if parent.day!=last_day:
        var result=supply.daily_network_update(parent.expansion,parent.transport_capacity)
        for note in result["disruptions"]: parent._log("SUPPLY: "+note)
        var checks=supply.daily_business_check(parent.expansion)
        var contract_note=contracts.daily_update()
        if contract_note!="": parent._log("SUPPLY: "+contract_note)
        if int(result["generated"])>0:
            parent._log("SUPPLY NETWORK: %d resource units generated; %d moved into company stock."%[result["generated"],result["moved"]])
        if int(checks["count"])>0:
            parent._log("SUPPLY SHORTAGE: %d operating businesses need inputs."%checks["count"])
        supply.reset_day()
        last_day=parent.day
    queue_redraw()

func market_buy(resource:String)->void:
    var region_controller=parent.get_node_or_null("RegionController")
    var regions=region_controller.regions if region_controller!=null else null
    var result=supply.acquire_from_market(resource,10,parent.cash,regions)
    var discount=contracts.resource_discount(resource)
    if result["ok"] and discount>0.0:
        var refund=int(round(float(result["cost"])*discount))
        result["cost"]=int(result["cost"])-refund
        result["message"]="Bought 10 %s with %d%% strategic discount for $%d."%[resource,int(discount*100.0),result["cost"]]
    message=result["message"]
    if result["ok"]:
        parent.cash-=int(result["cost"])
        parent._log("SPOT MARKET: "+result["message"])

func negotiate_supplier_contract()->void:
    var resource:="materials"
    var region_controller=parent.get_node_or_null("RegionController")
    if region_controller!=null:
        resource=String(region_controller.regions.current().get("resource","materials"))
    var rival_index=2
    var result=contracts.negotiate(rival_index,resource,parent)
    message=result["message"]
    if result["ok"]: parent._log("CONTRACT: "+result["message"])

func secure_resource_rights()->void:
    var resource:="materials"
    var region_controller=parent.get_node_or_null("RegionController")
    if region_controller!=null:
        resource=String(region_controller.regions.current().get("resource","materials"))
    var result=contracts.secure_resource(resource,parent)
    message=result["message"]
    if result["ok"]:
        supply.competitor_pressure=max(0,supply.competitor_pressure-contracts.pressure_reduction(resource))
        parent.reputation+=4
        parent._log("RESOURCE RIGHTS: "+result["message"])

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
    var active_contract:="None"
    if contracts.days_remaining>0:
        active_contract="%s (%dd, %d%% off)"%[contracts.active_resource,contracts.days_remaining,int(contracts.discount*100.0)]
    draw_string(ThemeDB.fallback_font,Vector2(865,468),"Rival pressure %d | Contract: %s"%[supply.competitor_pressure,active_contract],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font,Vector2(865,489),message,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color("8ee6a8"))

func _input(event:InputEvent)->void:
    if not event is InputEventKey or not event.pressed or event.echo: return
    match event.keycode:
        KEY_F13: negotiate_supplier_contract()
        KEY_F14: secure_resource_rights()
