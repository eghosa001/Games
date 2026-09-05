extends Node

## Compatibility node for the legacy Main.tscn Systems/FinanceSystem path.
## The authoritative ledger is the RenewFinanceSystem autoload; this node never
## owns financial state and only forwards calls/properties to that singleton.

func _finance():
    return get_node_or_null("/root/RenewFinanceSystem")

func spend(amount: int, reason: String = "expense") -> Dictionary:
    var finance = _finance()
    return finance.spend(amount, reason) if finance != null else {"ok": false, "message": "FinanceSystem unavailable."}

func receive(amount: int, reason: String = "income") -> Dictionary:
    var finance = _finance()
    return finance.receive(amount, reason) if finance != null else {"ok": false, "message": "FinanceSystem unavailable."}

func settle_sales(sales: int, wages: int, overhead: int, contract_income: int = 0) -> Dictionary:
    var finance = _finance()
    return finance.settle_sales(sales, wages, overhead, contract_income) if finance != null else {"ok": false, "message": "FinanceSystem unavailable."}

func repay(amount: int) -> Dictionary:
    var finance = _finance()
    return finance.repay(amount) if finance != null else {"ok": false, "message": "FinanceSystem unavailable."}

func take_loan(amount: int) -> Dictionary:
    var finance = _finance()
    return finance.take_loan(amount) if finance != null else {"ok": false, "message": "FinanceSystem unavailable."}

func create_loan(amount: int, annual_rate: float = 0.12, term_periods: int = 365) -> Dictionary:
    var finance = _finance()
    return finance.create_loan(amount, annual_rate, term_periods) if finance != null else {"ok": false, "message": "FinanceSystem unavailable."}

func settle_debt_day() -> Dictionary:
    var finance = _finance()
    return finance.settle_debt_day() if finance != null else {"ok": false, "message": "FinanceSystem unavailable."}

func capture_state() -> Dictionary:
    var finance = _finance()
    return finance.capture_state() if finance != null else {}

func restore_state(snapshot: Dictionary) -> void:
    var finance = _finance()
    if finance != null:
        finance.restore_state(snapshot)

func balance_sheet() -> Dictionary:
    var finance = _finance()
    return finance.balance_sheet() if finance != null else {}

func solvency_status() -> Dictionary:
    var finance = _finance()
    return finance.solvency_status() if finance != null else {"ok": false, "solvent": false}

func validate_invariants() -> Dictionary:
    var finance = _finance()
    return finance.validate_invariants() if finance != null else {"ok": false, "error": "FinanceSystem unavailable."}

func _get(property: String):
    var finance = _finance()
    if finance == null:
        return null
    return finance.get(property)