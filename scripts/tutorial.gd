extends RefCounted
class_name RenewTutorial

# The opening guide teaches one complete business loop before exposing
# advanced empire systems. Every step says what to do, where to do it and why.
var step: Variant = 0
var completed: Variant = false
var steps: Variant = [
    {
        "phase":"RESTORE",
        "title":"INSPECT YOUR FIRST PROPERTY",
        "text":"Inspect the abandoned warehouse before spending money on it.",
        "why":"Inspection reveals what you are restoring and starts the property journey.",
        "where":"PROPERTY > INSPECT PROPERTY",
        "view":"property",
        "cta":"OPEN PROPERTY",
        "action":"INSPECT"
    },
    {
        "phase":"RESTORE",
        "title":"ACQUIRE THE WAREHOUSE",
        "text":"Buy the inspected warehouse so restoration work can begin.",
        "why":"You can only restore and operate property that your company owns.",
        "where":"PROPERTY > ACQUIRE PROPERTY",
        "view":"property",
        "cta":"OPEN PROPERTY",
        "action":"ACQUIRE"
    },
    {
        "phase":"RESTORE",
        "title":"RESTORE IT TO OPERATIONAL",
        "text":"Complete each restoration stage until the property reaches Operational.",
        "why":"An operational property is the foundation for your first business.",
        "where":"PROPERTY > RESTORE NEXT STAGE",
        "view":"property",
        "cta":"OPEN PROPERTY",
        "action":"RESTORE"
    },
    {
        "phase":"OPERATE",
        "title":"OPEN YOUR FIRST BUSINESS",
        "text":"Choose what the restored property will become and open the business.",
        "why":"This converts the restored asset into a company that can earn revenue.",
        "where":"BUSINESS > CHOOSE BUSINESS",
        "view":"operate",
        "cta":"OPEN BUSINESS",
        "action":"OPEN BUSINESS"
    },
    {
        "phase":"OPERATE",
        "title":"BUY PRODUCTION INPUTS",
        "text":"Purchase the materials needed for your first production batch.",
        "why":"Production cannot start without stock such as timber, iron or energy.",
        "where":"BUSINESS > BUY INPUTS",
        "view":"operate",
        "cta":"OPEN BUSINESS",
        "action":"BUY INPUTS"
    },
    {
        "phase":"OPERATE",
        "title":"PRODUCE FINISHED GOODS",
        "text":"Turn your inputs into finished goods.",
        "why":"Finished goods are what your business can sell to create revenue.",
        "where":"BUSINESS > PRODUCE BATCH",
        "view":"operate",
        "cta":"OPEN BUSINESS",
        "action":"PRODUCE"
    },
    {
        "phase":"OPERATE",
        "title":"MAKE YOUR FIRST SALE",
        "text":"Sell the finished goods into current customer demand.",
        "why":"A completed sale proves the full loop: restore, operate, earn, then reinvest.",
        "where":"BUSINESS > COMMERCIAL CONTROLS > SELL GOODS",
        "view":"operate",
        "cta":"OPEN BUSINESS",
        "action":"SELL GOODS"
    }
]

func current() -> Dictionary:
    if completed or step >= steps.size():
        return {
            "phase":"GROW",
            "title":"FIRST BUSINESS COMPLETE",
            "text":"You now know the core loop: restore property, operate a business, sell goods and reinvest.",
            "why":"From here, growth systems add branches, finance, contracts, regions and rivals on top of the same loop.",
            "where":"HOME > NEXT MOVE",
            "view":"live",
            "cta":"GO HOME",
            "action":"COMPLETE"
        }
    return steps[step]

func _has_inputs(game) -> bool:
    if game == null or game.command_system == null or game.command_system.supply_system == null:
        return false
    var chain = game.command_system.supply_system.chain
    if chain == null or not chain.has_method("stock"):
        return false
    return float(chain.stock("timber")) > 0.0 or float(chain.stock("iron")) > 0.0 or float(chain.stock("energy")) > 0.0

func _advance(action:String, game)->bool:
    if completed:
        return false
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
        if step >= steps.size():
            completed = true
        return true
    return false

func notify(action:String, game)->String:
    var advanced: Variant = _advance(action, game)
    if advanced:
        return "GUIDE: " + String(current().get("title","Next step"))
    return String(current().get("text","Keep growing."))

func snapshot()->Dictionary:
    return {"step":step,"completed":completed}

func load_snapshot(state:Dictionary)->void:
    if not state is Dictionary:
        return
    step = clamp(int(state.get("step",0)),0,steps.size())
    completed = bool(state.get("completed",false)) or step >= steps.size()
