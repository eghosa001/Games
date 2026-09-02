extends RefCounted
class_name RenewRegions

# Macro world layer: districts remain local neighborhoods while regions define
# the larger economic geography that determines where an empire should expand.
var regions := [
    {"name":"Old Market Region","tier":1,"rep":0,"demand":1.15,"logistics":1.10,"labor":1.00,"competition":0.85,"growth":0.02,"special":"Consumer trade hub","industry":"Consumer Goods","resource":"packaging","distance":0},
    {"name":"Industrial Belt Region","tier":2,"rep":15,"demand":1.05,"logistics":0.90,"labor":1.10,"competition":1.15,"growth":0.025,"special":"Factory efficiency","industry":"Building Materials","resource":"materials","distance":1},
    {"name":"River Port Region","tier":3,"rep":30,"demand":1.20,"logistics":0.72,"labor":1.05,"competition":1.05,"growth":0.035,"special":"Import/export gateway","industry":"Consumer Goods","resource":"fuel","distance":2},
    {"name":"Agricultural Plains","tier":3,"rep":35,"demand":1.18,"logistics":0.95,"labor":0.90,"competition":0.95,"growth":0.04,"special":"Food supply abundance","industry":"Food Processing","resource":"materials","distance":3},
    {"name":"Northern Growth Corridor","tier":4,"rep":50,"demand":1.38,"logistics":1.00,"labor":1.20,"competition":1.30,"growth":0.055,"special":"Fast-growing market","industry":"Consumer Goods","resource":"packaging","distance":4},
    {"name":"Resource Basin","tier":5,"rep":70,"demand":0.92,"logistics":1.35,"labor":0.85,"competition":0.75,"growth":0.018,"special":"Cheap raw resources","industry":"Building Materials","resource":"materials","distance":5}
]
var selected := 0
var market_levels := [1.0,1.0,1.0,1.0,1.0,1.0]
var player_presence := [1,0,0,0,0,0]
var rival_presence := [1,1,1,0,0,0]
var infrastructure := [0,0,0,0,0,0]
var trade_routes: Dictionary = {}

func _normalize() -> void:
    while market_levels.size() < regions.size(): market_levels.append(1.0)
    while player_presence.size() < regions.size(): player_presence.append(0)
    while rival_presence.size() < regions.size(): rival_presence.append(0)
    while infrastructure.size() < regions.size(): infrastructure.append(0)
    if market_levels.size() > regions.size(): market_levels.resize(regions.size())
    if player_presence.size() > regions.size(): player_presence.resize(regions.size())
    if rival_presence.size() > regions.size(): rival_presence.resize(regions.size())
    if infrastructure.size() > regions.size(): infrastructure.resize(regions.size())
    selected = clamp(selected,0,regions.size()-1)

func update_unlocks(reputation:int) -> void:
    for r in regions:
        r["unlocked"] = reputation >= int(r["rep"])

func select(index:int, reputation:int) -> Dictionary:
    _normalize(); update_unlocks(reputation)
    if index < 0 or index >= regions.size(): return {"ok":false,"message":"Invalid region."}
    if not bool(regions[index].get("unlocked",false)):
        return {"ok":false,"message":"%s unlocks at %d reputation."%[regions[index]["name"],regions[index]["rep"]]}
    selected=index
    return {"ok":true,"message":"%s selected."%regions[index]["name"]}

func current() -> Dictionary:
    _normalize()
    return regions[selected]

func establish(index:int, cash:int, reputation:int) -> Dictionary:
    _normalize(); update_unlocks(reputation)
    if index < 0 or index >= regions.size(): return {"ok":false,"message":"Invalid region."}
    if not bool(regions[index].get("unlocked",false)): return {"ok":false,"message":"Region is locked."}
    if player_presence[index] > 0: return {"ok":false,"message":"You already have an operating presence here."}
    var cost := 12000 + int(regions[index]["tier"])*6500
    if cash < cost: return {"ok":false,"message":"Regional launch requires $%s."%_money(cost)}
    player_presence[index]=1
    return {"ok":true,"cost":cost,"message":"Regional operation established in %s."%regions[index]["name"]}

