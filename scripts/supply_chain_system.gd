extends Node

# Phase 9: one real V1 supply chain. Market resources move into a warehouse,
# iron is processed into metal, factories consume warehouse inputs, and finished
# furniture remains in the warehouse until customers buy it.
const SYSTEM_VERSION := 2
const RESOURCE_IDS := ["timber", "iron", "energy", "food", "electronics"]
const WAREHOUSE_LIMIT := 500.0
const FURNITURE_INPUTS := {"timber": 1.0, "metal": 0.5, "energy": 2.0}
const METAL_RECIPE := {"iron": 2.0, "energy": 0.5, "metal": 1.0}
var economy=null
var warehouse:Dictionary={"timber":0.0,"iron":0.0,"metal":0.0,"energy":0.0,"food":0.0,"electronics":0.0,"furniture":0.0}
var total_freight_cost:int=0;var last_operation:Dictionary={}
func _ready()->void:_ensure_warehouse()
func _ensure_warehouse()->void:
    for key in ["timber","iron","metal","energy","food","electronics","furniture"]:warehouse[key]=max(0.0,float(warehouse.get(key,0.0)))
func set_economy(value)->void:economy=value
func stock(resource:String)->float:return float(warehouse.get(resource,0.0))
func warehouse_snapshot()->Dictionary:return warehouse.duplicate(true)
func _technology():return get_node_or_null("/root/RenewTechnologySystem")
func _transport_capacity(level:int)->float:
    var base:=40.0+max(0,level-1)*20.0;var tech=_technology()
    return base*tech.transport_capacity_multiplier() if tech!=null else base
func _freight_cost(resource:String,amount:float,level:int)->int:
    var distance_factor:=1.0
    if economy!=null and economy.resources.has(resource):distance_factor=1.0+float(str(economy.resources[resource].get("region","Unknown")).length()%4)*0.05
    return int(round(amount*(2.0+float(max(0,3-level)))*distance_factor))
func procure(resource:String,amount:float,cash:int,transport_level:int=1)->Dictionary:
    if economy==null or not economy.resources.has(resource) or amount<=0:return {"ok":false,"reason":"invalid_resource"}
    var capacity:=_transport_capacity(transport_level);if amount>capacity:return {"ok":false,"reason":"transport_capacity","capacity":capacity,"requested":amount}
    var available:=float(economy.resources[resource].get("stock",0.0));if available<amount:return {"ok":false,"reason":"market_stock","available":available,"requested":amount}
    var unit_price:=float(economy.current_price(resource));var material_cost:=int(round(unit_price*amount));var freight:=_freight_cost(resource,amount,transport_level);var total:=material_cost+freight
    if cash<total:return {"ok":false,"reason":"cash","cost":total}
    economy.resources[resource]["stock"]=max(0.0,available-amount);warehouse[resource]=min(WAREHOUSE_LIMIT,stock(resource)+amount);total_freight_cost+=freight;last_operation={"type":"procure","resource":resource,"amount":amount,"material_cost":material_cost,"freight":freight,"cost":total,"region":economy.resources[resource].get("region","Unknown")};return {"ok":true,"resource":resource,"amount":amount,"cost":total,"material_cost":material_cost,"freight":freight}
func procure_bundle(orders:Array,cash:int,transport_level:int=1)->Dictionary:
    var total_amount:=0.0;for order in orders:total_amount+=float(order.get("amount",0.0))
    if total_amount>_transport_capacity(transport_level):return {"ok":false,"reason":"transport_capacity","capacity":_transport_capacity(transport_level),"requested":total_amount}
    var total_cost:=0
    for order in orders:
        var resource:=str(order.get("resource",""));var amount:=float(order.get("amount",0.0));if economy==null or not economy.resources.has(resource):return {"ok":false,"reason":"invalid_resource","resource":resource};if float(economy.resources[resource].get("stock",0.0))<amount:return {"ok":false,"reason":"market_stock","resource":resource};total_cost+=int(round(economy.current_price(resource)*amount))+_freight_cost(resource,amount,transport_level)
    if cash<total_cost:return {"ok":false,"reason":"cash","cost":total_cost}
    var delivered:Array=[]
    for order in orders:
        var result:=procure(str(order["resource"]),float(order["amount"]),cash,transport_level);if not result["ok"]:return {"ok":false,"reason":"delivery_failed","details":result};cash-=int(result["cost"]);delivered.append(result)
    return {"ok":true,"cost":total_cost,"delivered":delivered,"warehouse":warehouse_snapshot()}
