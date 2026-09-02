extends Node

# Expansion layer: owned properties become operating businesses, while owned
# resource sites feed the shared supply network.
var properties: Array = [
    {"name":"Sunrise Apartments","type":"Residential","condition":42,"value":25000,"cost":12000,"restoration_cost":12000,"income":1200,"owned":false,"active":false,"level":1,"inputs":{},"input_need":{},"unlock_rep":10},
    {"name":"Old Market","type":"Retail","condition":35,"value":32000,"cost":18000,"restoration_cost":18000,"income":1800,"owned":false,"active":false,"level":1,"inputs":{},"input_need":{"materials":2,"packaging":1},"unlock_rep":20},
    {"name":"Harbor Warehouse","type":"Industrial","condition":28,"value":50000,"cost":28000,"restoration_cost":28000,"income":2600,"owned":false,"active":false,"level":1,"inputs":{},"input_need":{"materials":2,"fuel":1},"unlock_rep":35}
]
var resource_sites: Array = [
    {"name":"Stone Quarry","resource":"materials","cost":15000,"owned":false,"level":1,"output":8,"risk":12,"stock":0},
    {"name":"Timber Camp","resource":"packaging","cost":15000,"owned":false,"level":1,"output":7,"risk":15,"stock":0},
    {"name":"Fuel Field","resource":"fuel","cost":15000,"owned":false,"level":1,"output":5,"risk":18,"stock":0}
]
var day: int = 1
var cash: int = 50000
var reputation: int = 10
var population: int = 100
var restored_count: int = 0
var management_level: int = 0
var management_overhead: int = 0
var selected_index: int = 0

func _ready() -> void:
    _normalize_all()

func _normalize_all() -> void:
    for p in properties:
        p["condition"] = int(p.get("condition", 0)); p["value"] = int(p.get("value", 0))
        p["restoration_cost"] = int(p.get("restoration_cost", p.get("cost", 0)))
        p["cost"] = int(p.get("cost", p["restoration_cost"])); p["income"] = int(p.get("income", 0))
        p["level"] = max(1, int(p.get("level", 1))); p["owned"] = bool(p.get("owned", false))
        p["active"] = bool(p.get("active", p["owned"]))
        if not p.has("inputs") or not (p["inputs"] is Dictionary): p["inputs"] = {}
        if not p.has("input_need") or not (p["input_need"] is Dictionary): p["input_need"] = {}
        p["unlock_rep"] = int(p.get("unlock_rep", 10)); p["unlocked"] = bool(p.get("unlocked", false))
    for site in resource_sites:
        site["cost"] = int(site.get("cost", 15000)); site["level"] = max(1, int(site.get("level", 1)))
        site["output"] = max(0, int(site.get("output", 0))); site["risk"] = clamp(int(site.get("risk", 0)), 0, 100)
        site["owned"] = bool(site.get("owned", false)); site["stock"] = max(0, int(site.get("stock", 0)))

func unlock_from_reputation(rep: int) -> void:
    _normalize_all()
    for p in properties: p["unlocked"] = int(rep) >= int(p["unlock_rep"])

func selected(index: int = -1) -> Dictionary:
    _normalize_all()
    if index >= 0: selected_index = index
    if properties.is_empty(): return {}
    selected_index = clamp(selected_index, 0, properties.size() - 1)
    return properties[selected_index]

