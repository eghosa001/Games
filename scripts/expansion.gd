extends RefCounted
class_name RenewExpansion

# RENEW empire layer: businesses, internal supply chains and owned resource sites.
# The system is deliberately self-contained so the original restoration loop stays stable.
var properties := [
    {"name":"Riverside Retail Unit","type":"Retail","industry":"Consumer Goods","cost":18000,"potential":90,"owned":false,"level":1,"employees":2,"price":145,"stock":0,"active":true,"quality":60,"last_profit":0,"inputs":{"goods":0},"input_need":{"goods":12}},
    {"name":"Brickworks Yard","type":"Factory","industry":"Building Materials","cost":42000,"potential":125,"owned":false,"level":1,"employees":4,"price":175,"stock":0,"active":true,"quality":60,"last_profit":0,"inputs":{"materials":0,"fuel":0},"input_need":{"materials":10,"fuel":4}},
    {"name":"Cold Storage Depot","type":"Warehouse","industry":"Food Processing","cost":30000,"potential":110,"owned":false,"level":1,"employees":3,"price":155,"stock":0,"active":true,"quality":60,"last_profit":0,"inputs":{"food":0,"fuel":0},"input_need":{"food":10,"fuel":3}}
]

var resource_sites := [
    {"name":"Cedar Materials Yard","resource":"materials","cost":28000,"owned":false,"level":1,"stock":0,"output":10,"risk":8},
    {"name":"Greenbelt Food Growers","resource":"food","cost":24000,"owned":false,"level":1,"stock":0,"output":10,"risk":12},
    {"name":"Harbor Fuel Terminal","resource":"fuel","cost":36000,"owned":false,"level":1,"stock":0,"output":8,"risk":16}
]
var unlocked := 1
var management_level := 0
var management_overhead := 0
var logistics_transfers := 0

func _init() -> void:
    _normalize_all()

func _normalize_all() -> void:
    for p in properties:
        if not p.has("inputs"): p["inputs"] = {}
        if not p.has("input_need"): p["input_need"] = {}
        if not p.has("quality"): p["quality"] = 60
        if not p.has("last_profit"): p["last_profit"] = 0
    for site in resource_sites:
        if not site.has("level"): site["level"] = 1
        if not site.has("stock"): site["stock"] = 0

func unlock_from_reputation(reputation: int) -> void:
    unlocked = clamp(1 + int(reputation / 15), 1, properties.size())

