extends Node

const ExpansionState = preload("res://scripts/expansion_state.gd")

var properties: Array = [
    {"name":"Sunrise Apartments","type":"Residential","industry":"Housing","condition":42,"value":25000,"cost":12000,"restoration_cost":12000,"income":1200,"owned":false,"active":false,"level":1,"inputs":{},"input_need":{},"unlock_rep":10},
    {"name":"Old Market","type":"Retail","industry":"Consumer Goods","condition":35,"value":32000,"cost":18000,"restoration_cost":18000,"income":1800,"owned":false,"active":false,"level":1,"inputs":{},"input_need":{"materials":2,"packaging":1},"unlock_rep":20},
    {"name":"Harbor Warehouse","type":"Industrial","industry":"Building Materials","condition":28,"value":50000,"cost":28000,"restoration_cost":28000,"income":2600,"owned":false,"active":false,"level":1,"inputs":{},"input_need":{"materials":2,"fuel":1},"unlock_rep":35}
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

# Transitional runtime binding. When present, resource mutations use GameState as the
# durable authority and this node is refreshed as a runtime projection.
var game_state = null

func _ready() -> void:
    _normalize_all()

func bind_game_state(state) -> void:
    game_state = state
    if game_state != null and game_state.has_method("restore_expansion_runtime"):
        game_state.restore_expansion_runtime(self)

func _canonical_state_enabled() -> bool:
    return game_state != null and game_state.has_method("get_value") and game_state.has_method("set_value")

func _normalize_all() -> void:
    for p in properties:
        p["condition"] = int(p.get("condition", 0)); p["value"] = int(p.get("value", 0))
        p["restoration_cost"] = int(p.get("restoration_cost", p.get("cost", 0)))
        p["cost"] = int(p.get("cost", p["restoration_cost"])); p["income"] = int(p.get("income", 0))
        p["level"] = max(1, int(p.get("level", 1))); p["owned"] = bool(p.get("owned", false))
        p["active"] = bool(p.get("active", p["owned"]))
        p["stock"] = max(0, int(p.get("stock", 0))); p["price"] = clamp(int(p.get("price", 100)), 50, 250)
        p["quality"] = clamp(int(p.get("quality", 60)), 30, 100); p["employees"] = max(1, int(p.get("employees", 1)))
        if not p.has("inputs") or not (p["inputs"] is Dictionary): p["inputs"] = {}
        if not p.has("input_need") or not (p["input_need"] is Dictionary): p["input_need"] = {}
        p["unlock_rep"] = int(p.get("unlock_rep", 10)); p["unlocked"] = bool(p.get("unlocked", false))
        if not p.has("industry") or String(p["industry"]).is_empty():
            match String(p.get("type", "")):
                "Residential": p["industry"] = "Housing"
                "Retail": p["industry"] = "Consumer Goods"
                "Industrial": p["industry"] = "Building Materials"
                _: p["industry"] = "General"
        for resource in p["input_need"]:
            p["inputs"][resource] = max(0, int(p["inputs"].get(resource, 0)))
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
    var site: Dictionary = properties[index]
    if not bool(site.get("unlocked", true)): return {"ok":false,"cost":0,"message":"More reputation is required to access this property."}
    if bool(site["owned"]): return {"ok":false,"cost":0,"message":"Already owned."}
    var cost: int = int(site["restoration_cost"])
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Restoration requires $%d." % cost}
    site["owned"] = true; site["active"] = true; site["condition"] = 100
    restored_count += 1; reputation += 5
    return {"ok":true,"cost":cost,"message":"%s restored and acquired." % site["name"]}

func buy_resource_site(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size(): return {"ok":false,"cost":0,"message":"Unknown resource site."}
    var site: Dictionary = resource_sites[index]
    var cost: int = int(site["cost"])
    if _canonical_state_enabled():
        var canonical_cash := int(game_state.get_value(["expansion", "cash"], 0))
        if bool(site.get("owned", false)): return {"ok":false,"cost":0,"message":"Already owned."}
        if canonical_cash < cost: return {"ok":false,"cost":cost,"message":"Purchase requires $%d." % cost}
        if not ExpansionState.record_resource_purchase(game_state, index, cost, 2):
            return {"ok":false,"cost":cost,"message":"Resource site purchase could not be completed."}
        game_state.restore_expansion_runtime(self)
        return {"ok":true,"cost":cost,"message":"%s acquired. Generate its resource to build network stock." % site["name"]}
    if bool(site["owned"]): return {"ok":false,"cost":0,"message":"Already owned."}
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
    var profit: int = revenue - expense
    day += 1; population += restored_count * 2
    return {"revenue":revenue,"expense":expense,"profit":profit,"cash":cash + profit,"day":day,"businesses":businesses}

func upgrade_property(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size() or not bool(properties[index]["owned"]): return {"ok":false,"cost":0,"message":"Own the property first."}
    var site: Dictionary = properties[index]; var cost: int = 7000 * int(site["level"])
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Upgrade requires $%d." % cost}
    site["level"] += 1; site["income"] += 500; site["value"] += 5000
    management_level = max(management_level, int(properties.size() / 2))
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [site["name"],site["level"]]}

func generate_resource(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size(): return {"ok":false,"output":0,"message":"Unknown resource site."}
    var site: Dictionary = resource_sites[index]
    if _canonical_state_enabled():
        if not bool(site.get("owned", false)): return {"ok":false,"output":0,"message":"Own the resource site first."}
        var generated: Dictionary = ExpansionState.record_resource_generation(game_state, index)
        if not bool(generated.get("ok", false)): return {"ok":false,"output":0,"message":"Resource generation could not be completed."}
        game_state.restore_expansion_runtime(self)
        return {"ok":true,"output":int(generated.get("output", 0)),"message":"%s generated %d %s. Stock: %d." % [site["name"],int(generated.get("output", 0)),site["resource"],int(generated.get("stock", 0))]}
    if not bool(site["owned"]): return {"ok":false,"output":0,"message":"Own the resource site first."}
    var output: int = int(site["output"]) * int(site["level"])
    site["stock"] += output
    return {"ok":true,"output":output,"message":"%s generated %d %s. Stock: %d." % [site["name"],output,site["resource"],site["stock"]]}

func harvest_resource(index: int) -> Dictionary: return generate_resource(index)

func produce(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"output":0,"message":"Unknown business."}
    var p: Dictionary = properties[index]
    if not bool(p["owned"]): return {"ok":false,"output":0,"message":"Own the business first."}
    if not bool(p.get("active", true)): return {"ok":false,"output":0,"message":"Business is paused."}
    if p["input_need"].is_empty():
        p["stock"] = int(p.get("stock", 0)) + 1
        return {"ok":true,"output":1,"message":"%s completed one operating cycle." % p["name"]}
    for resource in p["input_need"]:
        if int(p["inputs"].get(resource, 0)) < int(p["input_need"][resource]): return {"ok":false,"output":0,"message":"%s needs more %s before production." % [p["name"],resource]}
    for resource in p["input_need"]: p["inputs"][resource] = int(p["inputs"].get(resource, 0)) - int(p["input_need"][resource])
    var output: int = max(1, int(p["level"])); p["stock"] = int(p.get("stock", 0)) + output
    p["quality"] = clamp(int(p.get("quality", 60)) + randi_range(-2, 3), 30, 100)
    return {"ok":true,"output":output,"message":"%s produced %d units at quality %d." % [p["name"],output,int(p["quality"])]}

func sell(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"revenue":0,"profit":0,"message":"Unknown business."}
    var p: Dictionary = properties[index]; var stock: int = int(p.get("stock", 0))
    if stock <= 0: return {"ok":false,"revenue":0,"profit":0,"message":"%s has no finished stock to sell." % p["name"]}
    var price: int = int(p.get("price", 100)); var revenue: int = stock * price; var operating_cost: int = max(100, int(p["income"]) / 5); var profit: int = revenue - operating_cost
    p["stock"] = 0
    return {"ok":true,"revenue":revenue,"profit":profit,"message":"%s sold %d units for $%d." % [p["name"],stock,revenue]}

func hire(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size() or not bool(properties[index]["owned"]): return {"ok":false,"cost":0,"message":"Own the business first."}
    var p: Dictionary = properties[index]; var employees: int = int(p.get("employees", 1)); var cost: int = 900 + employees * 250
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Hiring requires $%d." % cost}
    p["employees"] = employees + 1; p["income"] = int(p["income"]) + 180
    return {"ok":true,"cost":cost,"message":"%s hired employee %d." % [p["name"],employees + 1]}

func change_price(index: int, delta: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"message":"Unknown business."}
    var p: Dictionary = properties[index]; var price: int = clamp(int(p.get("price", 100)) + delta, 50, 250); p["price"] = price
    return {"ok":true,"message":"%s selling price is now $%d." % [p["name"],price]}

func toggle_active(index: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"message":"Unknown business."}
    var p: Dictionary = properties[index]
    if not bool(p["owned"]): return {"ok":false,"message":"Own the business first."}
    p["active"] = not bool(p.get("active", true)); return {"ok":true,"message":"%s is now %s." % [p["name"],"open" if p["active"] else "paused"]}

func transfer_core_goods(index: int, amount: int, available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"moved":0,"message":"Unknown business."}
    var p: Dictionary = properties[index]
    if not bool(p["owned"]): return {"ok":false,"moved":0,"message":"Own the business first."}
    var moved: int = min(max(0, amount), max(0, available))
    if moved <= 0: return {"ok":false,"moved":0,"message":"No finished goods are available."}
    p["inputs"]["goods"] = int(p["inputs"].get("goods", 0)) + moved; p["input_need"]["goods"] = max(1, int(p["input_need"].get("goods", 0)))
    return {"ok":true,"moved":moved,"message":"Moved %d finished goods into %s." % [moved,p["name"]]}

func management_upgrade(cash_available: int) -> Dictionary:
    var cost: int = 12000 * (management_level + 1)
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"HQ management upgrade requires $%d." % cost}
    management_level += 1; management_overhead = management_level * 350
    return {"ok":true,"cost":cost,"message":"Headquarters management upgraded to level %d." % management_level}

func upgrade_resource_site(index: int, cash_available: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= resource_sites.size(): return {"ok":false,"cost":0,"message":"Unknown resource site."}
    var site: Dictionary = resource_sites[index]
    var cost: int = 9000 * int(site["level"])
    if _canonical_state_enabled():
        if not bool(site.get("owned", false)): return {"ok":false,"cost":0,"message":"Own the resource site first."}
        var canonical_cash := int(game_state.get_value(["expansion", "cash"], 0))
        if canonical_cash < cost: return {"ok":false,"cost":cost,"message":"Resource upgrade requires $%d." % cost}
        if not ExpansionState.record_resource_upgrade(game_state, index, cost, 2, -1):
            return {"ok":false,"cost":cost,"message":"Resource upgrade could not be completed."}
        game_state.restore_expansion_runtime(self)
        return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [site["name"],int(site["level"]) + 1]}
    if not bool(site["owned"]): return {"ok":false,"cost":0,"message":"Own the resource site first."}
    if cash_available < cost: return {"ok":false,"cost":cost,"message":"Resource upgrade requires $%d." % cost}
    site["level"] += 1; site["output"] += 2; site["risk"] = max(3, int(site["risk"]) - 1)
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [site["name"],site["level"]]}

func supply_business(index: int, resource: String, amount: int) -> Dictionary:
    _normalize_all()
    if index < 0 or index >= properties.size(): return {"ok":false,"moved":0,"message":"Unknown business."}
    var p: Dictionary = properties[index]
    if not bool(p["owned"]): return {"ok":false,"moved":0,"message":"Own the business first."}
    if not p["input_need"].has(resource): return {"ok":false,"moved":0,"message":"%s does not use %s." % [p["name"],resource]}
    var need: int = max(0, amount)
    if need <= 0: return {"ok":false,"moved":0,"message":"Supply amount must be positive."}
    for site in resource_sites:
        if bool(site["owned"]) and String(site["resource"]) == resource:
            var moved: int = min(need, int(site["stock"]))
            if moved <= 0: continue
            site["stock"] -= moved; p["inputs"][resource] = int(p["inputs"].get(resource, 0)) + moved
            return {"ok":true,"moved":moved,"message":"Moved %d %s from %s to %s." % [moved,resource,site["name"],p["name"]]}
    return {"ok":false,"moved":0,"message":"No owned stock is available for %s." % resource}

func get_summary() -> Dictionary:
    _normalize_all()
    return {"day":day,"cash":cash,"reputation":reputation,"population":population,"restored_count":restored_count,"properties":properties,"resource_sites":resource_sites,"management_level":management_level,"management_overhead":management_overhead}