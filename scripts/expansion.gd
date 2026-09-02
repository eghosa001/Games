extends RefCounted
class_name RenewExpansion

var properties := [
    {"name":"Riverside Retail Unit","type":"Retail","industry":"Consumer Goods","cost":18000,"potential":90,"owned":false,"level":1,"employees":2,"price":145,"stock":0},
    {"name":"Brickworks Yard","type":"Factory","industry":"Building Materials","cost":42000,"potential":125,"owned":false,"level":1,"employees":4,"price":175,"stock":0},
    {"name":"Cold Storage Depot","type":"Warehouse","industry":"Food Processing","cost":30000,"potential":110,"owned":false,"level":1,"employees":3,"price":155,"stock":0}
]
var unlocked := 1

func unlock_from_reputation(reputation: int) -> void:
    unlocked = clamp(1 + int(reputation / 15), 1, properties.size())

func buy(index: int, cash: int) -> Dictionary:
    if index < 0 or index >= unlocked: return {"ok":false,"cost":0,"message":"This opportunity is not unlocked yet."}
    var p = properties[index]
    if p["owned"]: return {"ok":false,"cost":0,"message":"You already own this property."}
    if cash < p["cost"]: return {"ok":false,"cost":p["cost"],"message":"Not enough capital."}
    p["owned"] = true
    return {"ok":true,"cost":p["cost"],"message":"Acquired %s." % p["name"]}

func operate_day() -> Dictionary:
    var income := 0
    var profit := 0
    var count := 0
    var report: Array[String] = []
    for p in properties:
        if not p["owned"]: continue
        count += 1
        var demand := int(p["potential"]) + int(p["level"]) * 8
        var units := min(demand, 18 + int(p["employees"]) * 5 + int(p["level"]) * 4)
        var sales := units * int(p["price"])
        var wages := int(p["employees"]) * 160
        var overhead := 350 + int(p["level"]) * 120
        var net := sales - wages - overhead
        income += sales; profit += net
        report.append("%s: %d sold, $%d net" % [p["name"], units, net])
    return {"businesses":count,"income":income,"profit":profit,"report":report}

func upgrade(index: int, cash: int) -> Dictionary:
    if index < 0 or index >= properties.size() or not properties[index]["owned"]: return {"ok":false,"cost":0,"message":"Own the business first."}
    var p = properties[index]
    var cost := 7000 * int(p["level"])
    if cash < cost: return {"ok":false,"cost":cost,"message":"Upgrade requires $%d." % cost}
    p["level"] += 1
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [p["name"],p["level"]]}
