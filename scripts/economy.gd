extends RefCounted
class_name RenewEconomy

var resources := {
    "materials": {"price": 45, "stock": 100, "trend": 0},
    "packaging": {"price": 20, "stock": 140, "trend": 0},
    "fuel": {"price": 30, "stock": 180, "trend": 0}
}

var suppliers := [
    {"name": "Harbor Supply Co.", "resource": "materials", "reliability": 82, "markup": 1.0},
    {"name": "Metro Pack", "resource": "packaging", "reliability": 91, "markup": 1.05},
    {"name": "Independent Fuel", "resource": "fuel", "reliability": 68, "markup": 0.95}
]

func buy_resource(resource: String, amount: int, cash: int) -> Dictionary:
    if not resources.has(resource):
        return {"ok": false, "cost": 0, "amount": 0}
    var price: int = resources[resource]["price"]
    var cost := price * amount
    if cash < cost:
        return {"ok": false, "cost": cost, "amount": 0}
    resources[resource]["stock"] += amount
    return {"ok": true, "cost": cost, "amount": amount}

func end_market_day() -> void:
    for key in resources:
        var data = resources[key]
        var swing := randi_range(-5, 7)
        data["trend"] = swing
        data["price"] = clamp(int(data["price"]) + swing, 12, 90)
        data["stock"] = max(20, int(data["stock"]) + randi_range(-18, 24))

func supplier_for(resource: String) -> Dictionary:
    for supplier in suppliers:
        if supplier["resource"] == resource:
            return supplier
    return {}
