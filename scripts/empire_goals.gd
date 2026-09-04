extends Node

# Long-term company objectives. These create a reason to keep playing after the
# first business is profitable and turn the simulation into a visible campaign.
var game: Node
var claimed: Variant = {}
var goals: Variant = [
    {"id":"restore","title":"SAVE THE WAREHOUSE","cash":500,"rep":2,"text":"Complete the first restoration."},
    {"id":"profit10","title":"TEN THOUSAND PROFIT","cash":1500,"rep":3,"text":"Reach $10,000 total operating profit."},
    {"id":"team","title":"BUILD A TEAM","cash":1000,"rep":2,"text":"Grow the core company to 5 employees."},
    {"id":"expansion","title":"SECOND ASSET","cash":2000,"rep":4,"text":"Acquire your first expansion business or resource site."},
    {"id":"resource","title":"OWN THE SUPPLY","cash":2500,"rep":4,"text":"Own a resource site and start controlling an input."},
    {"id":"alliance","title":"FIND AN ALLY","cash":1500,"rep":4,"text":"Turn a rival relationship into an alliance."},
    {"id":"regional","title":"ENTER A NEW REGION","cash":3000,"rep":5,"text":"Establish a second regional foothold."},
    {"id":"empire","title":"CONNECTED EMPIRE","cash":5000,"rep":8,"text":"Own at least three expansion/resource assets."}
]

func _ready() -> void:
    game = get_tree().root.get_node_or_null("Renew")
    _load_state()

func _process(_delta: float) -> void:
    if game == null:
        return
    for goal in goals:
        var id: Variant = String(goal["id"])
        if bool(claimed.get(id, false)):
            continue
        if _reached(id):
            _claim(goal)

func _reached(id: String) -> bool:
    match id:
        "restore": return str(game.stage) == "Operational"
        "profit10": return int(game.total_profit) >= 10000
        "team": return int(game.employees) >= 5
        "expansion":
            for item in game.expansion.properties:
                if bool(item.get("owned", false)):
                    return true
            for item in game.expansion.resource_sites:
                if bool(item.get("owned", false)):
                    return true
        "resource":
            for item in game.expansion.resource_sites:
                if bool(item.get("owned", false)):
                    return true
        "alliance":
            for rival in game.rivals.rivals:
                if bool(rival.get("allied", false)):
                    return true
        "regional":
            var region = game.get_node_or_null("RegionController")
            if region != null:
                return int(region.regions.player_presence.count(1)) > 1
        "empire":
            var count: Variant = 0
            for item in game.expansion.properties:
                if bool(item.get("owned", false)): count += 1
            for item in game.expansion.resource_sites:
                if bool(item.get("owned", false)): count += 1
            return count >= 3
    return false

func _claim(goal: Dictionary) -> void:
    var id: Variant = String(goal["id"])
    claimed[id] = true
    game.cash += int(goal["cash"])
    game.reputation += int(goal["rep"])
    game._log("COMPANY GOAL: %s — %s" % [goal["title"], goal["text"]])
    game.message = "%s COMPLETE — +$%s and +%d reputation." % [goal["title"], game._money(int(goal["cash"])), int(goal["rep"])]
    _save_state()

func current_goal() -> Dictionary:
    for goal in goals:
        if not bool(claimed.get(String(goal["id"]), false)):
            return goal
    return {"title":"EMPIRE MASTERED","text":"Every V1 company objective is complete."}

func completed_count() -> int:
    var count: Variant = 0
    for goal in goals:
        if bool(claimed.get(String(goal["id"]), false)):
            count += 1
    return count

func _save_state() -> void:
    var state = get_node_or_null("/root/RenewGameState")
    if state != null:
        state.set_value("progression", "claimed_goals", claimed)

func _load_state() -> void:
    var state = get_node_or_null("/root/RenewGameState")
    if state != null:
        var saved = state.get_value("progression", "claimed_goals", {})
        if saved is Dictionary and not saved.is_empty():
            claimed = saved
