extends RefCounted
class_name RenewSupplyChain

# Supply-chain simulation: resources are produced at owned sites, moved through
# the player's network, and consumed by operating businesses. Shortages create
# real economic consequences instead of being cosmetic inventory numbers.
var network_stock := {"materials":0,"packaging":0,"fuel":0,"food":0}
var shipped_today := 0
var shortages_today: Array[String] = []
var disruption_level := 0
var competitor_pressure := 0

var resource_regions := {
    "materials": 5,
    "packaging": 0,
    "fuel": 2,
    "food": 3
}

func _normalize() -> void:
    for resource in ["materials","packaging","fuel","food"]:
        network_stock[resource] = max(0,int(network_stock.get(resource,0)))
    shipped_today=max(0,shipped_today)
    disruption_level=clamp(disruption_level,0,100)
    competitor_pressure=clamp(competitor_pressure,0,20)

func resource_price(resource:String, regions)->int:
    var base := {"materials":38,"packaging":28,"fuel":52,"food":34}.get(resource,40)
    var multiplier:=1.0+float(competitor_pressure)*0.025
    if regions and regions.has_method("regional_resource_bonus"):
        multiplier*=1.0+float(regions.regional_resource_bonus(resource))
    return max(10,int(round(float(base)*multiplier)))

func acquire_from_market(resource:String, amount:int, cash:int, regions)->Dictionary:
    if amount<=0: return {"ok":false,"cost":0,"message":"Choose a positive shipment."}
    var unit:=resource_price(resource,regions)
    var cost:=unit*amount
    if cash<cost: return {"ok":false,"cost":cost,"message":"Market shipment requires $%d."%cost}
    network_stock[resource]=int(network_stock.get(resource,0))+amount
    shipped_today+=amount
    return {"ok":true,"cost":cost,"message":"Bought %d %s for $%d."%[amount,resource,cost]}

func move_from_site(resource_site:Dictionary, amount:int, transport_capacity:int)->Dictionary:
    var available:=int(resource_site.get("stock",0))
    var moved:=min(min(amount,available),max(0,transport_capacity))
    if moved<=0: return {"ok":false,"moved":0,"message":"No transferable resource stock."}
    resource_site["stock"]=available-moved
    var resource:=String(resource_site.get("resource","materials"))
    network_stock[resource]=int(network_stock.get(resource,0))+moved
    shipped_today+=moved
    return {"ok":true,"moved":moved,"message":"Moved %d %s into the company network."%[moved,resource]}

func supply_business(property:Dictionary, amount:int, transport_capacity:int)->Dictionary:
    var moved:=0
    var missing:Array[String]=[]
    for resource in property.get("input_need",{}):
        var need: int = int(property["input_need"][resource])*max(1,amount)
        var available:=int(network_stock.get(resource,0))
        var send:=min(min(need,available),max(0,transport_capacity))
        if send>0:
            network_stock[resource]=available-send
            property["inputs"][resource]=int(property["inputs"].get(resource,0))+send
            moved+=send
        if send<need: missing.append(resource)
    if missing.size()>0:
        return {"ok":false,"moved":moved,"missing":missing,"message":"Network shortage: %s."%", ".join(missing)}
    shipped_today+=moved
    return {"ok":true,"moved":moved,"message":"Business fully supplied with %d input units."%moved}

func supply_branch(branch:Dictionary, amount:int, transport_capacity:int)->Dictionary:
    var need:=max(1,amount)
    var available:=int(network_stock.get("packaging",0))
    var moved:=min(min(need,available),max(0,transport_capacity))
    if moved<=0:
        return {"ok":false,"moved":0,"shortage":need,"message":"Packaging shortage at %s."%branch["name"]}
    network_stock["packaging"]=available-moved
    branch["inputs_packaging"]=int(branch.get("inputs_packaging",0))+moved
    shipped_today+=moved
    return {"ok":moved>=need,"moved":moved,"shortage":max(0,need-moved),"message":"%d packaging units allocated to %s."%[moved,branch["name"]]}

func consume_branch_packaging(branch:Dictionary, units:int)->Dictionary:
    var need=max(1,units)
    var stock:=int(branch.get("inputs_packaging",0))
    var used=min(stock,need)
    branch["inputs_packaging"]=stock-used
    return {"ok":used>=need,"used":used,"shortage":need-used}

func daily_network_update(expansion, transport_capacity:int)->Dictionary:
    _normalize()
    var generated:=0
    var moved:=0
    var disruptions:Array[String]=[]
    for site in expansion.resource_sites:
        if not bool(site.get("owned",false)): continue
        var resource:=String(site.get("resource","materials"))
        var output:=int(site.get("output",0))+int(site.get("level",1))*2
        if randf()*100.0<float(site.get("risk",0)):
            output=max(1,int(round(output*0.55)))
            disruptions.append("%s suffered a supply disruption."%site["name"])
        site["stock"]=int(site.get("stock",0))+output
        generated+=output
        var transfer=move_from_site(site,output,transport_capacity)
        moved+=int(transfer.get("moved",0))
    disruption_level=min(100,disruption_level+disruptions.size()*8)
    if disruptions.size()==0: disruption_level=max(0,disruption_level-2)
    shortages_today.clear()
    return {"generated":generated,"moved":moved,"disruptions":disruptions,"shortages":shortages_today}

func daily_business_check(expansion)->Dictionary:
    var shortages:Array[String]=[]
    for p in expansion.properties:
        if not bool(p.get("owned",false)) or not bool(p.get("active",false)): continue
        for resource in p.get("input_need",{}):
            var need=int(p["input_need"][resource])
            if int(p["inputs"].get(resource,0))<need:
                shortages.append("%s lacks %s."%[p["name"],resource])
    shortages_today=shortages
    return {"shortages":shortages,"count":shortages.size()}

func reset_day()->void:
    shipped_today=0
    shortages_today.clear()

func snapshot()->Dictionary:
    _normalize()
    return {"network_stock":network_stock.duplicate(true),"shipped_today":shipped_today,"disruption_level":disruption_level,"competitor_pressure":competitor_pressure}

func load_snapshot(state:Dictionary)->void:
    if state is Dictionary:
        network_stock=state.get("network_stock",network_stock).duplicate(true)
        shipped_today=int(state.get("shipped_today",0))
        disruption_level=int(state.get("disruption_level",0))
        competitor_pressure=int(state.get("competitor_pressure",0))
    _normalize()
