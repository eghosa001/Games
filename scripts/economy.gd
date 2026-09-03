extends RefCounted
class_name RenewEconomy

var resources := {
    "materials": {"price":45,"stock":100,"base":45,"target_stock":100},
    "packaging": {"price":20,"stock":140,"base":20,"target_stock":120},
    "fuel": {"price":30,"stock":180,"base":30,"target_stock":160}
}
var market_multipliers := {"materials":1.0,"packaging":1.0,"fuel":1.0}
var suppliers := {
    "materials":[{"name":"Harbor Supply Co.","reliability":82,"markup":1.00},{"name":"Atlas Bulk","reliability":68,"markup":0.88},{"name":"Greenline Materials","reliability":94,"markup":1.16}],
    "packaging":[{"name":"Metro Pack","reliability":91,"markup":1.05},{"name":"BoxWorks","reliability":76,"markup":0.91},{"name":"Prime Wrap","reliability":97,"markup":1.18}],
    "fuel":[{"name":"Independent Fuel","reliability":68,"markup":0.95},{"name":"National Energy","reliability":88,"markup":1.08},{"name":"RapidFuel","reliability":58,"markup":0.78}]
}

func supplier_for(resource:String, choice:int=0)->Dictionary:
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
    return clamp(float(d.get("stock",0))/max(1.0,float(d.get("target_stock",100))),0.0,2.0)
func scarcity(resource:String)->Dictionary:
    if not resources.has(resource): return {"ok":false}
    var d:Dictionary=resources[resource]
    var a:=availability(resource)
    var shortage:=clamp(1.0-a,-1.0,1.0)
    var severity:=clamp(shortage,0.0,1.0)
    var factor:=clamp(1.0+shortage*1.15,0.55,2.50)
    var production_factor:=clamp(1.0-severity*0.55,0.45,1.0)
    var status:="surplus"
    if a<0.45: status="critical_shortage"
    elif a<0.75: status="shortage"
    elif a<1.10: status="balanced"
    return {"ok":true,"resource":resource,"stock":int(d.get("stock",0)),"target_stock":int(d.get("target_stock",100)),"availability":a,"shortage":shortage,"price_multiplier":factor,"production_factor":production_factor,"status":status}
func scarcity_snapshot()->Dictionary:
    var result:={}
    for resource in resources: result[resource]=scarcity(String(resource))
    return result
func quote(resource:String,amount:int,choice:int=0)->Dictionary:
    if not resources.has(resource) or amount<=0: return {"ok":false,"cost":0,"supplier":"Unknown"}
    var supplier:=supplier_for(resource,choice)
    if supplier.is_empty(): return {"ok":false,"cost":0,"supplier":"Unknown"}
    var market_factor:=float(market_multipliers.get(resource,1.0))
    var scarcity_factor:=float(scarcity(resource).get("price_multiplier",1.0))
    var cost:=int(round(float(resources[resource]["price"])*amount*float(supplier["markup"])*market_factor*scarcity_factor))
    return {"ok":true,"cost":cost,"supplier":supplier["name"],"reliability":supplier["reliability"],"market_factor":market_factor,"scarcity_factor":scarcity_factor}
func production_cost(orders:Array,choice:int=0)->Dictionary:
    var total:=0
    var quotes:Array=[]
    for order in orders:
        if not (order is Dictionary): return {"ok":false,"cost":0,"quotes":[]}
        var q:=quote(String(order.get("resource","")),int(order.get("amount",0)),choice)
        if not q["ok"]: return {"ok":false,"cost":0,"quotes":[]}
        total+=int(q["cost"]); quotes.append(q)
    return {"ok":true,"cost":total,"quotes":quotes}
func buy_resource(resource:String,amount:int,cash:int,choice:int=0)->Dictionary:
    var q:=quote(resource,amount,choice)
    if not q["ok"] or cash<q["cost"]: return {"ok":false,"cost":q["cost"],"amount":0,"supplier":q.get("supplier","Unknown")}
    var supplier:=supplier_for(resource,choice)
    if randi_range(1,100)>int(supplier["reliability"]): return {"ok":false,"cost":0,"amount":0,"supplier":supplier["name"],"failed":true}
    resources[resource]["stock"]+=amount
    return {"ok":true,"cost":q["cost"],"amount":amount,"supplier":supplier["name"],"scarcity_factor":q.get("scarcity_factor",1.0)}
func quote_bundle(orders:Array,choice:int=0,discount_rate:float=0.0,surcharge:int=0)->Dictionary:
    var base_total:=0
    var quotes:Array=[]
    for order in orders:
        if not (order is Dictionary): return {"ok":false,"cost":0,"base_cost":0,"quotes":[]}
        var q:=quote(String(order.get("resource","")),int(order.get("amount",0)),choice)
        if not q["ok"]: return {"ok":false,"cost":0,"base_cost":0,"quotes":[]}
        base_total+=int(q["cost"]); quotes.append(q)
    var discount:=int(round(float(base_total)*clamp(discount_rate,0.0,1.0)))
    return {"ok":true,"cost":max(0,base_total-discount+max(0,surcharge)),"base_cost":base_total,"discount":discount,"surcharge":max(0,surcharge),"quotes":quotes}
func buy_bundle(orders:Array,cash:int,choice:int=0,discount_rate:float=0.0,surcharge:int=0)->Dictionary:
    var q:=quote_bundle(orders,choice,discount_rate,surcharge)
    if not q["ok"]: return {"ok":false,"cost":0,"delivered":[],"supplier":"Unknown","failed":true}
    if cash<int(q["cost"]): return {"ok":false,"cost":int(q["cost"]),"delivered":[],"supplier":"Multiple suppliers","failed":false}
    for order in orders:
        var supplier:=supplier_for(String(order["resource"]),choice)
        if randi_range(1,100)>int(supplier["reliability"]): return {"ok":false,"cost":0,"delivered":[],"supplier":supplier["name"],"failed":true}
    var delivered:Array=[]
    var quotes:Array=q["quotes"]
    for i in range(orders.size()):
        var resource:=String(orders[i]["resource"]); var amount:=int(orders[i]["amount"])
        resources[resource]["stock"]+=amount
        delivered.append({"resource":resource,"amount":amount,"cost":int(quotes[i]["cost"]),"supplier":quotes[i]["supplier"]})
    return {"ok":true,"cost":int(q["cost"]),"base_cost":int(q["base_cost"]),"discount":int(q["discount"]),"surcharge":int(q["surcharge"]),"delivered":delivered,"supplier":"Bundle","failed":false}
func end_market_day()->void:
    for key in resources:
        var d:Dictionary=resources[key]
        var target:=max(1.0,float(d.get("target_stock",100))); var stock:=max(0.0,float(d.get("stock",0)))
        var shortage:=clamp(1.0-stock/target,-1.0,1.0); var factor:=clamp(1.0+shortage*1.15,0.55,2.50)
        var base_price:=float(d.get("base",d.get("price",30))); var target_price: float = base_price*factor
        var current:=float(d.get("price",base_price)); var drift:=clamp((target_price-current)*0.35,-12.0,18.0)
        d["price"]=clamp(int(round(current+drift+randi_range(-2,3))),10,250)
        d["stock"]=max(0,int(stock)+randi_range(-12,20)); resources[key]=d
