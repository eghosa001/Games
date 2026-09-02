extends Node

# Milestone layer: gives the player long-term goals and memorable moments
# without replacing the simulation's existing economy.
var parent
var claimed := {}

var milestones := [
    {"id":"acquired","title":"FIRST ASSET","rep":2,"cash":0,"text":"You own something the market had written off."},
    {"id":"restored","title":"REBUILDER","rep":4,"cash":0,"text":"The warehouse is fully restored. Neglect became productive capital."},
    {"id":"opened","title":"FIRST BUSINESS","rep":3,"cash":0,"text":"RENEW Goods is operating. You have entered the market."},
    {"id":"profit","title":"PROFITABLE","rep":3,"cash":1000,"text":"Your first profitable operating day proves the model can work."},
    {"id":"regional","title":"GOING REGIONAL","rep":4,"cash":0,"text":"Your company now has a foothold beyond its original neighborhood."},
    {"id":"empire","title":"EMPIRE BUILDER","rep":8,"cash":2500,"text":"Multiple assets are working together. You are building an economic empire."}
]

func _ready() -> void:
    parent = get_parent()
    _load_state()

func _process(_delta: float) -> void:
    if parent == null:
        return
    _check_milestones()

func _check_milestones() -> void:
    for milestone in milestones:
        var id := String(milestone["id"])
        if bool(claimed.get(id, false)):
            continue
        var reached := false
        match id:
            "acquired": reached = bool(parent.owned)
            "restored": reached = str(parent.stage) == "Operational"
            "opened": reached = bool(parent.business_open)
            "profit": reached = int(parent.total_profit) > 0
            "regional":
                var region = parent.get_node_or_null("RegionController")
                if region != null:
                    reached = int(region.regions.player_presence.count(1)) > 1
            "empire":
                var owned_businesses := 0
                for p in parent.expansion.properties:
                    if bool(p.get("owned", false)): owned_businesses += 1
                for site in parent.expansion.resource_sites:
                    if bool(site.get("owned", false)): owned_businesses += 1
                reached = owned_businesses >= 3
        if reached:
            _claim(milestone)

func _claim(milestone: Dictionary) -> void:
    var id := String(milestone["id"])
    claimed[id] = true
    parent.reputation += int(milestone["rep"])
    parent.cash += int(milestone["cash"])
    parent._log("MILESTONE: %s — %s" % [milestone["title"], milestone["text"]])
    parent.message = "%s — %s" % [milestone["title"], milestone["text"]]
    _save_state()

func _save_state() -> void:
    var file := FileAccess.open("user://renew_milestones.json", FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(claimed))

func _load_state() -> void:
    if not FileAccess.file_exists("user://renew_milestones.json"):
        return
    var file := FileAccess.open("user://renew_milestones.json", FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        claimed = parsed
