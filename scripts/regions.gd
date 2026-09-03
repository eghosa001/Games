extends RefCounted
class_name RenewRegions

## Regional economic layer. Geography now changes demand, labor, wages,
## logistics, resources, market size, competition, infrastructure and reputation.

const MAX_MARKET_LEVEL := 2.25
const MIN_MARKET_LEVEL := 0.75

var regions: Variant = [
    {"name":"Old Market Region","tier":1,"rep":0,"population":850000,"labor_supply":1.05,"wage_level":0.95,"demand":1.15,"logistics":1.10,"labor":1.00,"competition":0.85,"growth":0.02,"special":"Consumer trade hub","industry":"Consumer Goods","resource":"packaging","distance":0,"local_reputation":0.0,"market_size":1.00},
    {"name":"Industrial Belt Region","tier":2,"rep":15,"population":620000,"labor_supply":1.18,"wage_level":1.10,"demand":1.05,"logistics":0.90,"labor":1.10,"competition":1.15,"growth":0.025,"special":"Factory efficiency","industry":"Building Materials","resource":"materials","distance":1,"local_reputation":0.0,"market_size":0.82},
    {"name":"River Port Region","tier":3,"rep":30,"population":540000,"labor_supply":0.98,"wage_level":1.05,"demand":1.20,"logistics":0.72,"labor":1.05,"competition":1.05,"growth":0.035,"special":"Import/export gateway","industry":"Consumer Goods","resource":"fuel","distance":2,"local_reputation":0.0,"market_size":0.74},
    {"name":"Agricultural Plains","tier":3,"rep":35,"population":710000,"labor_supply":1.12,"wage_level":0.90,"demand":1.18,"logistics":0.95,"labor":0.90,"competition":0.95,"growth":0.04,"special":"Food supply abundance","industry":"Food Processing","resource":"materials","distance":3,"local_reputation":0.0,"market_size":0.88},
    {"name":"Northern Growth Corridor","tier":4,"rep":50,"population":430000,"labor_supply":0.92,"wage_level":1.20,"demand":1.38,"logistics":1.00,"labor":1.20,"competition":1.30,"growth":0.055,"special":"Fast-growing market","industry":"Consumer Goods","resource":"packaging","distance":4,"local_reputation":0.0,"market_size":0.61},
    {"name":"Resource Basin","tier":5,"rep":70,"population":290000,"labor_supply":1.08,"wage_level":0.85,"demand":0.92,"logistics":1.35,"labor":0.85,"competition":0.75,"growth":0.018,"special":"Cheap raw resources","industry":"Building Materials","resource":"materials","distance":5,"local_reputation":0.0,"market_size":0.45}
]
var selected: Variant = 0
var market_levels: Variant = [1.0,1.0,1.0,1.0,1.0,1.0]
var player_presence: Variant = [1,0,0,0,0,0]
var rival_presence: Variant = [1,1,1,0,0,0]
var infrastructure: Variant = [0,0,0,0,0,0]
var trade_routes: Dictionary = {}
var opportunity_rotation: Variant = 0
var regional_businesses: Dictionary = {}
var regional_prices: Dictionary = {}
var regional_wages: Dictionary = {}
var local_reputation: Array = [0.0,0.0,0.0,0.0,0.0,0.0]
var last_economic_update: Variant = 0

func _normalize() -> void:
    while market_levels.size() < regions.size(): market_levels.append(1.0)
    while player_presence.size() < regions.size(): player_presence.append(0)
    while rival_presence.size() < regions.size(): rival_presence.append(0)
    while infrastructure.size() < regions.size(): infrastructure.append(0)
    while local_reputation.size() < regions.size(): local_reputation.append(0.0)
    while regional_wages.size() < regions.size(): regional_wages[regional_wages.size()] = 1.0
    if market_levels.size() > regions.size(): market_levels.resize(regions.size())
    if player_presence.size() > regions.size(): player_presence.resize(regions.size())
    if rival_presence.size() > regions.size(): rival_presence.resize(regions.size())
    if infrastructure.size() > regions.size(): infrastructure.resize(regions.size())
    if local_reputation.size() > regions.size(): local_reputation.resize(regions.size())
    selected = clamp(selected,0,regions.size()-1)

func _ready() -> void:
    _normalize()
    _recalculate_economy(1)

func update_unlocks(reputation:int) -> void:
    for r in regions: r["unlocked"] = reputation >= int(r["rep"])

func select(index:int, reputation:int) -> Dictionary:
    _normalize(); update_unlocks(reputation)
    if index < 0 or index >= regions.size(): return {"ok":false,"message":"Invalid region."}
    if not bool(regions[index].get("unlocked",false)): return {"ok":false,"message":"%s unlocks at %d reputation."%[regions[index]["name"],regions[index]["rep"]]}
    selected=index
    return {"ok":true,"message":"%s selected."%regions[index]["name"]}

