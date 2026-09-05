extends Node

# Shared infrastructure for domain systems. Domain systems mutate only their
# owning GameState bucket and communicate results back to the command layer.
#
# Finance is the canonical cash/debt ledger. Legacy domain buckets are read-only
# mirrors for financial fields; callers must use FinanceSystem transactions.

const FINANCE_MIRROR_FIELDS := {
    "economy": ["cash", "last_sales", "last_profit", "total_profit"],
    "finance": ["debt", "loan_payment"]
}

func game_state():
    return get_node_or_null("/root/RenewGameState")

func _finance():
    return get_node_or_null("/root/RenewFinanceSystem")

func get_value(domain: String, key: String, default_value):
    var state = game_state()
    var finance = _finance()
    if finance != null and FINANCE_MIRROR_FIELDS.has(domain) and FINANCE_MIRROR_FIELDS[domain].has(key):
        return finance.get(key, default_value)
    return default_value if state == null else state.get_value(domain, key, default_value)

func set_value(domain: String, key: String, value) -> void:
    # Never allow generic domain writes to mutate authoritative finance state.
    # Financial state changes must be represented by FinanceSystem transactions.
    if FINANCE_MIRROR_FIELDS.has(domain) and FINANCE_MIRROR_FIELDS[domain].has(key):
        return
    var state = game_state()
    if state != null:
        state.set_value(domain, key, value)

func _sync_finance_mirrors(finance) -> void:
    var state = game_state()
    if state == null or finance == null:
        return
    state.set_value("economy", "cash", int(finance.get("cash")))
    state.set_value("economy", "last_sales", int(finance.get("last_sales")))
    state.set_value("economy", "last_profit", int(finance.get("last_profit")))
    state.set_value("economy", "total_profit", int(finance.get("total_profit")))
    state.set_value("finance", "debt", int(finance.get("debt")))
    state.set_value("finance", "loan_payment", int(finance.get("loan_payment")))

func spend(amount: int, reason: String = "expense") -> Dictionary:
    if amount < 0:
        return {"ok": false, "amount": 0, "reason": reason, "message": "Invalid spending amount."}
    var finance = _finance()
    if finance != null and finance.has_method("spend"):
        var result: Dictionary = finance.spend(amount, reason)
        if not bool(result.get("ok", false)):
            return result
        _sync_finance_mirrors(finance)
        return result
    return {"ok": false, "amount": 0, "reason": reason, "message": "FinanceSystem unavailable."}

func receive(amount: int, reason: String = "income") -> Dictionary:
    if amount < 0:
        return {"ok": false, "amount": 0, "reason": reason, "message": "Invalid income amount."}
    var finance = _finance()
    if finance != null and finance.has_method("receive"):
        var result: Dictionary = finance.receive(amount, reason)
        if not bool(result.get("ok", false)):
            return result
        _sync_finance_mirrors(finance)
        return result
    return {"ok": false, "amount": 0, "reason": reason, "message": "FinanceSystem unavailable."}

func log_message(text: String) -> void:
    var logs = get_value("company", "log_lines", [])
    if not logs is Array:
        logs = []
    logs = logs.duplicate(true)
    logs.append(text)
    if logs.size() > 100:
        logs.pop_front()
    set_value("company", "log_lines", logs)

func message(text: String) -> void:
    set_value("company", "message", text)

func money(value: int) -> String:
    return "%d" % value
