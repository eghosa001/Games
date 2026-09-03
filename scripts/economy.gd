extends RefCounted
class_name RenewEconomy

# Phase 8: the resource market has five canonical resources. Every resource
# carries the full economic state needed by supply, production and demand.
const RESOURCE_CONFIG := {
    "timber": {"base_price":50.0,"production_rate":16.0,"consumption_rate":12.0,"stock":120.0,"region":"Forest Belt"},
    "iron": {"base_price":80.0,"production_rate":12.0,"consumption_rate":10.0,"stock":100.0,"region":"Iron Ridge"},
    "energy": {"base_price":35.0,"production_rate":24.0,"consumption_rate":20.0,"stock":180.0,"region":"Power Basin"},
    "food": {"base_price":30.0,"production_rate":28.0,"consumption_rate":24.0,"stock":220.0,"region":"River Plains"},
    "electronics": {"base_price":120.0,"production_rate":7.0,"consumption_rate":6.0,"stock":70.0,"region":"Tech Coast"}
}

var resources: Dictionary = {}
var market_multipliers := {}
var suppliers := {}

func _init() -> void:
    _ensure_resources()

func _ensure_resources() -> void:
    for resource in RESOURCE_CONFIG:
        if not resources.has(resource):
            var c:Dictionary = RESOURCE_CONFIG[resource]
            resources[resource] = {"base_price":c["base_price"],"current_price":c["base_price"],"price":c["base_price"],"production_rate":c["production_rate"],"consumption_rate":c["consumption_rate"],"stock":c["stock"],"scarcity":0.0,"region":c["region"],"target_stock":c["stock"]}
        var d:Dictionary = resources[resource]
        d["base_price"] = float(d.get("base_price",RESOURCE_CONFIG[resource]["base_price"]))
        d["current_price"] = float(d.get("current_price",d.get("price",d["base_price"])))
        d["price"] = d["current_price"]
        d["production_rate"] = float(d.get("production_rate",RESOURCE_CONFIG[resource]["production_rate"]))
        d["consumption_rate"] = float(d.get("consumption_rate",RESOURCE_CONFIG[resource]["consumption_rate"]))
        d["stock"] = max(0.0,float(d.get("stock",RESOURCE_CONFIG[resource]["stock"])))
        d["region"] = String(d.get("region",RESOURCE_CONFIG[resource]["region"]))
        d["target_stock"] = max(1.0,float(d.get("target_stock",RESOURCE_CONFIG[resource]["stock"])))
        resources[resource] = d
        market_multipliers[resource] = float(market_multipliers.get(resource,1.0))
        suppliers[resource] = _default_suppliers(resource)

func _default_suppliers(resource:String)->Array:
    return [{"name":"Regional Producer","reliability":90,"markup":1.00,"region":String(resources.get(resource,{}).get("region","Unknown"))},{"name":"National Broker","reliability":76,"markup":1.12,"region":"National"},{"name":"Emergency Importer","reliability":60,"markup":1.30,"region":"International"}]

func resource_ids()->Array: return RESOURCE_CONFIG.keys()
func get_resource(resource:String)->Dictionary: return resources.get(resource,{}).duplicate(true)
func current_price(resource:String)->float: return float(resources.get(resource,{}).get("current_price",0.0))
func production_rate(resource:String)->float: return float(resources.get(resource,{}).get("production_rate",0.0))
func consumption_rate(resource:String)->float: return float(resources.get(resource,{}).get("consumption_rate",0.0))
func stock_amount(resource:String)->float: return float(resources.get(resource,{}).get("stock",0.0))

func supplier_for(resource:String,choice:int=0)->Dictionary:
    if not suppliers.has(resource): return {}
    var list:Array=suppliers[resource]
    return list[clamp(choice,0,list.size()-1)]
func set_market_modifier(resource:String,multiplier:float)->void:
    if market_multipliers.has(resource): market_multipliers[resource]=clamp(multiplier,0.55,2.50)
func clear_market_modifiers()->void:
    for resource in market_multipliers: market_multipliers[resource]=1.0
func availability(resource:String)->float:
    if not resources.has(resource): return 0.0
    var d:Dictionary=resources[resource]
    return clamp(float(d.get("stock",0.0))/max(1.0,float(d.get("target_stock",100.0))),0.0,2.0)
func scarcity(resource:String)->Dictionary:
    if not resources.has(resource): return {"ok":false}
    var d:Dictionary=resources[resource]; var a:=availability(resource); var shortage:=clamp(1.0-a,-1.0,1.0); var severity:=clamp(shortage,0.0,1.0)
    d["scarcity"]=severity; resources[resource]=d
    var factor:=clamp(1.0+shortage*1.15,0.55,2.50); var production_factor:=clamp(1.0-severity*0.55,0.45,1.0); var status:="surplus"
    if a<0.45: status="critical_shortage"
    elif a<0.75: status="shortage"
    elif a<1.10: status="balanced"
    return {"ok":true,"resource":resource,"stock":float(d.get("stock",0.0)),"target_stock":float(d.get("target_stock",100.0)),"availability":a,"shortage":shortage,"scarcity":severity,"price_multiplier":factor,"production_factor":production_factor,"status":status,"region":d.get("region","Unknown")}
func scarcity_snapshot()->Dictionary:
    var result:={}
    for resource in resources: result[resource]=scarcity(String(resource))
    return result