func build_infrastructure(index:int, cash:int, reputation:int) -> Dictionary:
    _normalize(); update_unlocks(reputation)
    if index < 0 or index >= regions.size() or not bool(regions[index].get("unlocked",false)): return {"ok":false,"message":"Region is locked."}
    if player_presence[index] <= 0: return {"ok":false,"message":"Establish a regional operation first."}
    var level:int = int(infrastructure[index])
    if level >= 3: return {"ok":false,"message":"Regional infrastructure is already maxed."}
    var cost := 9000 + level*7000 + int(regions[index]["tier"])*1500
    if cash < cost: return {"ok":false,"message":"Infrastructure upgrade requires $%s."%_money(cost)}
    infrastructure[index]=level+1
    return {"ok":true,"cost":cost,"message":"Infrastructure upgraded to level %d."%infrastructure[index]}

func establish_trade_route(origin:int, destination:int, cash:int, reputation:int) -> Dictionary:
    _normalize(); update_unlocks(reputation)
    if origin < 0 or origin >= regions.size() or destination < 0 or destination >= regions.size() or origin == destination:
        return {"ok":false,"message":"Choose two different regions for a trade route."}
    if player_presence[origin] <= 0 or player_presence[destination] <= 0:
        return {"ok":false,"message":"You need operations in both regions before connecting them."}
    var key := "%d-%d" % [min(origin,destination),max(origin,destination)]
    if trade_routes.has(key):
        return {"ok":false,"message":"This trade corridor is already active."}
    var distance := abs(origin-destination)
    var cost := 10000 + distance*5000 + int(regions[destination]["tier"])*2000
    if cash < cost:
        return {"ok":false,"message":"Trade corridor requires $%s."%_money(cost)}
    trade_routes[key] = {"level":1,"origin":origin,"destination":destination}
    return {"ok":true,"cost":cost,"message":"Trade corridor connected %s and %s."%[regions[origin]["name"],regions[destination]["name"]]}

func trade_route_bonus(index:int) -> float:
    var bonus := 0.0
    for key in trade_routes:
        var route:Dictionary = trade_routes[key]
        if int(route["origin"]) == index or int(route["destination"]) == index:
            bonus += 0.08 * int(route["level"])
    return min(0.30,bonus)

func daily_update(day:int) -> Array[String]:
    _normalize()
    var news:Array[String]=[]
    for i in range(regions.size()):
        market_levels[i]=clamp(float(market_levels[i])+float(regions[i]["growth"]),0.85,1.75)
        if day % 7 == 0 and i == selected:
            market_levels[i]=clamp(market_levels[i]+0.05,0.85,1.75)
            news.append("%s market expanded."%regions[i]["name"])
        if day % 6 == 0 and rival_presence[i] > 0:
            rival_presence[i]=min(4,int(rival_presence[i])+1)
            news.append("Rivals increased pressure in %s."%regions[i]["name"])
        if day % 5 == 0 and player_presence[i] > 0 and infrastructure[i] < 3:
            rival_presence[i]=max(0,int(rival_presence[i])-1)
        if day % 10 == 0 and trade_route_bonus(i) > 0.0:
            market_levels[i]=clamp(float(market_levels[i])+0.02,0.85,1.75)
            news.append("Trade corridor boosted activity in %s."%regions[i]["name"])
    return news

func market_multiplier(industry:String) -> float:
    var r=current()
    var bonus := 1.0
    if industry == r["industry"]: bonus += 0.15
    if industry == "Food Processing" and r["special"] == "Food supply abundance": bonus += 0.12
    bonus += trade_route_bonus(selected)
    return float(r["demand"])*float(market_levels[selected])*bonus

func logistics_cost(base:float, origin:int, destination:int) -> float:
    _normalize()
    var distance:=abs(origin-destination)
    var regional:=float(regions[destination]["logistics"])
    var infrastructure_discount:=1.0-float(infrastructure[destination])*0.06
    var route_discount:=1.0-trade_route_bonus(destination)*0.45
    return base*(1.0+distance*0.12)*regional*infrastructure_discount*route_discount

func regional_resource_bonus(resource:String) -> float:
    var r=current()
    if r["resource"] == resource: return 0.18 + infrastructure[selected]*0.03 + trade_route_bonus(selected)*0.35
    return trade_route_bonus(selected)*0.20

func competition_pressure() -> float:
    var r=current()
    return min(0.35,float(r["competition"])*0.08*int(rival_presence[selected]))

func _money(value:int)->String:
    return "%,d"%value
