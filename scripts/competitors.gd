extends RefCounted
class_name RenewCompetitors

var rivals := [
    {"name": "The Giant", "cash": 500000, "price": 105, "relationship": -20, "stance": "Aggressive"},
    {"name": "The Specialist", "cash": 90000, "price": 118, "relationship": 5, "stance": "Efficient"},
    {"name": "The Network", "cash": 180000, "price": 125, "relationship": 15, "stance": "Connected"}
]

func daily_update(day: int) -> Array[String]:
    var news: Array[String] = []
    for rival in rivals:
        if rival["name"] == "The Giant" and day % 3 == 0:
            rival["price"] = max(80, int(rival["price"]) - 4)
            news.append("The Giant cut prices to $%d to squeeze smaller businesses." % rival["price"])
        elif rival["name"] == "The Specialist" and day % 4 == 0:
            rival["price"] = max(90, int(rival["price"]) - 2)
            news.append("The Specialist improved efficiency and lowered its market price.")
        elif rival["name"] == "The Network" and day % 5 == 0:
            news.append("The Network signed an exclusive supplier agreement in the district.")
    return news

func offer_alliance(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size():
        return {"ok": false, "message": "Unknown company."}
    var rival = rivals[index]
    if rival["relationship"] >= 30:
        return {"ok": true, "message": "%s accepted your alliance proposal." % rival["name"]}
    rival["relationship"] += 10
    return {"ok": false, "message": "%s wants stronger trust before an alliance." % rival["name"]}

func improve_relationship(index: int) -> String:
    if index < 0 or index >= rivals.size():
        return "Unknown company."
    var rival = rivals[index]
    rival["relationship"] = min(100, int(rival["relationship"]) + 5)
    return "Relationship with %s improved to %d." % [rival["name"], rival["relationship"]]
