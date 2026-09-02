extends Node

# Player-facing restoration strategy layer.
# Changes the economics of the first property without changing the core loop.
var game: Node
var selected := "Standard"
var applied := false

var plans := {
    "Budget": {"costs": [0, 800, 2200, 3500, 4800, 5200], "final_message": "Budget restoration favors cash preservation. The warehouse opens lean and practical."},
    "Standard": {"costs": [0, 1000, 3000, 4500, 6000, 7500], "final_message": "Standard restoration balances cost, reputation and operating quality."},
    "Premium": {"costs": [0, 1400, 3800, 6000, 8000, 10000], "final_message": "Premium restoration creates a stronger launch and a better first impression in the district."}
}

func _ready() -> void:
    game = get_parent()
    call_deferred("_apply", selected)

func choose_budget() -> void:
    _apply("Budget")

func choose_standard() -> void:
    _apply("Standard")

func choose_premium() -> void:
    _apply("Premium")

func _apply(plan_name: String) -> void:
    if game == null:
        game = get_parent()
    if game == null or not plans.has(plan_name):
        return
    if bool(game.get("owned", false)) and int(game.get("restoration", 0)) > 0:
        game.message = "Restoration strategy is locked after work begins."
        return
    selected = plan_name
    var plan: Dictionary = plans[plan_name]
    var costs: Array = plan["costs"]
    var stages: Array = game.get("stages")
    if stages.size() == costs.size():
        for i in range(stages.size()):
            stages[i][2] = int(costs[i])
        game.stages = stages
    applied = true
    game.message = "%s restoration selected. %s" % [selected, String(plan["final_message"])]
    if game.has_method("_log"):
        game._log("RESTORATION PLAN: %s selected." % selected)

func summary() -> String:
    var plan: Dictionary = plans.get(selected, plans["Standard"])
    var costs: Array = plan["costs"]
    var total: int = 0
    for i in range(1, costs.size()):
        total += int(costs[i])
    return "%s: $%,d total restoration" % [selected, total]
