extends Node

var properties: Array = [
    {"name":"Sunrise Apartments","type":"Residential","condition":42,"value":25000,"restoration_cost":12000,"income":1200,"owned":false,"level":1,"inputs":[]},
    {"name":"Old Market","type":"Retail","condition":35,"value":32000,"restoration_cost":18000,"income":1800,"owned":false,"level":1,"inputs":["materials","packaging"]},
    {"name":"Harbor Warehouse","type":"Industrial","condition":28,"value":50000,"restoration_cost":28000,"income":2600,"owned":false,"level":1,"inputs":["materials","fuel"]}
]

# Resource ownership uses the same commodity vocabulary as the economy and
# supply-chain systems so owned sites can actually feed the empire network.
var resource_sites: Array = [
    {"name":"Stone Quarry","resource":"materials","owned":false,"level":1,"output":8,"risk":12},
    {"name":"Timber Camp","resource":"packaging","owned":false,"level":1,"output":7,"risk":15},
    {"name":"Fuel Field","resource":"fuel","owned":false,"level":1,"output":5,"risk":18}
]

var day: int = 1
var cash: int = 50000
var reputation: int = 10
var population: int = 100
var restored_count: int = 0

func _ready() -> void:
    _normalize_all()

func _normalize_all() -> void:
    for p in properties:
        p["condition"] = int(p.get("condition", 0))
        p["value"] = int(p.get("value", 0))
        p["restoration_cost"] = int(p.get("restoration_cost", 0))
        p["income"] = int(p.get("income", 0))
        p["level"] = int(p.get("level", 1))
        p["owned"] = bool(p.get("owned", false))
        if not p.has("inputs"): p["inputs"] = []
    for site in resource_sites:
        site["level"] = int(site.get("level", 1))
        site["output"] = int(site.get("output", 0))
        site["risk"] = int(site.get("risk", 0))
        site["owned"] = bool(site.get("owned", false))
        site["stock"] = int(site.get("stock", 0))

func get_property_count() -> int:
    return properties.size()

func get_resource_site_count() -> int:
    return resource_sites.size()

func get_property(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {}
    return properties[index]

func get_resource_site(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size(): return {}
    return resource_sites[index]

func restore_property(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"cost":0,"message":"Unknown property."}
    var site = properties[index]
    if site["owned"]: return {"ok":false,"cost":0,"message":"Already owned."}
    var cost: int = int(site["restoration_cost"])
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Restoration requires $%d." % cost}
    site["owned"] = true
    site["condition"] = 100
    restored_count += 1
    reputation += 5
    return {"ok":true,"cost":cost,"message":"%s restored and acquired." % site["name"]}

func buy_resource_site(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size(): return {"ok":false,"cost":0,"message":"Unknown resource site."}
    var site = resource_sites[index]
    if site["owned"]: return {"ok":false,"cost":0,"message":"Already owned."}
    var cost: int = 15000 * int(site["level"])
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Purchase requires $%d." % cost}
    site["owned"] = true
    reputation += 2
    return {"ok":true,"cost":cost,"message":"%s acquired." % site["name"]}

func operate_day() -> Dictionary:
    _normalize_all()
    var revenue: int = 0
    var expense: int = 0
    for p in properties:
        if p["owned"]:
            revenue += int(p["income"]) * int(p["level"])
            expense += int(p["income"]) / 4
    for site in resource_sites:
        if site["owned"]:
            revenue += int(site["output"]) * 100
    var profit: int = revenue - expense
    cash += profit
    day += 1
    population += restored_count * 2
    return {"revenue":revenue,"expense":expense,"profit":profit,"cash":cash,"day":day}

func upgrade_property(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size() or not properties[index]["owned"]:
        return {"ok":false,"cost":0,"message":"Own the property first."}
    var site = properties[index]
    var cost: int = 7000 * int(site["level"])
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Upgrade requires $%d." % cost}
    site["level"] += 1
    site["income"] += 500
    site["value"] += 5000
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [site["name"],site["level"]]}

func generate_resource(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size() or not resource_sites[index]["owned"]:
        return {"ok":false,"output":0,"message":"Own the resource site first."}
    var site = resource_sites[index]
    var output: int = int(site["output"]) * int(site["level"])
    site["stock"] = int(site.get("stock",0)) + output
    return {"ok":true,"output":output,"message":"%s generated %d %s." % [site["name"],output,site["resource"]]}

func upgrade_resource_site(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size() or not resource_sites[index]["owned"]:
        return {"ok":false,"cost":0,"message":"Own the resource site first."}
    var site = resource_sites[index]
    var cost: int = 9000 * int(site["level"])
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Resource upgrade requires $%d." % cost}
    site["level"] += 1
    site["output"] += 2
    site["risk"] = max(3, int(site["risk"]) - 1)
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [site["name"],site["level"]]}

func supply_business(index: int, resource: String, amount: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"moved":0,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"moved":0,"message":"Own the business first."}
    if not p["inputs"].has(resource): return {"ok":false,"moved":0,"message":"%s does not use %s." % [p["name"],resource]}
    return {"ok":true,"moved":amount,"message":"Supplied %d %s to %s." % [amount,resource,p["name"]]}

func get_summary() -> Dictionary:
    _normalize_all()
    return {"day":day,"cash":cash,"reputation":reputation,"population":population,"restored_count":restored_count,"properties":properties,"resource_sites":resource_sites}
