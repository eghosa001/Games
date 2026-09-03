extends RefCounted
class_name RenewDistricts

# Regional expansion: businesses gain strategic advantages by operating in
# districts with different demand, logistics and competitive pressure.
var districts: Variant = [
    {"name":"Old Market","tier":1,"unlocked":true,"demand":1.15,"logistics":1.10,"competition":0.85,"reputation":0,"special":"Retail demand"},
    {"name":"Industrial Belt","tier":2,"unlocked":false,"demand":1.05,"logistics":0.90,"competition":1.15,"reputation":15,"special":"Factory efficiency"},
    {"name":"River Port","tier":3,"unlocked":false,"demand":1.20,"logistics":0.80,"competition":1.05,"reputation":30,"special":"Cheap inbound logistics"},
    {"name":"North Growth Corridor","tier":4,"unlocked":false,"demand":1.35,"logistics":1.00,"competition":1.25,"reputation":50,"special":"High demand"}
]
var selected: Variant = 0

func update_unlocks(reputation: int) -> void:
    for d in districts:
        d["unlocked"] = reputation >= int(d["reputation"])

func select(index: int) -> Dictionary:
    if index < 0 or index >= districts.size(): return {"ok":false,"message":"Unknown district."}
    if not districts[index]["unlocked"]:
        return {"ok":false,"message":"Reach %d reputation to unlock %s." % [districts[index]["reputation"],districts[index]["name"]]}
    selected = index
    return {"ok":true,"message":"District selected: %s." % districts[index]["name"]}

func current() -> Dictionary:
    return districts[selected]

func business_multiplier(industry: String) -> float:
    var d = current()
    var mult: Variant = float(d["demand"])
    if d["name"] == "Old Market" and industry == "Consumer Goods": mult += 0.15
    if d["name"] == "Industrial Belt" and industry == "Building Materials": mult += 0.18
    if d["name"] == "River Port" and industry == "Food Processing": mult += 0.12
    return mult

func logistics_cost(base: int) -> int:
    return max(1, int(round(float(base) * float(current()["logistics"]))))

func competition_pressure() -> float:
    return float(current()["competition"])
