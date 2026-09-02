extends RefCounted
class_name RenewCompetitors

# Persistent economic actors. Rivals expand, negotiate, compete and can become
# valuable partners or dangerous buyers as the player's empire grows.
var rivals := [
    {"name":"The Giant","cash":500000,"price":105,"relationship":-20,"stance":"Aggressive","strength":"capital","districts":[0],"presence":1,"supplier_pressure":0,"offer_cooldown":0,"deal":"none","deal_days":0,"retaliation":0},
    {"name":"The Specialist","cash":90000,"price":118,"relationship":5,"stance":"Efficient","strength":"quality","districts":[1],"presence":1,"supplier_pressure":0,"offer_cooldown":0,"deal":"none","deal_days":0,"retaliation":0},
    {"name":"The Network","cash":180000,"price":125,"relationship":15,"stance":"Connected","strength":"suppliers","districts":[2],"presence":1,"supplier_pressure":1,"offer_cooldown":0,"deal":"none","deal_days":0,"retaliation":0}
]

func _normalize() -> void:
    for rival in rivals:
        if not rival.has("districts"): rival["districts"] = [0]
        if not rival.has("presence"): rival["presence"] = 1
        if not rival.has("supplier_pressure"): rival["supplier_pressure"] = 0
        if not rival.has("offer_cooldown"): rival["offer_cooldown"] = 0
        if not rival.has("deal"): rival["deal"] = "none"
        if not rival.has("deal_days"): rival["deal_days"] = 0
        if not rival.has("retaliation"): rival["retaliation"] = 0

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
        if int(rival["retaliation"]) > 0:
            rival["retaliation"] = int(rival["retaliation"]) - 1
            if int(rival["retaliation"]) == 0: news.append("%s has cooled its retaliation campaign." % rival["name"])
        if int(rival["offer_cooldown"]) > 0: rival["offer_cooldown"] = int(rival["offer_cooldown"]) - 1
        if int(rival["deal_days"]) > 0:
            rival["deal_days"] = int(rival["deal_days"]) - 1
            if int(rival["deal_days"]) == 0:
                rival["deal"] = "none"
                news.append("%s strategic deal has expired." % rival["name"])
    return news

func strategic_update(day: int, selected_district: int, reputation: int) -> Array[String]:
    _normalize()
    var news: Array[String] = []
    for i in range(rivals.size()):
        var rival = rivals[i]
        var rival_districts: Array = rival["districts"]
        if day % (6 + i * 2) == 0 and rival_districts.size() < 4:
            var target := (int(rival_districts.back()) + 1) % 4
            if not rival_districts.has(target):
                rival_districts.append(target)
                rival["presence"] = min(3, int(rival["presence"]) + 1)
                news.append("%s expands into %s. Competition is tightening." % [rival["name"], _district_name(target)])
        if selected_district in rival_districts:
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

func retaliation_after_acquisition(index: int) -> Dictionary:
    _normalize()
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    var pressure_gain := 1 if index != 1 else 0
    r["retaliation"] = max(int(r["retaliation"]), 6)
    r["offer_cooldown"] = max(int(r["offer_cooldown"]), 6)
    r["relationship"] = max(-100, int(r["relationship"]) - 12)
    r["supplier_pressure"] = min(3, int(r["supplier_pressure"]) + pressure_gain)
    r["price"] = max(78, int(r["price"]) - (3 if index == 0 else 1))
    return {"ok":true,"message":"%s retaliated: competition intensified for the next several days." % r["name"]}

func competitive_status(index: int) -> Dictionary:
    _normalize()
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    return {"ok":true,"name":r["name"],"stance":r["stance"],"strength":r["strength"],"relationship":int(r["relationship"]),"presence":int(r["presence"]),"supplier_pressure":int(r["supplier_pressure"]),"retaliation_days":int(r["retaliation"]),"message":"%s — %s. Strength: %s. Presence %d." % [r["name"],r["stance"],r["strength"],int(r["presence"])]}