func quote(resource:String,amount:int,choice:int=0)->Dictionary:
    if not resources.has(resource) or amount<=0: return {"ok":false,"cost":0,"supplier":"Unknown"}
    var supplier:=supplier_for(resource,choice); if supplier.is_empty(): return {"ok":false,"cost":0,"supplier":"Unknown"}
    var market_factor:=float(market_multipliers.get(resource,1.0)); var scarcity_factor:=float(scarcity(resource).get("price_multiplier",1.0)); var cost:=int(round(current_price(resource)*amount*float(supplier["markup"])*market_factor*scarcity_factor))
    return {"ok":true,"cost":cost,"unit_price":current_price(resource),"supplier":supplier["name"],"reliability":supplier["reliability"],"market_factor":market_factor,"scarcity_factor":scarcity_factor,"region":resources[resource]["region"]}
func production_cost(orders:Array,choice:int=0)->Dictionary:
    var total:=0; var quotes:Array=[]
    for order in orders:
        if not (order is Dictionary): return {"ok":false,"cost":0,"quotes":[]}
        var q:=quote(String(order.get("resource","")),int(order.get("amount",0)),choice); if not q["ok"]: return {"ok":false,"cost":0,"quotes":[]}
        total+=int(q["cost"]); quotes.append(q)
    return {"ok":true,"cost":total,"quotes":quotes}
func buy_resource(resource:String,amount:int,cash:int,choice:int=0)->Dictionary:
    var q:=quote(resource,amount,choice); if not q["ok"] or cash<q["cost"]: return {"ok":false,"cost":q["cost"],"amount":0,"supplier":q.get("supplier","Unknown")}
    var supplier:=supplier_for(resource,choice); if randi_range(1,100)>int(supplier["reliability"]): return {"ok":false,"cost":0,"amount":0,"supplier":supplier["name"],"failed":true}
    resources[resource]["stock"]+=amount; return {"ok":true,"cost":q["cost"],"amount":amount,"supplier":supplier["name"],"scarcity_factor":q.get("scarcity_factor",1.0)}
func quote_bundle(orders:Array,choice:int=0,discount_rate:float=0.0,surcharge:int=0)->Dictionary:
    var base_total:=0; var quotes:Array=[]
    for order in orders:
        if not (order is Dictionary): return {"ok":false,"cost":0,"base_cost":0,"quotes":[]}
        var q:=quote(String(order.get("resource","")),int(order.get("amount",0)),choice); if not q["ok"]: return {"ok":false,"cost":0,"base_cost":0,"quotes":[]}
        base_total+=int(q["cost"]); quotes.append(q)
    var discount:=int(round(float(base_total)*clamp(discount_rate,0.0,1.0))); return {"ok":true,"cost":max(0,base_total-discount+max(0,surcharge)),"base_cost":base_total,"discount":discount,"surcharge":max(0,surcharge),"quotes":quotes}
func buy_bundle(orders:Array,cash:int,choice:int=0,discount_rate:float=0.0,surcharge:int=0)->Dictionary:
    var q:=quote_bundle(orders,choice,discount_rate,surcharge); if not q["ok"] or cash<int(q["cost"]): return {"ok":false,"cost":int(q.get("cost",0)),"delivered":[],"supplier":"Multiple suppliers","failed":false}
    for order in orders:
        var supplier:=supplier_for(String(order["resource"]),choice); if randi_range(1,100)>int(supplier["reliability"]): return {"ok":false,"cost":0,"delivered":[],"supplier":supplier["name"],"failed":true}
    var delivered:Array=[]; var quotes:Array=q["quotes"]
    for i in range(orders.size()):
        var resource:=String(orders[i]["resource"]); var amount:=int(orders[i]["amount"]); resources[resource]["stock"]+=amount; delivered.append({"resource":resource,"amount":amount,"cost":int(quotes[i]["cost"]),"supplier":quotes[i]["supplier"]})
    return {"ok":true,"cost":int(q["cost"]),"base_cost":int(q["base_cost"]),"discount":int(q["discount"]),"surcharge":int(q["surcharge"]),"delivered":delivered,"supplier":"Bundle","failed":false}

func estimate_demand(resource:String,price:float)->float:
    if not resources.has(resource): return 0.0
    var base:=float(resources[resource]["base_price"]); return max(0.0,consumption_rate(resource)*(1.0-clamp((price/base-1.0)*0.8,-0.7,0.9)))
func market_value(resource:String,amount:float)->float: return max(0.0,amount)*current_price(resource)
func end_market_day()->void:
    _ensure_resources()
    for key in resources:
        var d:Dictionary=resources[key]; var stock:=max(0.0,float(d.get("stock",0.0))); var target:=max(1.0,float(d.get("target_stock",100.0))); var net:=float(d.get("production_rate",0.0))-float(d.get("consumption_rate",0.0)); stock=max(0.0,stock+net+randi_range(-4,8)); d["stock"]=stock
        var scarcity_level:=clamp(1.0-stock/target,0.0,1.0); var balance:=float(d.get("production_rate",0.0))-float(d.get("consumption_rate",0.0)); var pressure:=clamp((float(d.get("consumption_rate",0.0))-float(d.get("production_rate",0.0)))/max(1.0,float(d.get("consumption_rate",1.0))),-1.0,1.0); var target_price:=float(d["base_price"])*(1.0+scarcity_level*1.15+pressure*0.20); var current:=float(d.get("current_price",d["base_price"])); d["current_price"]=clamp(current+(target_price-current)*0.35+randi_range(-2,3),10.0,500.0); d["price"]=d["current_price"]; d["scarcity"]=scarcity_level; resources[key]=d

# Backward-compatible aliases are deliberately not stored as extra resources;
# callers should migrate to timber/iron/energy/food/electronics.