func current() -> Dictionary:
    _normalize()
    var result: Dictionary = regions[selected].duplicate(true)
    result["market_level"] = market_levels[selected]
    result["player_presence"] = player_presence[selected]
    result["rival_presence"] = rival_presence[selected]
    result["infrastructure"] = infrastructure[selected]
    result["local_reputation"] = local_reputation[selected]
    result["regional_wage"] = regional_wages.get(selected, float(regions[selected]["wage_level"]))
    result["business_count"] = int(regional_businesses.get(selected, []).size())
    return result

func current_opportunity(day:int=1) -> Dictionary:
    _normalize(); var r := current(); var kind := (selected + day + opportunity_rotation) % 4
    match kind:
        0: return {"type":"LOCAL CONTRACT","region":r["name"],"industry":r["industry"],"reward":1800+int(r["tier"])*700,"risk":0.04,"message":"A local buyer needs an urgent shipment. Delivering here rewards speed."}
        1: return {"type":"RESOURCE WINDFALL","region":r["name"],"resource":r["resource"],"reward":1400+int(r["tier"])*900,"risk":0.08,"message":"A temporary surplus of %s is available in this region." % r["resource"]}
        2: return {"type":"MARKET OPENING","region":r["name"],"industry":r["industry"],"bonus":0.12,"duration":3,"risk":0.02,"message":"Demand is surging for %s in this region." % r["industry"]}
        _: return {"type":"DISTRESSED ASSET","region":r["name"],"discount":0.15,"risk":0.12,"message":"A struggling local operator may be available below normal expansion cost."}

func rotate_opportunity() -> Dictionary:
    opportunity_rotation = (opportunity_rotation + 1) % 4
    return current_opportunity(1)

func establish(index:int, cash:int, reputation:int) -> Dictionary:
    _normalize(); update_unlocks(reputation)
    if index < 0 or index >= regions.size(): return {"ok":false,"message":"Invalid region."}
    if not bool(regions[index].get("unlocked",false)): return {"ok":false,"message":"Region is locked."}
    if player_presence[index] > 0: return {"ok":false,"message":"You already have an operating presence here."}
    var cost: int = 12000 + int(regions[index]["tier"])*6500
    if cash < cost: return {"ok":false,"message":"Regional launch requires $%s."%_money(cost)}
    player_presence[index]=1
    local_reputation[index] = max(local_reputation[index], 10.0)
    return {"ok":true,"cost":cost,"message":"Regional operation established in %s."%regions[index]["name"]}

func build_infrastructure(index:int, cash:int, reputation:int) -> Dictionary:
    _normalize(); update_unlocks(reputation)
    if index < 0 or index >= regions.size() or not bool(regions[index].get("unlocked",false)): return {"ok":false,"message":"Region is locked."}
    if player_presence[index] <= 0: return {"ok":false,"message":"Establish a regional operation first."}
    var level:int = int(infrastructure[index])
    if level >= 3: return {"ok":false,"message":"Regional infrastructure is already maxed."}
    var cost: int = 9000 + level*7000 + int(regions[index]["tier"])*1500
    if cash < cost: return {"ok":false,"message":"Infrastructure upgrade requires $%s."%_money(cost)}
    infrastructure[index]=level+1
    local_reputation[index] = clamp(local_reputation[index] + 2.0, -100.0, 100.0)
    return {"ok":true,"cost":cost,"message":"Infrastructure upgraded to level %d."%infrastructure[index]}

func establish_trade_route(origin:int, destination:int, cash:int, reputation:int) -> Dictionary:
    _normalize(); update_unlocks(reputation)
    if origin < 0 or origin >= regions.size() or destination < 0 or destination >= regions.size() or origin == destination: return {"ok":false,"message":"Choose two different regions for a trade route."}
    if player_presence[origin] <= 0 or player_presence[destination] <= 0: return {"ok":false,"message":"You need operations in both regions before connecting them."}
    var key: Variant = "%d-%d" % [min(origin,destination),max(origin,destination)]
    if trade_routes.has(key): return {"ok":false,"message":"This trade corridor is already active."}
    var distance: Variant = abs(origin-destination)
    var cost: int = 10000 + distance*5000 + int(regions[destination]["tier"])*2000
    if cash < cost: return {"ok":false,"message":"Trade corridor requires $%s."%_money(cost)}
    trade_routes[key] = {"level":1,"origin":origin,"destination":destination}
    local_reputation[origin] += 2.0; local_reputation[destination] += 2.0
    return {"ok":true,"cost":cost,"message":"Trade corridor connected %s and %s."%[regions[origin]["name"],regions[destination]["name"]]}

