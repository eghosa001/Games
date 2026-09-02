extends RefCounted
class_name RenewExpansion

var properties := [
    {"name":"Riverside Retail Unit", "type":"Retail", "cost":18000, "potential":90, "owned":false},
    {"name":"Brickworks Yard", "type":"Factory", "cost":42000, "potential":125, "owned":false},
    {"name":"Cold Storage Depot", "type":"Warehouse", "cost":30000, "potential":110, "owned":false}
]

var unlocked := 0

func unlock_from_reputation(reputation: int) -> void:
    unlocked = clamp(1 + int(reputation / 15), 1, properties.size())

func buy(index: int, cash: int) -> Dictionary:
    if index < 0 or index >= unlocked:
        return {"ok":false,"cost":0,"message":"This opportunity is not unlocked yet."}
    var property = properties[index]
    if property["owned"]:
        return {"ok":false,"cost":0,"message":"You already own this property."}
    if cash < property["cost"]:
        return {"ok":false,"cost":property["cost"],"message":"Not enough capital."}
    property["owned"] = true
    return {"ok":true,"cost":property["cost"],"message":"Acquired %s." % property["name"]}
