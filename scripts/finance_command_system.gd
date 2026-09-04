extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")

var state_adapter = DomainSystem.new()

func _ready() -> void:
    add_child(state_adapter)

func _finance() -> Node:
    return get_node_or_null("/root/RenewFinanceSystem")

func _sync_legacy_finance(finance: Node) -> void:
    if finance == null or not finance.has_method("capture_state"):
        return
    var snapshot: Dictionary = finance.capture_state()
    for key in ["cash", "debt", "loan_payment"]:
        if snapshot.has(key):
            state_adapter.set_value("finance" if key != "cash" else "economy", key, snapshot[key])

func take_loan() -> void:
    var finance := _finance()
    if finance == null:
        state_adapter.message("Finance system unavailable.")
        return
    var debt: int = int(finance.get("debt"))
    if debt > 0:
        state_adapter.message("Repay the current loan before borrowing again.")
        return
    var reputation: int = int(state_adapter.get_value("player", "reputation", 0))
    var amount: int = 20000 + reputation * 300
    var result: Dictionary = finance.create_loan(amount, 0.12, 20, false, "unsecured loan")
    if not bool(result.get("ok", false)):
        state_adapter.message(str(result.get("message", "Loan could not be approved.")))
        return
    _sync_legacy_finance(finance)
    state_adapter.log_message("BANK: borrowed $%s. Daily repayment is $%s." % [state_adapter.money(amount), state_adapter.money(int(result.get("payment", 0)))])
    state_adapter.message("Loan approved. Growth is faster, but default will hurt your company.")

func repay_loan() -> void:
    var finance := _finance()
    if finance == null:
        state_adapter.message("Finance system unavailable.")
        return
    var debt: int = int(finance.get("debt"))
    if debt <= 0:
        state_adapter.message("You have no outstanding loan.")
        return
    var amount: int = min(debt, max(1000, debt / 4))
    var result: Dictionary = finance.repay(amount)
    if not bool(result.get("ok", false)):
        state_adapter.message(str(result.get("message", "Repayment failed.")))
        return
    _sync_legacy_finance(finance)
    state_adapter.log_message("BANK: voluntary repayment $%s. Remaining debt $%s." % [state_adapter.money(int(result.get("amount", 0))), state_adapter.money(int(result.get("debt", 0)))])
    state_adapter.message("Loan balance reduced.")
