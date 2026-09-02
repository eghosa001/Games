extends Node

# Scarcity converts physical supply into price pressure and production pressure.
const SYSTEM_VERSION := 1
const MIN_PRICE_MULTIPLIER := 0.55
const MAX_PRICE_MULTIPLIER := 2.50
const MIN_PRODUCTION_FACTOR := 0.45

func profile(resource:String,data:Dictionary)->Dictionary:
    var stock:=max(0.0,float(data.get("stock",0)))
    var target:=max(1.0,float(data.get("target_stock",data.get("base_stock",100))))
    var availability:=clamp(stock/target,0.0,2.0)
    var shortage:=clamp(1.0-availability,-1.0,1.0)
    var severity:=clamp(shortage,0.0,1.0)
    var price_multiplier:=clamp(1.0+shortage*1.15,MIN_PRICE_MULTIPLIER,MAX_PRICE_MULTIPLIER)
    var production_factor:=clamp(1.0-severity*0.55,MIN_PRODUCTION_FACTOR,1.0)
    var status:="surplus"
    if availability<0.45: status="critical_shortage"
    elif availability<0.75: status="shortage"
    elif availability<1.10: status="balanced"
    return {"resource":resource,"stock":int(stock),"target_stock":int(target),"availability":availability,"shortage":shortage,"price_multiplier":price_multiplier,"production_factor":production_factor,"status":status}

func snapshot(resources:Dictionary)->Dictionary:
    var result:={}
    for resource in resources: result[resource]=profile(String(resource),resources[resource])
    return result

func apply_to_economy(economy)->Dictionary:
    if economy==null: return {}
    var result:=snapshot(economy.resources)
    for resource in result: economy.set_market_modifier(String(resource),float(result[resource]["price_multiplier"]))
    return result

func product_cost_multiplier(economy)->float:
    if economy==null: return 1.0
    var total:=0.0
    var count:=0
    for resource in economy.resources:
        total+=float(profile(String(resource),economy.resources[resource])["price_multiplier"])
        count+=1
    return clamp(total/max(1,count),0.70,2.20)

func product_market_price(economy,base_price:float=110.0)->float:
    return base_price*product_cost_multiplier(economy)

func _process(_delta:float)->void:
    var main:=get_tree().current_scene
    if main==null: return
    var economy=main.get("economy")
    if economy==null: return
    apply_to_economy(economy)
    var rivals=main.get("rivals")
    if rivals==null: return
    var multiplier:=product_cost_multiplier(economy)
    for rival in rivals.rivals:
        if not rival.has("_scarcity_base_price"): rival["_scarcity_base_price"]=int(rival.get("price",110))
        rival["price"]=clamp(int(round(float(rival["_scarcity_base_price"])*multiplier)),50,300)

func capture_state(resources:Dictionary)->Dictionary:
    return {"system_version":SYSTEM_VERSION,"snapshot":snapshot(resources)}
