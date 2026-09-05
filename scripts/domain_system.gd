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
        var value = finance.get(key)
        return default_value if value == null else value
    return default_value if state == null else state.get_value(domain, key, default_value)

func set_value(domain: String, key: String, value) -> void:
    # Never allow generic domain writes to mutate authoritative finance state.
    # Financial state changes must be represented by FinanceSystem transactions.
    if FINANCE_MIRROR_FIELDS.has(domain) and FINANCE_MIRROR_FIELDS[domain].has(key):
        return
    var state = game_state()
    if state != null:
        state.set_value(domain, key, value)

func spend(amount: int, reason: String = "expense") -> Dictionary:
    # Compatibility bridge for existing domain systems. FinanceSystem remains
    # authoritative; this method deliberately delegates instead of maintaining
    # or mutating a second cash ledger.
    var finance = _finance()
    if finance == null:
        return {"ok": false, "message": "FinanceSystem unavailable."}
    var result: Dictionary = finance.spend(amount, reason)
    if bool(result.get("ok", false)):
        _sync_finance_mirrors(finance)
    return result

func receive(amount: int, reason: String = "income") -> Dictionary:
    # Compatibility bridge for existing domain systems. FinanceSystem remains
    # authoritative; this method deliberately delegates instead of maintaining
    # or mutating a second cash ledger.
    var finance = _finance()
    if finance == null:
        return {"ok": false, "message": "FinanceSystem unavailable."}
    var result: Dictionary = finance.receive(amount, reason)
    if bool(result.get("ok", false)):
        _sync_finance_mirrors(finance)
    return result

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