func trade_route_bonus(index:int) -> float:
    var bonus: Variant = 0.0
    for key in trade_routes:
        var route:Dictionary = trade_routes[key]
        if int(route["origin"]) == index or int(route["destination"]) == index: bonus += 0.08 * int(route["level"])
    return min(0.30,bonus)

func _recalculate_economy(day:int) -> void:
    _normalize()
    for i in range(regions.size()):
        var r: Dictionary = regions[i]
        var population_growth: Variant = 1.0 + float(r["growth"])
        r["population"] = max(100000, int(round(float(r["population"]) * population_growth)))
        r["market_size"] = clamp(float(r.get("market_size", 0.5)) * population_growth, 0.35, 2.5)
        var pressure: Variant = float(r["competition"]) * (0.04 * float(rival_presence[i]))
        var infrastructure_effect: Variant = float(infrastructure[i]) * 0.04
        var labor_tightness: Variant = max(0.0, 1.0 - float(r["labor_supply"]) + float(player_presence[i]) * 0.04)
        var wage: Variant = float(r["wage_level"]) * (1.0 + labor_tightness * 0.18 + pressure * 0.15 - infrastructure_effect * 0.08)
        regional_wages[i] = clamp(wage, 0.65, 1.80)
        var market_shift: Variant = float(r["growth"]) + float(local_reputation[i]) * 0.0008 + trade_route_bonus(i) * 0.03 - pressure * 0.02
        market_levels[i] = clamp(float(market_levels[i]) + market_shift, MIN_MARKET_LEVEL, MAX_MARKET_LEVEL)
        r["demand"] = clamp(float(r["demand"]) * (1.0 + float(r["growth"]) * 0.35), 0.70, 2.00)
        r["logistics"] = clamp(float(r["logistics"]) * (1.0 - infrastructure_effect * 0.12 - trade_route_bonus(i) * 0.05), 0.50, 1.60)
        r["competition"] = clamp(float(r["competition"]) + pressure * 0.02 - local_reputation[i] * 0.0004, 0.50, 1.80)
        regions[i] = r
        _simulate_regional_businesses(i, day)
    last_economic_update = day

func _simulate_regional_businesses(index:int, day:int) -> void:
    var list: Array = regional_businesses.get(index, [])
    var desired: Variant = max(1, int(round(float(regions[index]["market_size"]) * (2.0 + float(regions[index]["competition"])))))
    desired += rival_presence[index]
    while list.size() < desired:
        var n: Variant = list.size() + 1
        list.append({"id":"%d_%d"%[index,n],"name":"%s Operator %d"%[regions[index]["name"],n],"industry":regions[index]["industry"],"size":1,"market_share":0.0,"health":70.0 + float((n * 7) % 25),"local_reputation":30.0,"wage_multiplier":regional_wages.get(index,1.0),"last_day":day})
    var total_share: Variant = 0.0
    for business in list:
        var share: Variant = max(0.02, float(business.get("market_share",0.0)))
        var adaptation: Variant = (float(regions[index]["demand"]) - 1.0) * 0.8 - (float(regions[index]["competition"]) - 1.0) * 0.35
        business["health"] = clamp(float(business.get("health",70.0)) + adaptation, 10.0, 100.0)
        business["wage_multiplier"] = regional_wages.get(index,1.0)
        business["last_day"] = day
        business["market_share"] = share
        total_share += share
    if total_share > 0.0:
        for business in list: business["market_share"] = float(business["market_share"]) / total_share
    regional_businesses[index] = list

func daily_update(day:int) -> Array[String]:
    _normalize()
    var news:Array[String]=[]
    _recalculate_economy(day)
    for i in range(regions.size()):
        if day % 7 == 0 and i == selected:
            market_levels[i]=clamp(float(market_levels[i])+0.05,MIN_MARKET_LEVEL,MAX_MARKET_LEVEL)
            local_reputation[i] += 1.0
            news.append("%s market expanded."%regions[i]["name"])
        if day % 6 == 0 and rival_presence[i] > 0:
            rival_presence[i]=min(4,int(rival_presence[i])+1)
            news.append("Rivals increased pressure in %s."%regions[i]["name"])
        if day % 5 == 0 and player_presence[i] > 0 and infrastructure[i] < 3:
            rival_presence[i]=max(0,int(rival_presence[i])-1)
        if day % 10 == 0 and trade_route_bonus(i) > 0.0:
            market_levels[i]=clamp(float(market_levels[i])+0.02,MIN_MARKET_LEVEL,MAX_MARKET_LEVEL)
            news.append("Trade corridor boosted activity in %s."%regions[i]["name"])
        if player_presence[i] > 0:
            local_reputation[i] = clamp(local_reputation[i] + 0.15, -100.0, 100.0)
    if day % 3 == 0: opportunity_rotation = (opportunity_rotation + 1) % 4
    return news