func process_iron_to_metal(cycles:int=1)->Dictionary:
    cycles=max(0,cycles);var possible:=cycles;possible=min(possible,int(floor(stock("iron")/METAL_RECIPE["iron"])));possible=min(possible,int(floor(stock("energy")/METAL_RECIPE["energy"])));if possible<=0:return {"ok":false,"reason":"insufficient_iron_or_energy","cycles":0}
    warehouse["iron"]-=METAL_RECIPE["iron"]*possible;warehouse["energy"]-=METAL_RECIPE["energy"]*possible;warehouse["metal"]=min(WAREHOUSE_LIMIT,stock("metal")+METAL_RECIPE["metal"]*possible);last_operation={"type":"metal_processing","cycles":possible,"iron_consumed":METAL_RECIPE["iron"]*possible,"energy_consumed":METAL_RECIPE["energy"]*possible,"metal_output":METAL_RECIPE["metal"]*possible};return {"ok":true,"cycles":possible,"output":METAL_RECIPE["metal"]*possible,"iron_consumed":METAL_RECIPE["iron"]*possible,"energy_consumed":METAL_RECIPE["energy"]*possible}
func can_make_furniture(cycles:int=1)->Dictionary:
    var possible:=max(0,cycles);for resource in FURNITURE_INPUTS:possible=min(possible,int(floor(stock(resource)/float(FURNITURE_INPUTS[resource]))));return {"ok":possible>0,"cycles":possible,"inputs":FURNITURE_INPUTS.duplicate(true)}
func consume_furniture_inputs(cycles:int)->Dictionary:
    var check:=can_make_furniture(cycles);if not check["ok"]:return check
    var run_cycles:=int(check["cycles"]);for resource in FURNITURE_INPUTS:warehouse[resource]-=float(FURNITURE_INPUTS[resource])*run_cycles
    last_operation={"type":"furniture_factory_inputs","cycles":run_cycles,"consumed":{"timber":FURNITURE_INPUTS["timber"]*run_cycles,"metal":FURNITURE_INPUTS["metal"]*run_cycles,"energy":FURNITURE_INPUTS["energy"]*run_cycles};return {"ok":true,"cycles":run_cycles,"consumed":last_operation["consumed"].duplicate(true)}
func receive_furniture(amount:int)->void:warehouse["furniture"]=min(WAREHOUSE_LIMIT,stock("furniture")+max(0,amount))
func sell_furniture(amount:int,price:int)->Dictionary:
    var sold:=min(max(0,amount),int(floor(stock("furniture"))));var revenue:=sold*max(0,price);warehouse["furniture"]-=sold;last_operation={"type":"customer_sale","amount":sold,"price":price,"revenue":revenue};return {"ok":sold>0,"sold":sold,"revenue":revenue}
func capture_state()->Dictionary:return {"system_version":SYSTEM_VERSION,"warehouse":warehouse_snapshot(),"total_freight_cost":total_freight_cost,"last_operation":last_operation.duplicate(true)}
func restore_state(snapshot:Dictionary)->void:
    if snapshot.is_empty():return
    warehouse=snapshot.get("warehouse",warehouse).duplicate(true);total_freight_cost=int(snapshot.get("total_freight_cost",0));last_operation=snapshot.get("last_operation",{}).duplicate(true);_ensure_warehouse()
