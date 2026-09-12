extends RefCounted
class_name RenewTutorial

# The opening tutorial teaches the economic loop one decision at a time.
# Advanced strategy is deliberately excluded until the player has completed a
# full operating day and understands why those systems matter.
var step: Variant = 0
var completed: Variant = false
var steps: Variant = [
    {"title":"INSPECT THE WAREHOUSE","text":"Inspect the abandoned warehouse to understand the opportunity.","action":"INSPECT"},
    {"title":"BUY YOUR FIRST PROPERTY","text":"Acquire the warehouse so you can invest in bringing it back to life.","action":"ACQUIRE"},
    {"title":"RESTORE THE PROPERTY","text":"Keep restoring the warehouse until it becomes operational.","action":"RESTORE"},
    {"title":"OPEN RENEW GOODS","text":"The building is ready. Open your first business and begin operating.","action":"OPEN BUSINESS"},
    {"title":"BUY PRODUCTION INPUTS","text":"A business needs materials before it can make goods. Buy your first inputs.","action":"BUY INPUTS"},
    {"title":"PRODUCE YOUR FIRST GOODS","text":"Turn those inputs into finished inventory that can generate revenue.","action":"PRODUCE"},
    {"title":"FINISH YOUR FIRST DAY","text":"End the day to make sales, see the result, and learn whether the business made money.","action":"END DAY"}
]

func current() -> Dictionary:
    if completed or step >= steps.size():
        return {"title":"FIRST BUSINESS COMPLETE","text":"You restored an abandoned asset, opened a business and completed a trading day. Now improve it and expand when the company is ready.","action":"COMPLETE"}
    return steps[step]

func _advance(action:String, game)->bool:
    if completed: return false
    var expected:String = String(current().get("action",""))
    var valid: Variant = false
    match expected:
        "INSPECT": valid = bool(game.inspected)
        "ACQUIRE": valid = bool(game.owned)
        "RESTORE": valid = str(game.stage) == "Operational" or int(game.restoration) >= 100
        "OPEN BUSINESS": valid = bool(game.business_open)
        "BUY INPUTS": valid = int(game.raw_materials) > 0
        "PRODUCE": valid = int(game.finished_goods) > 0
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