func _district_name(index: int) -> String:
    var names := ["Old Market","Industrial Belt","River Port","North Growth Corridor"]
    return names[index] if index >= 0 and index < names.size() else "Unknown District"

func district_pressure(district_index: int) -> float:
    _normalize()
    var pressure := 0.0
    for rival in rivals:
        if district_index in rival["districts"]:
            pressure += 0.05 * float(rival["presence"])
            if int(rival["retaliation"]) > 0: pressure += 0.025
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
        r["deal"] = "alliance"
        r["deal_days"] = 12
        return {"ok":true,"message":"%s accepted a 12-day strategic alliance." % r["name"]}
    r["relationship"] = min(100, int(r["relationship"]) + 10)
    return {"ok":false,"message":"%s wants stronger trust before an alliance." % r["name"]}

func propose_supply_deal(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    if int(r["relationship"]) < 25: return {"ok":false,"message":"Trust is too low for a supply deal."}
    if index != 2: return {"ok":false,"message":"%s is not a strong logistics partner." % r["name"]}
    r["deal"] = "supply"
    r["deal_days"] = 10
    r["supplier_pressure"] = max(0, int(r["supplier_pressure"]) - 1)
    r["relationship"] = min(100, int(r["relationship"]) + 4)
    return {"ok":true,"message":"The Network signed a 10-day supply agreement. Input pressure is reduced."}

func propose_customer_partnership(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    if int(r["relationship"]) < 25: return {"ok":false,"message":"Trust is too low for a customer partnership."}
    if index != 1: return {"ok":false,"message":"The Specialist prefers quality partnerships rather than customer distribution."}
    r["deal"] = "customer"
    r["deal_days"] = 10
    r["relationship"] = min(100, int(r["relationship"]) + 4)
    return {"ok":true,"message":"The Specialist signed a 10-day customer partnership. Premium demand increases."}

func reject_acquisition(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    r["offer_cooldown"] = 14
    r["relationship"] = max(-100, int(r["relationship"]) - 5)
    return {"ok":true,"message":"Acquisition rejected. %s will remember the decision." % r["name"]}

func negotiate_acquisition(index: int, player_cash: int, reputation: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    if reputation < 35: return {"ok":false,"message":"Your company needs 35 reputation to negotiate a major acquisition."}
    var cost := 45000 + int(r["presence"]) * 18000
    if int(r["relationship"]) < 10: cost += 15000
    if player_cash < cost: return {"ok":false,"message":"Negotiation requires $%s available capital." % _money(cost),"cost":cost}
    r["cash"] = max(0, int(r["cash"]) - cost / 2)
    r["presence"] = max(1, int(r["presence"]) - 1)
    r["offer_cooldown"] = 20
    r["relationship"] = min(50, int(r["relationship"]) + 8)
    return {"ok":true,"cost":cost,"message":"You acquired a strategic foothold from %s. Their remaining operations are still active." % r["name"]}

func alliance_bonus(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"discount":0.0,"sales":0.0,"risk":0.0}
    var r = rivals[index]
    if int(r["relationship"]) < 35 and r["deal"] == "none": return {"discount":0.0,"sales":0.0,"risk":0.0}
    match index:
        0: return {"discount":0.08,"sales":0.02,"risk":0.0}
        1: return {"discount":0.02,"sales":0.10,"risk":0.0}
        _: return {"discount":0.12,"sales":0.03,"risk":0.15}

func deal_bonus(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"sales":0.0,"discount":0.0,"supplier":0,"risk":0.0}
    var deal := str(rivals[index]["deal"])
    match deal:
        "supply": return {"sales":0.0,"discount":0.10,"supplier":-1,"risk":0.02}
        "customer": return {"sales":0.12,"discount":0.0,"supplier":0,"risk":0.02}
        "alliance": return {"sales":0.05,"discount":0.05,"supplier":0,"risk":0.03}
        _: return {"sales":0.0,"discount":0.0,"supplier":0,"risk":0.0}

func _money(value: int) -> String:
    return "%,d" % value
