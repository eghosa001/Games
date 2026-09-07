extends Node

# Shared infrastructure for domain systems. Domain systems mutate only their
# owning GameState bucket and communicate results back to the command layer.
#
# Finance is the canonical cash/debt ledger. Legacy domain buckets are read-only
# mirrors for financial fields; callers must use FinanceSystem transactions.

const EmployeeEffects = preload("res://scripts/employee_system.gd")

const FINANCE_MIRROR_FIELDS := {
    "economy": ["cash", "last_sales", "last_profit", "total_profit"],
    "finance": ["debt", "loan_payment"]
}

const EXECUTIVE_SEATS := ["CEO", "COO", "CFO", "CTO"]

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

func message(text: String) -> void:
    var state = game_state()
    if state == null:
        return
    state.set_value("company", "message", text)
    log_message(text)

func log_message(text: String) -> void:
    var state = game_state()
    if state == null:
        return
    var logs = state.get_value("company", "log_lines", [])
    if not logs is Array:
        logs = []
    logs = logs.duplicate(true)
    logs.append(text)
    while logs.size() > 100:
        logs.pop_front()
    state.set_value("company", "log_lines", logs)

func money(value: int) -> String:
    var negative := value < 0
    var digits := str(absi(value))
    var out := ""
    while digits.length() > 3:
        out = "," + digits.substr(digits.length() - 3, 3) + out
        digits = digits.substr(0, digits.length() - 3)
    out = digits + out
    return ("-" + out) if negative else out

func executive_seats() -> Dictionary:
    var seats: Dictionary = {}
    var state = game_state()
    if state == null:
        return seats
    var roster = state.get_value("employees", "roster", [])
    if not roster is Array:
        return seats
    for employee in roster:
        if not employee is Dictionary:
            continue
        if str(employee.get("status", "active")) != "active":
            continue
        var seat := str(employee.get("executive_seat", ""))
        if seat != "" and EXECUTIVE_SEATS.has(seat):
            seats[seat] = str(employee.get("id", ""))
    return seats

func executive_bonus(kind: String) -> float:
    var seats := executive_seats()
    match kind:
        "production":
            return float(EmployeeEffects.EXECUTIVE_BONUSES["COO"].get("production", 1.0)) if seats.has("COO") else 1.0
        "operating_cost":
            return float(EmployeeEffects.EXECUTIVE_BONUSES["CFO"].get("operating_cost", 1.0)) if seats.has("CFO") else 1.0
        "research":
            return float(EmployeeEffects.EXECUTIVE_BONUSES["CTO"].get("research", 1.0)) if seats.has("CTO") else 1.0
        "hiring":
            return float(EmployeeEffects.EXECUTIVE_BONUSES["CEO"].get("hiring", 1.0)) if seats.has("CEO") else 1.0
    return 1.0

func infra_modifier(key: String) -> float:
    if not is_inside_tree():
        return 1.0
    var infra = get_node_or_null("/root/RenewInfrastructureSystem")
    if infra == null or not infra.has_method("founder_modifiers"):
        return 1.0
    return float(infra.founder_modifiers().get(key, 1.0))