func market_multiplier(industry:String) -> float:
    var r: Variant = current()
    var bonus: Variant = 1.0
    if industry == r["industry"]: bonus += 0.15
    if industry == "Food Processing" and r["special"] == "Food supply abundance": bonus += 0.12
    bonus += trade_route_bonus(selected)
    bonus += max(-0.15, min(0.20, local_reputation[selected] / 500.0))
    return float(r["demand"])*float(r["market_level"])*float(r["market_size"])*bonus

func logistics_cost(base:float, origin:int, destination:int) -> float:
    _normalize(); var distance:=abs(origin-destination); var regional:=float(regions[destination]["logistics"]); var infrastructure_discount:=1.0-float(infrastructure[destination])*0.06; var route_discount:=1.0-trade_route_bonus(destination)*0.45
    return base*(1.0+distance*0.12)*regional*infrastructure_discount*route_discount

func regional_resource_bonus(resource:String) -> float:
    var r:=current()
    if r["resource"] == resource: return 0.18 + infrastructure[selected]*0.03 + trade_route_bonus(selected)*0.35
    return trade_route_bonus(selected)*0.20

func competition_pressure() -> float:
    var r:=current()
    return min(0.45,float(r["competition"])*0.08*int(rival_presence[selected]))

func labor_cost(index:int=-1) -> float:
    _normalize(); var i := selected if index < 0 else clamp(index,0,regions.size()-1)
    return float(regional_wages.get(i,float(regions[i]["wage_level"])))

func labor_availability(index:int=-1) -> float:
    _normalize(); var i := selected if index < 0 else clamp(index,0,regions.size()-1)
    return float(regions[i]["labor_supply"]) / max(0.5,labor_cost(i))

func regional_market_size(index:int=-1) -> float:
    _normalize(); var i := selected if index < 0 else clamp(index,0,regions.size()-1)
    return float(regions[i]["market_size"]) * float(market_levels[i])

func local_reputation_score(index:int=-1) -> float:
    _normalize(); var i := selected if index < 0 else clamp(index,0,regions.size()-1)
    return float(local_reputation[i])

func register_business(index:int, business_name:String, industry:String, size:int=1, reputation:float=30.0) -> Dictionary:
    _normalize()
    if index < 0 or index >= regions.size(): return {"ok":false,"error":"invalid_region"}
    var list: Array = regional_businesses.get(index, [])
    var id: Variant = "%d_player_%d" % [index,list.size()+1]
    list.append({"id":id,"name":business_name,"industry":industry,"size":max(1,size),"market_share":0.02,"health":80.0,"local_reputation":reputation,"wage_multiplier":labor_cost(index),"last_day":last_economic_update})
    regional_businesses[index] = list
    player_presence[index] = 1
    return {"ok":true,"business":list[-1].duplicate(true)}

func capture_state() -> Dictionary:
    return {"selected":selected,"market_levels":market_levels.duplicate(true),"player_presence":player_presence.duplicate(true),"rival_presence":rival_presence.duplicate(true),"infrastructure":infrastructure.duplicate(true),"trade_routes":trade_routes.duplicate(true),"opportunity_rotation":opportunity_rotation,"regional_businesses":regional_businesses.duplicate(true),"regional_prices":regional_prices.duplicate(true),"regional_wages":regional_wages.duplicate(true),"local_reputation":local_reputation.duplicate(true),"last_economic_update":last_economic_update}

func restore_state(snapshot:Dictionary)->void:
    if snapshot.is_empty(): _normalize(); return
    selected=int(snapshot.get("selected",0)); market_levels=snapshot.get("market_levels",market_levels).duplicate(true); player_presence=snapshot.get("player_presence",player_presence).duplicate(true); rival_presence=snapshot.get("rival_presence",rival_presence).duplicate(true); infrastructure=snapshot.get("infrastructure",infrastructure).duplicate(true); trade_routes=snapshot.get("trade_routes",{}).duplicate(true); opportunity_rotation=int(snapshot.get("opportunity_rotation",0)); regional_businesses=snapshot.get("regional_businesses",{}).duplicate(true); regional_prices=snapshot.get("regional_prices",{}).duplicate(true); regional_wages=snapshot.get("regional_wages",{}).duplicate(true); local_reputation=snapshot.get("local_reputation",local_reputation).duplicate(true); last_economic_update=int(snapshot.get("last_economic_update",0)); _normalize()

func _money(value:int)->String: return str(value)