func buy(index: int, cash: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= unlocked:
        return {"ok":false,"cost":0,"message":"This opportunity is not unlocked yet."}
    var p = properties[index]
    if p["owned"]: return {"ok":false,"cost":0,"message":"You already own this property."}
    if cash < p["cost"]: return {"ok":false,"cost":p["cost"],"message":"Not enough capital."}
    p["owned"] = true
    p["stock"] = 0
    p["active"] = true
    return {"ok":true,"cost":p["cost"],"message":"Acquired %s." % p["name"]}

func selected(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {}
    return properties[index]

func produce(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"message":"Own the business first."}
    if not p["active"]: return {"ok":false,"message":"Business is paused."}

    var missing: Array[String] = []
    for resource in p["input_need"]:
        var need := int(p["input_need"][resource])
        if int(p["inputs"].get(resource, 0)) < need:
            missing.append(resource)
    if missing.size() > 0:
        return {"ok":false,"message":"Production needs %s. Use [D] to move internal supplies." % ", ".join(missing)}

    for resource in p["input_need"]:
        p["inputs"][resource] = int(p["inputs"].get(resource, 0)) - int(p["input_need"][resource])
    var output := 8 + int(p["employees"]) * 3 + int(p["level"]) * 4
    if p["type"] == "Retail": output += 4
    p["stock"] += output
    p["quality"] = clamp(int(p["quality"]) + randi_range(-2,4), 35, 100)
    return {"ok":true,"output":output,"quality":p["quality"],"message":"%s produced %d units." % [p["name"],output]}

func sell(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"revenue":0,"profit":0,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"revenue":0,"profit":0,"message":"Own the business first."}
    var demand := int(p["potential"]) + int(p["level"]) * 8 + int(p["quality"]) / 8
    var price_factor := clamp(1.15 - (float(p["price"]) / 220.0), 0.35, 1.1)
    demand = max(1, int(round(demand * price_factor)))
    var units := min(int(p["stock"]), demand)
    if units <= 0: return {"ok":false,"revenue":0,"profit":0,"message":"No inventory available to sell."}
    var revenue := units * int(p["price"])
    var wages := int(p["employees"]) * 160
    var overhead := 350 + int(p["level"]) * 120
    var logistics := min(240, logistics_transfers * 12)
    var profit := revenue - wages - overhead - logistics
    p["stock"] -= units
    p["last_profit"] = profit
    return {"ok":true,"units":units,"revenue":revenue,"profit":profit,"message":"%s sold %d units for $%d." % [p["name"],units,revenue]}

func hire(index: int, cash: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"cost":0,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"cost":0,"message":"Own the business first."}
    var cost := 1500 + int(p["employees"]) * 300
    if cash < cost: return {"ok":false,"cost":cost,"message":"Hiring requires $%d." % cost}
    p["employees"] += 1
    return {"ok":true,"cost":cost,"message":"%s hired another employee (%d total)." % [p["name"],p["employees"]]}

func change_price(index: int, delta: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"message":"Own the business first."}
    p["price"] = clamp(int(p["price"]) + delta, 70, 240)
    return {"ok":true,"message":"%s price is now $%d." % [p["name"],p["price"]]}

func toggle_active(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"message":"Own the business first."}
    p["active"] = not p["active"]
    return {"ok":true,"message":"%s is now %s." % [p["name"],"OPEN" if p["active"] else "PAUSED"]}

func upgrade(index: int, cash: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size() or not properties[index]["owned"]:
        return {"ok":false,"cost":0,"message":"Own the business first."}
    var p = properties[index]
    var cost := 7000 * int(p["level"])
    if cash < cost: return {"ok":false,"cost":cost,"message":"Upgrade requires $%d." % cost}
    p["level"] += 1
    p["potential"] += 10
    for resource in p["input_need"]:
        p["input_need"][resource] = int(p["input_need"][resource]) + 1
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [p["name"],p["level"]]}

func buy_resource_site(index: int, cash: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size(): return {"ok":false,"cost":0,"message":"Unknown resource site."}
    var site = resource_sites[index]
    if site["owned"]: return {"ok":false,"cost":0,"message":"You already own this resource site."}
    if cash < site["cost"]: return {"ok":false,"cost":site["cost"],"message":"Need $%d to acquire it." % site["cost"]}
    site["owned"] = true
    site["stock"] = 0
    return {"ok":true,"cost":site["cost"],"message":"Acquired %s. Internal %s supply is now possible." % [site["name"],site["resource"]]}

func harvest_resource(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size(): return {"ok":false,"output":0,"message":"Unknown resource site."}
    var site = resource_sites[index]
    if not site["owned"]: return {"ok":false,"output":0,"message":"Acquire the resource site first."}
    var output := int(site["output"]) + int(site["level"]) * 3
    var disruption := randi_range(1,100) <= int(site["risk"])
    if disruption: output = max(2, int(round(output * 0.5)))
    site["stock"] += output
    return {"ok":true,"output":output,"message":"%s generated %d %s." % [site["name"],output,site["resource"]]}

func upgrade_resource_site(index: int, cash: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size() or not resource_sites[index]["owned"]:
        return {"ok":false,"cost":0,"message":"Own the resource site first."}
    var site = resource_sites[index]
    var cost := 9000 * int(site["level"])
    if cash < cost: return {"ok":false,"cost":cost,"message":"Resource upgrade requires $%d." % cost}
    site["level"] += 1
    site["output"] += 2
    site["risk"] = max(3, int(site["risk"]) - 1)
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [site["name"],site["level"]}

func supply_business(index: int, resource: String, amount: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"moved":0,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"moved":0,"message":"Own the business first."}
    if not p["inputs"].has(resource): return {"ok":false,"moved":0,"message":"%s does not use %s." % [p["name"],resource]}
    var source := -1
    for i in range(resource_sites.size()):
        if resource_sites[i]["owned"] and resource_sites[i]["resource"] == resource:
            source = i
            break
    if source < 0: return {"ok":false,"moved":0,"message":"No owned %s resource site. Buy one first." % resource}
    var site = resource_sites[source]
    var moved := min(amount, int(site["stock"]))
    if moved <= 0: return {"ok":false,"moved":0,"message":"The %s site has no %s stock." % [site["name"],resource]}
    site["stock"] -= moved
    p["inputs"][resource] = int(p["inputs"].get(resource,0)) + moved
    logistics_transfers += 1
    return {"ok":true,"moved":moved,"message":"Moved %d %s into %s." % [moved,resource,p["name"]]}

func transfer_core_goods(index: int, amount: int, core_goods: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"moved":0,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"moved":0,"message":"Own the business first."}
    if not p["inputs"].has("goods"):
        return {"ok":false,"moved":0,"message":"This business cannot receive finished goods."}
    var moved := min(amount, core_goods)
    if moved <= 0: return {"ok":false,"moved":0,"message":"No finished goods are available at headquarters."}
    p["inputs"]["goods"] = int(p["inputs"].get("goods",0)) + moved
    logistics_transfers += 1
    return {"ok":true,"moved":moved,"message":"Transferred %d finished goods to %s." % [moved,p["name"]]}

func management_upgrade(cash: int) -> Dictionary:
    var cost := 12000 * (management_level + 1)
    if cash < cost: return {"ok":false,"cost":cost,"message":"HQ management upgrade requires $%d." % cost}
    management_level += 1
    management_overhead = management_level * 450
    return {"ok":true,"cost":cost,"message":"HQ management upgraded to level %d. More businesses can now be coordinated efficiently." % management_level}

func operate_day() -> Dictionary:
    _normalize_all()
    var income := 0
    var profit := -management_overhead
    var count := 0
    var report: Array[String] = []
    var active_count := 0
    for i in range(properties.size()):
        var p = properties[i]
        if not p["owned"] or not p["active"]: continue
        count += 1
        active_count += 1
        # Automatic production only when the business has enough internal inputs.
        var can_produce := true
        for resource in p["input_need"]:
            if int(p["inputs"].get(resource,0)) < int(p["input_need"][resource]):
                can_produce = false
        if can_produce:
            var result := produce(i)
            if result["ok"]: report.append("%s produced %d" % [p["name"],result["output"]])
        var sell_result := sell(i)
        var net := int(sell_result["profit"]) if sell_result["ok"] else -(int(p["employees"]) * 80 + 120)
        income += int(sell_result["revenue"]) if sell_result["ok"] else 0
        profit += net
        report.append("%s: $%d net" % [p["name"],net])
    # Resource sites have light upkeep, making ownership powerful but not free.
    var sites_owned := 0
    for site in resource_sites:
        if site["owned"]:
            sites_owned += 1
            profit -= 120 + int(site["level"]) * 50
    logistics_transfers = 0
    return {"businesses":count,"income":income,"profit":profit,"report":report,"resource_sites":sites_owned,"management_overhead":management_overhead}
