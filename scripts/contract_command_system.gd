extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")

var state_adapter = DomainSystem.new()

func _ready() -> void:
    add_child(state_adapter)

func sign_contract() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Open a business before signing contracts."); return
    if int(state_adapter.get_value("contracts", "contract_days", 0)) > 0:
        state_adapter.message("An active customer contract is already running."); return
    var reputation: Variant = int(state_adapter.get_value("player", "reputation", 0))
    if reputation < 10:
        state_adapter.message("Major customers need at least 10 reputation."); return
    var contracts = get_node_or_null("/root/RenewContractSystem")
    if contracts != null:
        if not contracts.active_contract().is_empty():
            state_adapter.message("An active customer contract is already running."); return
        var offer: Dictionary = contracts.get_future_contract_offer(reputation)
        if not bool(offer.get("eligible", false)):
            state_adapter.message(str(offer.get("message", "No customer contract is available."))); return
        var result: Dictionary = contracts.create_default_customer_contract(int(state_adapter.get_value("player", "day", 1)), reputation)
        if not bool(result.get("ok", false)):
            state_adapter.message(str(result.get("message", "No customer contract is available."))); return
        var contract: Dictionary = result.get("contract", {})
        var duration: int = int(contract.get("delivery_schedule", {}).get("duration_days", 1))
        state_adapter.set_value("contracts", "contract_days", duration)
        state_adapter.set_value("contracts", "contract_bonus", int(contract.get("price", 0)))
        state_adapter.log_message("CONTRACT: customer supply agreement signed with %s." % str(contract.get("customer_id", "customer")))
        state_adapter.message("Contract signed. Deliver on schedule to earn revenue and improve the customer relationship.")
        return
    state_adapter.message("Contract system unavailable.")

func cancel_active_contract(reason: String = "player cancelled") -> void:
    var contracts = get_node_or_null("/root/RenewContractSystem")
    if contracts == null:
        state_adapter.message("Contract system unavailable."); return
    var active: Dictionary = contracts.active_contract()
    if active.is_empty():
        state_adapter.message("There is no active customer contract to cancel."); return
    var fee: int = int(active.get("cancellation", {}).get("fee", 0))
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    if fee > 0:
        if finance == null:
            state_adapter.message("Finance system unavailable."); return
        if int(finance.get("cash")) < fee:
            state_adapter.message("Cancellation requires $%s." % state_adapter.money(fee)); return
        var payment: Dictionary = finance.spend(fee, "customer contract cancellation fee")
        if not bool(payment.get("ok", false)):
            state_adapter.message(str(payment.get("message", "Cancellation fee could not be paid."))); return
        state_adapter.set_value("economy", "cash", int(payment.get("cash", finance.get("cash"))))
    var result: Dictionary = contracts.cancel_contract(str(active.get("id", "")), reason, int(state_adapter.get_value("player", "day", 1)))
    if not bool(result.get("ok", false)):
        if fee > 0 and finance != null:
            var refund: Dictionary = finance.receive(fee, "refund after failed contract cancellation")
            state_adapter.set_value("economy", "cash", int(refund.get("cash", finance.get("cash"))))
        state_adapter.message(str(result.get("message", "Contract cancellation failed."))); return
    state_adapter.set_value("contracts", "contract_days", 0)
    state_adapter.set_value("contracts", "contract_bonus", 0)
    state_adapter.message("Contract cancelled. The $%s cancellation fee was paid." % state_adapter.money(fee))
    state_adapter.log_message("CONTRACT: cancelled %s (-$%s)." % [str(active.get("id", "")), state_adapter.money(fee)])
