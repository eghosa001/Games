extends RefCounted
class_name RenewTutorial

# Phase A tutorial: guides the player through the first restoration-to-business loop.
var step: Variant = 0
var completed: Variant = false
var steps: Variant = [
    {"title":"INSPECT THE OPPORTUNITY","text":"Start by inspecting the abandoned warehouse. Good businesses begin with good information.","action":"INSPECT"},
    {"title":"ACQUIRE THE PROPERTY","text":"Buy the warehouse. This is your first piece of productive capital.","action":"ACQUIRE"},
    {"title":"RESTORE IT","text":"Invest through each restoration stage. Every upgrade increases reputation and unlocks the next decision.","action":"RESTORE"},
    {"title":"OPEN RENEW GOODS","text":"When restoration reaches Operational, open the business with working capital.","action":"OPEN BUSINESS"},
    {"title":"BUILD INVENTORY","text":"Buy inputs, then produce goods. Inventory is your fuel for making sales.","action":"PRODUCE"},
    {"title":"SET YOUR STRATEGY","text":"Hire staff, upgrade capacity, market the brand, and experiment with your price.","action":"STRATEGY"},
    {"title":"CLOSE YOUR FIRST DAY","text":"Once you have at least five finished goods, end the day and see whether your strategy made money.","action":"END DAY"}
]

func current() -> Dictionary:
    if completed or step >= steps.size():
        return {"title":"FIRST BUSINESS COMPLETE","text":"You have turned a neglected asset into a working company. The next challenge is scaling it.","action":"COMPLETE"}
    return steps[step]

func _advance(action:String, game)->bool:
    if completed: return false
    var expected:String = String(current().get("action",""))
    var valid: Variant = false
    match expected:
        "INSPECT": valid = bool(game.inspected)
        "ACQUIRE": valid = bool(game.owned)
        "RESTORE": valid = int(game.restoration) > 0
        "OPEN BUSINESS": valid = bool(game.business_open)
        "PRODUCE": valid = int(game.finished_goods) > 0
        "STRATEGY": valid = int(game.employees) > 3 or int(game.capacity_level) > 1 or int(game.marketing_level) > 0 or int(game.player_price) != 110
        "END DAY": valid = int(game.day) > 1
    if valid:
        step += 1
        if step >= steps.size(): completed = true
        return true
    return false

func notify(action:String, game)->String:
    var advanced: Variant = _advance(action, game)
    if advanced:
        return "TUTORIAL: " + String(current().get("title","Next step"))
    return String(current().get("text","Keep building."))

func snapshot()->Dictionary:
    return {"step":step,"completed":completed}

func load_snapshot(state:Dictionary)->void:
    if not state is Dictionary: return
    step = clamp(int(state.get("step",0)),0,steps.size())
    completed = bool(state.get("completed",false)) or step >= steps.size()
