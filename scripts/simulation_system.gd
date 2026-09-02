extends Node
class_name RenewSimulationSystem

const SYSTEM_VERSION := 1

# Simulation is the command boundary between UI/input and domain systems.
# It does not own presentation; it coordinates authoritative subsystems and
# exposes deterministic commands that Main can delegate to during migration.
var command_count := 0
var last_command := ""
var last_result: Dictionary = {}

func execute(command: String, args: Dictionary = {}) -> Dictionary:
    command_count += 1
    last_command = command
    match command:
        "spend": return _finance().spend(int(args.get("amount", 0)), str(args.get("reason", "expense")))
        "receive": return _finance().receive(int(args.get("amount", 0)), str(args.get("reason", "income")))
        "loan": return _finance().take_loan(int(args.get("amount", 0)))
        "repay": return _finance().repay(int(args.get("amount", 0)))
        "produce": return _produce(args)
        "settle_sales": return _settle_sales(args)
        "end_day": return end_day(args)
        _:
            return {"ok": false, "message": "Unknown simulation command: %s" % command}

func _produce(args: Dictionary) -> Dictionary:
    var production = _production()
    var economy = _economy()
    if production == null or economy == null:
        return {"ok": false, "message": "Production dependencies are unavailable."}
    return production.produce(economy, int(args.get("cycles", 0)))

func _settle_sales(args: Dictionary) -> Dictionary:
    var result = _finance().settle_sales(int(args.get("sales", 0)), int(args.get("wages", 0)), int(args.get("overhead", 0)), int(args.get("contract_income", 0)))
    last_result = result
    return result

func end_day(args: Dictionary = {}) -> Dictionary:
    var finance = _finance()
    if finance == null: return {"ok": false, "message": "FinanceSystem is unavailable."}
    var debt_result := finance.settle_debt_day()
    var economy = _economy()
    if economy != null: economy.end_market_day()
    last_result = debt_result
    return debt_result

func capture_state() -> Dictionary:
    var result := {"system_version": SYSTEM_VERSION, "command_count": command_count, "last_command": last_command, "last_result": last_result.duplicate(true)}
    var finance = _finance()
    var production = _production()
    if finance != null: result["finance"] = finance.capture_state()
    if production != null: result["production"] = production.capture_state()
    return result

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    command_count = int(snapshot.get("command_count", 0))
    last_command = str(snapshot.get("last_command", ""))
    last_result = snapshot.get("last_result", {}).duplicate(true)
    var finance = _finance()
    if finance != null and snapshot.get("finance", {}) is Dictionary: finance.restore_state(snapshot["finance"])
    var production = _production()
    if production != null and snapshot.get("production", {}) is Dictionary: production.restore_state(snapshot["production"])

func _finance():
    var root = get_tree().root
    return root.get_node_or_null("RenewFinanceSystem") if root else null

func _production():
    var root = get_tree().root
    return root.get_node_or_null("RenewProductionSystem") if root else null

func _economy():
    var main = get_tree().root.get_node_or_null("Main")
    return main.economy if main != null and "economy" in main else null
