extends RefCounted
class_name RenewEvents

var events := [
    {"title":"Construction boom", "text":"Local demand for building materials rises.", "cash":1200, "rep":2},
    {"title":"Supplier disruption", "text":"A shipment is delayed. Operating costs increase today.", "cash":-900, "rep":0},
    {"title":"Big customer", "text":"A retailer offers a one-day bulk contract.", "cash":2500, "rep":3},
    {"title":"Equipment failure", "text":"Emergency repairs are required.", "cash":-1800, "rep":0},
    {"title":"Community recognition", "text":"Your restoration work attracts positive attention.", "cash":0, "rep":5}
]

func roll() -> Dictionary:
    return events[randi_range(0, events.size() - 1)]
