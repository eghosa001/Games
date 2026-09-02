extends RefCounted
class_name RenewCompetitors

# Rivals are persistent economic actors. Their district presence creates
# pressure that changes as the player's empire grows.
var rivals := [
    {"name":"The Giant","cash":500000,"price":105,"relationship":-20,"stance":"Aggressive","strength":"capital","districts":[0],"presence":1,"supplier_pressure":0,"offer_cooldown":0},
    {"name":"The Specialist","cash":90000,"price":118,"relationship":5,"stance":"Efficient","strength":"quality","districts":[1],"presence":1,"supplier_pressure":0,"offer_cooldown":0},
    {"name":"The Network","cash":180000,"price":125,"relationship":15,"stance":"Connected","strength":"suppliers","districts":[2],"presence":1,"supplier_pressure":1,"offer_cooldown":0}
]

func _normalize() -> void:
    for rival in rivals:
        if not rival.has("districts"): rival["districts"] = [0]
        if not rival.has("presence"): rival["presence"] = 1
        if not rival.has("supplier_pressure"): rival["supplier_pressure"] = 0
        if not rival.has("offer_cooldown"): rival["offer_cooldown"] = 0

func daily_update(day: int) -> Array[String]:
    _normalize()
    var news: Array[String] = []
    for rival in rivals:
        if rival["name"] == "The Giant":
            if day % 3 == 0:
                rival["price"] = max(82, int(rival["price"]) - 4)
                news.append("The Giant cuts prices to $%d." % rival["price"])
            else:
                rival["cash"] += 2500
        elif rival["name"] == "The Specialist" and day % 4 == 0:
            rival["price"] = max(92, int(rival["price"]) - 2)
            news.append("The Specialist improves efficiency and lowers prices.")
        elif rival["name"] == "The Network" and day % 5 == 0:
            rival["supplier_pressure"] = min(3, int(rival["supplier_pressure"]) + 1)
            news.append("The Network locks down a major supplier agreement.")
        if int(rival["offer_cooldown"]) > 0: rival["offer_cooldown"] = int(rival["offer_cooldown"]) - 1
    return news

func strategic_update(day: int, selected_district: int, reputation: int) -> Array[String]:
    _normalize()
    var news: Array[String] = []
    for i in range(rivals.size()):
        var rival = rivals[i]
        var districts: Array = rival["districts"]
        if day % (6 + i * 2) == 0 and districts.size() < 4:
            var target := (int(districts.back()) + 1) % 4
            if target not in districts:
                districts.append(target)
                rival["presence"] = min(3, int(rival["presence"]) + 1)
                news.append("%s expands into %s. Competition is tightening." % [rival["name"], _district_name(target)])
        if selected_district in districts:
            if i == 0 and day % 4 == 0:
                rival["price"] = max(78, int(rival["price"]) - 2)
                news.append("PRICE WAR: The Giant is undercutting businesses in your district.")
            elif i == 2 and day % 5 == 0:
                rival["supplier_pressure"] = min(3, int(rival["supplier_pressure"]) + 1)
                news.append("SUPPLIER WAR: The Network is competing for scarce inputs in your district.")
            elif i == 1 and day % 7 == 0:
                news.append("SPECIALIST PUSH: The Specialist is winning premium customers nearby.")
        if reputation >= 35 and int(rival["relationship"]) < 0 and int(rival["offer_cooldown"]) == 0:
            rival["offer_cooldown"] = 10
            news.append("BOARDROOM: %s is considering an acquisition approach against your company." % rival["name"])
    return news

func _district_name(index: int) -> String:
    var names := ["Old Market","Industrial Belt","River Port","North Growth Corridor"]
    return names[index] if index >= 0 and index < names.size() else "Unknown District"

func district_pressure(district_index: int) -> float:
    _normalize()
    var pressure := 0.0
    for rival in rivals:
        if district_index in rival["districts"]:
            pressure += 0.05 * float(rival["presence"])
    return pressure

func supplier_pressure(district_index: int) -> int:
    _normalize()
    var pressure := 0
    for rival in rivals:
        if district_index in rival["districts"]:
            pressure += int(rival["supplier_pressure"])
    return pressure

func improve_relationship(index: int) -> String:
    if index < 0 or index >= rivals.size(): return "Unknown company."
    rivals[index]["relationship"] = min(100, int(rivals[index]["relationship"]) + 5)
    return "Relationship with %s improved to %d." % [rivals[index]["name"], rivals[index]["relationship"]]

func offer_alliance(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    if int(r["relationship"]) >= 35:
        r["relationship"] = min(100, int(r["relationship"]) + 3)
        return {"ok":true,"message":"%s accepted. Alliance benefits are active." % r["name"]}
    r["relationship"] = min(100, int(r["relationship"]) + 10)
    return {"ok":false,"message":"%s wants stronger trust before an alliance." % r["name"]}

func alliance_bonus(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size() or int(rivals[index]["relationship"]) < 35: return {"discount":0.0,"sales":0.0,"risk":0.0}
    match index:
        0: return {"discount":0.08,"sales":0.02,"risk":0.0}
        1: return {"discount":0.02,"sales":0.10,"risk":0.0}
        _: return {"discount":0.12,"sales":0.03,"risk":0.15}
