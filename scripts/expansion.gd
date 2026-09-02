extends RefCounted
class_name RenewExpansion

# Each expansion is a real business with its own workforce, inventory,
# selling price, operating status and management decisions.
var properties := [
    {"name":"Riverside Retail Unit","type":"Retail","industry":"Consumer Goods","cost":18000,"potential":90,"owned":false,"level":1,"employees":2,"price":145,"stock":0,"active":true,"quality":60,"last_profit":0},
    {"name":"Brickworks Yard","type":"Factory","industry":"Building Materials","cost":42000,"potential":125,"owned":false,"level":1,"employees":4,"price":175,"stock":0,"active":true,"quality":60,"last_profit":0},
    {"name":"Cold Storage Depot","type":"Warehouse","industry":"Food Processing","cost":30000,"potential":110,"owned":false,"level":1,"employees":3,"price":155,"stock":0,"active":true,"quality":60,"last_profit":0}
]
var unlocked := 1

func unlock_from_reputation(reputation: int) -> void:
    unlocked = clamp(1 + int(reputation / 15), 1, properties.size())

func buy(index: int, cash: int) -> Dictionary:
    if index < 0 or index >= unlocked:
        return {"ok":false,"cost":0,"message":"This opportunity is not unlocked yet."}
    var p = properties[index]
    if p["owned"]:
        return {"ok":false,"cost":0,"message":"You already own this property."}
    if cash < p["cost"]:
        return {"ok":false,"cost":p["cost"],"message":"Not enough capital."}
    p["owned"] = true
    p["stock"] = 0
    p["active"] = true
    return {"ok":true,"cost":p["cost"],"message":"Acquired %s." % p["name"]}

func selected(index: int) -> Dictionary:
    if index < 0 or index >= properties.size():
        return {}
    return properties[index]

func produce(index: int) -> Dictionary:
    if index < 0 or index >= properties.size(): return {"ok":false,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"message":"Own the business first."}
    if not p["active"]: return {"ok":false,"message":"Business is paused."}
    var output := 8 + int(p["employees"]) * 3 + int(p["level"]) * 4
    if p["type"] == "Retail": output += 4
    p["stock"] += output
    p["quality"] = clamp(int(p["quality"]) + randi_range(-2,4), 35, 100)
    return {"ok":true,"output":output,"quality":p["quality"],"message":"%s produced %d units." % [p["name"],output]}

func sell(index: int) -> Dictionary:
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
    var profit := revenue - wages - overhead
    p["stock"] -= units
    p["last_profit"] = profit
    return {"ok":true,"units":units,"revenue":revenue,"profit":profit,"message":"%s sold %d units for $%d." % [p["name"],units,revenue]}

func hire(index: int, cash: int) -> Dictionary:
    if index < 0 or index >= properties.size(): return {"ok":false,"cost":0,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"cost":0,"message":"Own the business first."}
    var cost := 1500 + int(p["employees"]) * 300
    if cash < cost: return {"ok":false,"cost":cost,"message":"Hiring requires $%d." % cost}
    p["employees"] += 1
    return {"ok":true,"cost":cost,"message":"%s hired another employee (%d total)." % [p["name"],p["employees"]]}

func change_price(index: int, delta: int) -> Dictionary:
    if index < 0 or index >= properties.size(): return {"ok":false,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"message":"Own the business first."}
    p["price"] = clamp(int(p["price"]) + delta, 70, 240)
    return {"ok":true,"message":"%s price is now $%d." % [p["name"],p["price"]]}

func toggle_active(index: int) -> Dictionary:
    if index < 0 or index >= properties.size(): return {"ok":false,"message":"Unknown business."}
    var p = properties[index]
    if not p["owned"]: return {"ok":false,"message":"Own the business first."}
    p["active"] = not p["active"]
    return {"ok":true,"message":"%s is now %s." % [p["name"],"OPEN" if p["active"] else "PAUSED"]}

func upgrade(index: int, cash: int) -> Dictionary:
    if index < 0 or index >= properties.size() or not properties[index]["owned"]:
        return {"ok":false,"cost":0,"message":"Own the business first."}
    var p = properties[index]
    var cost := 7000 * int(p["level"])
    if cash < cost: return {"ok":false,"cost":cost,"message":"Upgrade requires $%d." % cost}
    p["level"] += 1
    p["potential"] += 10
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [p["name"],p["level"]]}

func operate_day() -> Dictionary:
    # Automatic sales are now a fallback for businesses the player did not
    # manually manage. Manual production/sales still use the same business state.
    var income := 0
    var profit := 0
    var count := 0
    var report: Array[String] = []
    for p in properties:
        if not p["owned"] or not p["active"]: continue
        count += 1
        if int(p["stock"]) <= 0:
            var output := 8 + int(p["employees"]) * 2 + int(p["level"]) * 3
            p["stock"] += output
        var result := sell(properties.find(p))
        var net := int(result["profit"]) if result["ok"] else 0
        income += int(result["revenue"]) if result["ok"] else 0
        profit += net
        report.append("%s: $%d net" % [p["name"],net])
    return {"businesses":count,"income":income,"profit":profit,"report":report}
