extends RefCounted
class_name RenewEconomy

var resources := {
    "materials": {"price": 45, "stock": 100, "base": 45},
    "packaging": {"price": 20, "stock": 140, "base": 20},
    "fuel": {"price": 30, "stock": 180, "base": 30}
}

var market_multipliers := {
    "materials": 1.0,
    "packaging": 1.0,
    "fuel": 1.0
}

var suppliers := {
    "materials": [
        {"name":"Harbor Supply Co.","reliability":82,"markup":1.00},
        {"name":"Atlas Bulk", "reliability":68,"markup":0.88},
        {"name":"Greenline Materials", "reliability":94,"markup":1.16}
    ],
    "packaging": [
        {"name":"Metro Pack","reliability":91,"markup":1.05},
        {"name":"BoxWorks","reliability":76,"markup":0.91},
        {"name":"Prime Wrap","reliability":97,"markup":1.18}
    ],
    "fuel": [
        {"name":"Independent Fuel","reliability":68,"markup":0.95},
        {"name":"National Energy","reliability":88,"markup":1.08},
        {"name":"RapidFuel","reliability":58,"markup":0.78}
    ]
}

func supplier_for(resource: String, choice: int = 0) -> Dictionary:
    if not suppliers.has(resource): return {}
    var list: Array = suppliers[resource]
    return list[clamp(choice, 0, list.size() - 1)]

func set_market_modifier(resource: String, multiplier: float) -> void:
    if market_multipliers.has(resource):
        market_multipliers[resource] = clamp(multiplier, 0.65, 1.60)

func clear_market_modifiers() -> void:
    for resource in market_multipliers:
        market_multipliers[resource] = 1.0

func quote(resource: String, amount: int, choice: int = 0) -> Dictionary:
    if not resources.has(resource) or amount <= 0:
        return {"ok":false,"cost":0,"supplier":"Unknown"}
    var supplier := supplier_for(resource, choice)
    if supplier.is_empty(): return {"ok":false,"cost":0,"supplier":"Unknown"}
    var market_factor := float(market_multipliers.get(resource, 1.0))
    var cost := int(round(float(resources[resource]["price"]) * amount * float(supplier["markup"]) * market_factor))
    return {"ok":true,"cost":cost,"supplier":supplier["name"],"reliability":supplier["reliability"],"market_factor":market_factor}

func buy_resource(resource: String, amount: int, cash: int, choice: int = 0) -> Dictionary:
    var q := quote(resource, amount, choice)
    if not q["ok"] or cash < q["cost"]: return {"ok":false,"cost":q["cost"],"amount":0,"supplier":q.get("supplier","Unknown")}
    var supplier := supplier_for(resource, choice)
    if randi_range(1,100) > int(supplier["reliability"]):
        return {"ok":false,"cost":0,"amount":0,"supplier":supplier["name"],"failed":true}
    resources[resource]["stock"] += amount
    return {"ok":true,"cost":q["cost"],"amount":amount,"supplier":supplier["name"]}

# Atomic multi-resource order. Either every requested delivery succeeds or no
# market stock changes. This prevents a failed third delivery from leaving the
# company with only the first two inputs of an order.
func buy_bundle(orders: Array, cash: int, choice: int = 0) -> Dictionary:
    var total := 0
    var quotes: Array = []
    for order in orders:
        if not (order is Dictionary):
            return {"ok":false,"cost":0,"delivered":[],"supplier":"Unknown","failed":true}
        var resource := String(order.get("resource", ""))
        var amount := int(order.get("amount", 0))
        var q := quote(resource, amount, choice)
        if not q["ok"]:
            return {"ok":false,"cost":0,"delivered":[],"supplier":q.get("supplier","Unknown"),"failed":true}
        total += int(q["cost"])
        quotes.append(q)
    if cash < total:
        return {"ok":false,"cost":total,"delivered":[],"supplier":"Multiple suppliers","failed":false}

    # Validate every reliability check before mutating any resource stock.
    for i in range(orders.size()):
        var resource := String(orders[i]["resource"])
        var supplier := supplier_for(resource, choice)
        if randi_range(1,100) > int(supplier["reliability"]):
            return {"ok":false,"cost":0,"delivered":[],"supplier":supplier["name"],"failed":true}

    var delivered: Array = []
    for i in range(orders.size()):
        var resource := String(orders[i]["resource"])
        var amount := int(orders[i]["amount"])
        resources[resource]["stock"] += amount
        delivered.append({"resource":resource,"amount":amount,"cost":int(quotes[i]["cost"]),"supplier":quotes[i]["supplier"]})
    return {"ok":true,"cost":total,"delivered":delivered,"supplier":"Bundle","failed":false}

func end_market_day() -> void:
    for key in resources:
        var data = resources[key]
        var scarcity := clamp((80.0 - float(data["stock"])) / 100.0, -0.5, 0.7)
        var swing := randi_range(-4,6) + int(round(scarcity * 6.0))
        data["price"] = clamp(int(data["price"]) + swing, 10, 100)
        data["stock"] = max(15, int(data["stock"]) + randi_range(-12,20))
