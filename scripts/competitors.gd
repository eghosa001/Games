extends RefCounted
class_name RenewCompetitors

var rivals := [
    {"name":"The Giant","cash":500000,"price":105,"relationship":-20,"stance":"Aggressive","strength":"capital"},
    {"name":"The Specialist","cash":90000,"price":118,"relationship":5,"stance":"Efficient","strength":"quality"},
    {"name":"The Network","cash":180000,"price":125,"relationship":15,"stance":"Connected","strength":"suppliers"}
]

func daily_update(day: int) -> Array[String]:
    var news: Array[String] = []
    for rival in rivals:
        if rival["name"] == "The Giant":
            if day % 3 == 0: rival["price"] = max(82, int(rival["price"]) - 4); news.append("The Giant cuts prices to $%d." % rival["price"])
            else: rival["cash"] += 2500
        elif rival["name"] == "The Specialist" and day % 4 == 0:
            rival["price"] = max(92, int(rival["price"]) - 2); news.append("The Specialist improves efficiency and lowers prices.")
        elif rival["name"] == "The Network" and day % 5 == 0:
            news.append("The Network locks down a major supplier agreement.")
    return news

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