func get_property_count() -> int: return properties.size()
func get_resource_site_count() -> int: return resource_sites.size()
func get_property(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {}
    return properties[index]
func get_resource_site(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size(): return {}
    return resource_sites[index]
func buy(index: int, cash_available: int) -> Dictionary: return restore_property(index, cash_available)
func upgrade(index: int, cash_available: int) -> Dictionary: return upgrade_property(index, cash_available)

func restore_property(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"cost":0,"message":"Unknown property."}
    var site = properties[index]
    if not bool(site.get("unlocked", true)): return {"ok":false,"cost":0,"message":"More reputation is required to access this property."}
    if bool(site["owned"]): return {"ok":false,"cost":0,"message":"Already owned."}
    var cost: int = int(site["restoration_cost"])
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Restoration requires $%d." % cost}
    site["owned"] = true; site["active"] = true; site["condition"] = 100; site["inputs"] = {}
    restored_count += 1; reputation += 5
    return {"ok":true,"cost":cost,"message":"%s restored and acquired." % site["name"]}

func buy_resource_site(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size(): return {"ok":false,"cost":0,"message":"Unknown resource site."}
    var site = resource_sites[index]
    if bool(site["owned"]): return {"ok":false,"cost":0,"message":"Already owned."}
    var cost: int = int(site["cost"])
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Purchase requires $%d." % cost}
    site["owned"] = true; reputation += 2
    return {"ok":true,"cost":cost,"message":"%s acquired. Generate its resource to build network stock." % site["name"]}

func operate_day() -> Dictionary:
    _normalize_all()
    var revenue: int = 0; var expense: int = 0; var businesses: int = 0
    for p in properties:
        if bool(p["owned"]) and bool(p.get("active", true)):
            businesses += 1; revenue += int(p["income"]) * int(p["level"]); expense += int(p["income"]) / 4
    for site in resource_sites:
        if bool(site["owned"]): revenue += int(site["output"]) * int(site["level"]) * 100
    management_overhead = management_level * 350; expense += management_overhead
    var profit: int = revenue - expense; cash += profit; day += 1; population += restored_count * 2
    return {"revenue":revenue,"expense":expense,"profit":profit,"cash":cash,"day":day,"businesses":businesses}

func upgrade_property(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size() or not bool(properties[index]["owned"]): return {"ok":false,"cost":0,"message":"Own the property first."}
    var site = properties[index]; var cost: int = 7000 * int(site["level"])
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Upgrade requires $%d." % cost}
    site["level"] += 1; site["income"] += 500; site["value"] += 5000
    management_level = max(management_level, int(properties.size() / 2))
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [site["name"],site["level"]]}

func generate_resource(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size() or not bool(resource_sites[index]["owned"]): return {"ok":false,"output":0,"message":"Own the resource site first."}
    var site = resource_sites[index]; var output: int = int(site["output"]) * int(site["level"])
    site["stock"] += output
    return {"ok":true,"output":output,"message":"%s generated %d %s. Stock: %d." % [site["name"],output,site["resource"],site["stock"]]}

func upgrade_resource_site(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size() or not bool(resource_sites[index]["owned"]): return {"ok":false,"cost":0,"message":"Own the resource site first."}
    var site = resource_sites[index]; var cost: int = 9000 * int(site["level"])
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Resource upgrade requires $%d." % cost}
    site["level"] += 1; site["output"] += 2; site["risk"] = max(3, int(site["risk"]) - 1)
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [site["name"],site["level"]]}

func supply_business(index: int, resource: String, amount: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"moved":0,"message":"Unknown business."}
    var p = properties[index]
    if not bool(p["owned"]): return {"ok":false,"moved":0,"message":"Own the business first."}
    if not p["input_need"].has(resource): return {"ok":false,"moved":0,"message":"%s does not use %s." % [p["name"],resource]}
    var site_index := -1
    for i in range(resource_sites.size()):
        if String(resource_sites[i]["resource"]) == resource and bool(resource_sites[i]["owned"]): site_index = i; break
    if site_index < 0: return {"ok":false,"moved":0,"message":"No owned %s source is available." % resource}
    var source = resource_sites[site_index]; var available: int = int(source["stock"]); var moved: int = min(max(0, amount), available)
    if moved <= 0: return {"ok":false,"moved":0,"message":"Generate %s before supplying this business." % resource}
    source["stock"] = available - moved; p["inputs"][resource] = int(p["inputs"].get(resource,0)) + moved
    return {"ok":true,"moved":moved,"message":"Supplied %d %s to %s from your owned source." % [moved,resource,p["name"]]}

func get_summary() -> Dictionary:
    _normalize_all()
    return {"day":day,"cash":cash,"reputation":reputation,"population":population,"restored_count":restored_count,"properties":properties,"resource_sites":resource_sites,"management_level":management_level,"management_overhead":management_overhead}
