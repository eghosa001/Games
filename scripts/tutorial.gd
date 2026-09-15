extends RefCounted
class_name RenewTutorial

# The opening tutorial teaches the economic loop one decision at a time.
# The live economy uses real-world time; players actively create and sell goods.
var step: Variant = 0
var completed: Variant = false
var steps: Variant = [
    {"title":"INSPECT THE WAREHOUSE","text":"Inspect the abandoned warehouse to understand the opportunity.","action":"INSPECT"},
    {"title":"BUY YOUR FIRST PROPERTY","text":"Acquire the warehouse so you can invest in bringing it back to life.","action":"ACQUIRE"},
    {"title":"RESTORE THE PROPERTY","text":"Keep restoring the warehouse until it becomes operational.","action":"RESTORE"},
    {"title":"OPEN RESTORA GOODS","text":"The building is ready. Open your first business and begin operating.","action":"OPEN BUSINESS"},
    {"title":"BUY PRODUCTION INPUTS","text":"A business needs materials before it can make goods. Buy your first inputs.","action":"BUY INPUTS"},
    {"title":"PRODUCE YOUR FIRST GOODS","text":"Turn those inputs into finished inventory that can generate revenue.","action":"PRODUCE"},
    {"title":"MAKE YOUR FIRST SALE","text":"Sell finished goods into today's customer demand. You can keep managing the business throughout the real-world day.","action":"SELL GOODS"}
]

func current() -> Dictionary:
    if completed or step >= steps.size():
        return {"title":"FIRST BUSINESS COMPLETE","text":"You restored an abandoned asset, opened a business, produced inventory and made a live sale. Keep operating, then expand when the company is ready.","action":"COMPLETE"}
    return steps[step]

func _has_inputs(game) -> bool:
    if game == null or game.command_system == null or game.command_system.supply_system == null:
        return false
    var chain = game.command_system.supply_system.chain
    if chain == null or not chain.has_method("stock"):
        return false
    return float(chain.stock("timber")) > 0.0 or float(chain.stock("iron")) > 0.0 or float(chain.stock("energy")) > 0.0

func _advance(action:String, game)->bool:
    if completed: return false
    var expected:String = String(current().get("action",""))
    var valid: Variant = false
    match expected:
        "INSPECT": valid = bool(game.inspected)
        "ACQUIRE": valid = bool(game.owned)
        "RESTORE": valid = str(game.stage) == "Operational" or int(game.restoration) >= 100
        "OPEN BUSINESS": valid = bool(game.business_open)
        "BUY INPUTS": valid = _has_inputs(game)
        "PRODUCE": valid = int(game.finished_goods) > 0
        "SELL GOODS": valid = int(game.last_sales) > 0
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
