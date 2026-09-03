extends Node

var contract_system = null
var observed_day: Variant = -1
var observed_contract_id: Variant = ""

func _ready() -> void:
    contract_system = get_node_or_null("/root/RenewContractSystem")
    observed_day = _main_day()
    if contract_system != null:
        var existing: Variant = contract_system.active_contract()
        if not existing.is_empty(): observed_contract_id = str(existing.get("id", ""))

func _process(_delta: float) -> void:
    var main = get_parent()
    if main == null or contract_system == null: return
    var legacy_days: Variant = int(main.get("contract_days"))
    if legacy_days > 0 and observed_contract_id.is_empty():
        var existing: Variant = contract_system.active_contract()
        if not existing.is_empty():
            observed_contract_id = str(existing.get("id", ""))
        else:
            var created: Variant = contract_system.create_default_customer_contract(_main_day(), int(main.get("reputation")))
            if bool(created.get("ok", false)):
                observed_contract_id = str(created["contract"]["id"])
        if not observed_contract_id.is_empty():
            # Legacy fields are retained only as a compatibility signal; ContractSystem owns terms/execution.
            main.set("contract_bonus", 0)
            observed_day = _main_day()
    if observed_contract_id.is_empty(): return
    var current_day: Variant = _main_day()
    if current_day == observed_day: return
    if current_day < observed_day:
        observed_day = current_day
        return
    var contract: Variant = contract_system.active_contract(observed_contract_id)
    if contract.is_empty():
        observed_contract_id = ""
        observed_day = current_day
        return
    var production_quality: Variant = _quality()
    var available: Variant = int(main.get("finished_goods"))
    var result: Variant = contract_system.execute_day(observed_contract_id, available, production_quality, current_day)
    if not bool(result.get("ok", false)):
        observed_day = current_day
        return
    var delivered: Variant = int(result.get("delivered", 0))
    var revenue: Variant = int(result.get("revenue", 0))
    var penalty: Variant = int(result.get("penalty", 0))
    if delivered > 0: main.set("finished_goods", max(0, available - delivered))
    main.set("cash", int(main.get("cash")) + revenue - penalty)
    if int(result.get("shortfall", 0)) == 0 and bool(result.get("quality_ok", false)):
        main.set("reputation", int(main.get("reputation")) + 1)
    elif int(result.get("shortfall", 0)) > 0:
        main.set("reputation", max(0, int(main.get("reputation")) - 1))
    if penalty > 0:
        _log(main, "CONTRACT: delivered %d; penalty $%s." % [delivered, _money(penalty)])
    else:
        _log(main, "CONTRACT: delivered %d; revenue $%s." % [delivered, _money(revenue)])
    if bool(result.get("finished", false)):
        var final_contract: Dictionary = result["contract"]
        var status: Variant = str(final_contract.get("execution_status", "breached"))
        var due: Variant = max(1.0, float(final_contract["quantity_due"]))
        var fulfilment_pct: Variant = int(round(float(final_contract["quantity_delivered"]) / due * 100.0))
        _log(main, "CONTRACT %s: %s (%d%% fulfilled)." % [final_contract["id"], status.to_upper(), fulfilment_pct])
        main.set("contract_days", 0)
        main.set("contract_bonus", 0)
        var impact: Dictionary = final_contract.get("reputation_impact", {})
        var rep_change: Variant = int(impact.get("on_fulfilled", 0)) if status == "fulfilled" else int(impact.get("on_failed", 0))
        main.set("reputation", max(0, int(main.get("reputation")) + rep_change))
        observed_contract_id = ""
    observed_day = current_day

func _main_day() -> int:
    var main = get_parent()
    return int(main.get("day")) if main != null else 1

func _quality() -> int:
    var production = get_node_or_null("/root/RenewProductionSystem")
    if production != null:
        var snapshot: Dictionary = production.capture_state()
        var last_run: Dictionary = snapshot.get("last_run", {})
        if last_run.has("quality"): return int(last_run["quality"])
    return 75

func _money(value: int) -> String:
    return "%d" % value

func _log(main, text: String) -> void:
    var logs = main.get("log_lines")
    if logs is Array:
        logs.append(text)
        if logs.size() > 100: logs.pop_front()
