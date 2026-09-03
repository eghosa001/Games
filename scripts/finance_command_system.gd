extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")

var state_adapter = DomainSystem.new()

func _ready() -> void:
    add_child(state_adapter)

func take_loan() -> void:
    if int(state_adapter.get_value("finance", "debt", 0)) > 0:
        state_adapter.message("Repay the current loan before borrowing again."); return
    var reputation: Variant = int(state_adapter.get_value("player", "reputation", 0))
    var amount: Variant = 20000 + reputation * 300
    var payment: Variant = int(ceil(float(amount) / 20.0))
    state_adapter.set_value("finance", "debt", amount)
    state_adapter.set_value("finance", "loan_payment", payment)
    state_adapter.set_value("economy", "cash", int(state_adapter.get_value("economy", "cash", 25000)) + amount)
    state_adapter.log_message("BANK: borrowed $%s. Daily repayment is $%s." % [state_adapter.money(amount), state_adapter.money(payment)])
    state_adapter.message("Loan approved. Growth is faster, but default will hurt your company.")

func repay_loan() -> void:
    var debt: Variant = int(state_adapter.get_value("finance", "debt", 0))
    if debt <= 0:
        state_adapter.message("You have no outstanding loan."); return
    var amount: Variant = min(debt, max(1000, debt / 4))
    var cash: Variant = int(state_adapter.get_value("economy", "cash", 25000))
    if cash < amount:
        state_adapter.message("Not enough cash to make a voluntary repayment."); return
    state_adapter.set_value("economy", "cash", cash - amount)
    debt -= amount
    state_adapter.set_value("finance", "debt", debt)
    if debt == 0: state_adapter.set_value("finance", "loan_payment", 0)
    state_adapter.log_message("BANK: voluntary repayment $%s. Remaining debt $%s." % [state_adapter.money(amount), state_adapter.money(debt)])
    state_adapter.message("Loan balance reduced.")
