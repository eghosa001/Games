extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")

var state_adapter = DomainSystem.new()

func _ready() -> void:
    add_child(state_adapter)

func _sync_cash_mirror(cash: int) -> void:
    # economy.cash mirrors FinanceSystem; write it directly into GameState.
    var state = state_adapter.game_state()
    if state != null:
        state.set_value("economy", "cash", cash)

func _active_product() -> String:
    var industry_id := str(state_adapter.get_value("businesses", "industry_id", ""))
    if industry_id in ["furniture", "construction_materials", "consumer_electronics"]:
        return industry_id
    return "consumer_goods"

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
        var result: Dictionary = contracts.create_default_customer_contract(int(state_adapter.get_value("player", "day", 1)), reputation, _active_product())
        if not bool(result.get("ok", false)):
            state_adapter.message(str(result.get("message", "No customer contract is available."))); return
        var contract: Dictionary = result.get("contract", {})
        var duration: int = int(contract.get("delivery_schedule", {}).get("duration_days", 1))
        state_adapter.set_value("contracts", "contract_days", duration)
        state_adapter.set_value("contracts", "contract_bonus", int(contract.get("price", 0)))
        state_adapter.log_message("CONTRACT: customer supply agreement signed with %s." % str(contract.get("customer_id", "customer")))
        state_adapter.message("Contract signed. Deliver on schedule to earn revenue and improve the customer relationship."); var _rs=get_node_or_null("/root/RenewReputationSystem");if _rs!=null and _rs.has_method("adjust"):_rs.adjust("business",2)
        return
    state_adapter.message("Contract system unavailable.")
func haggle_contract() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)): state_adapter.message("Open a business before haggling over contracts."); return
    if int(state_adapter.get_value("contracts", "contract_days", 0)) > 0: state_adapter.message("Finish the active contract before haggling a new one."); return
    var reputation := int(state_adapter.get_value("player", "reputation", 0))
    if reputation < 10: state_adapter.message("Major customers need at least 10 reputation."); return
    var contracts = get_node_or_null("/root/RenewContractSystem")
    if contracts == null: state_adapter.message("Contract system unavailable."); return
    if not contracts.active_contract().is_empty(): state_adapter.message("An active customer contract is already running."); return
    var offer: Dictionary = contracts.get_future_contract_offer(reputation)
    if not bool(offer.get("eligible", false)): state_adapter.message(str(offer.get("message", "No customer contract is available."))); return
    var ask := int(offer.get("price", 180))
    var discount := minf(0.15, 0.05 + float(reputation) / 200.0)
    var demand := int(round(float(ask) * (1.0 - discount)))
    var day := int(state_adapter.get_value("player", "day", 1))
    var product := _active_product()
    var quantity := int(offer.get("quantity", 25))
    var duration := int(offer.get("duration_days", 5))
    var per_delivery := int(ceil(float(quantity) / float(maxi(1, duration))))
    var final := demand
    var verdict := "They accepted your counter."
    if reputation >= 25:
        final = demand
        verdict = "Your standing commands respect. They accepted your counter."
    elif reputation >= 15:
        final = int(round(float(ask + demand) / 2.0))
        verdict = "They met you halfway."
    else:
        final = int(round(float(ask) * 1.05))
        verdict = "They found the lowball insulting and raised the price."
    var result: Dictionary = contracts.create_customer_contract(["RENEW Goods", "Harbor Retail Cooperative"], product, quantity, maxi(1, final), 70, {"frequency": "daily", "quantity_per_delivery": per_delivery, "duration_days": duration, "start_day": day}, "Harbor District Retail Hub", 600, {"player_can_cancel": true, "notice_days": 1, "fee": 900}, {"eligible": true, "term_days": duration, "price_adjustment": 0.05}, {"on_fulfilled": 10, "on_missed": -2, "on_cancelled": -4, "on_failed": -20}, "standard")
    if not bool(result.get("ok", false)): state_adapter.message(str(result.get("message", "No customer contract is available."))); return
    var contract: Dictionary = result.get("contract", {})
    state_adapter.set_value("contracts", "contract_days", int(contract.get("delivery_schedule", {}).get("duration_days", 1)))
    state_adapter.set_value("contracts", "contract_bonus", int(contract.get("price", 0)))
    state_adapter.log_message("HAGGLE: asked $%d, settled $%d with %s." % [ask, int(contract.get("price", 0)), str(contract.get("customer_id", "customer"))])
    state_adapter.message("Haggled $%d down to $%d. %s" % [ask, int(contract.get("price", 0)), verdict]); var _rsh=get_node_or_null("/root/RenewReputationSystem");if _rsh!=null and _rsh.has_method("adjust"):_rsh.adjust("business",2)

func _sign_kind(kind: String, creator: String, min_reputation: int, label: String) -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Open a business before signing contracts."); return
    if int(state_adapter.get_value("contracts", "contract_days", 0)) > 0:
        state_adapter.message("An active customer contract is already running."); return
    var reputation: Variant = int(state_adapter.get_value("player", "reputation", 0))
    if reputation < min_reputation:
        state_adapter.message("%s contracts need at least %d reputation." % [label, min_reputation]); return
    var contracts = get_node_or_null("/root/RenewContractSystem")
    if contracts == null:
        state_adapter.message("Contract system unavailable."); return
    if not contracts.active_contract().is_empty():
        state_adapter.message("An active customer contract is already running."); return
    if not contracts.has_method(creator):
        state_adapter.message("That contract type is unavailable."); return
    var result: Dictionary = contracts.call(creator, int(state_adapter.get_value("player", "day", 1)), reputation, _active_product())
    if not bool(result.get("ok", false)):
        state_adapter.message(str(result.get("message", "No customer contract is available."))); return
    var contract: Dictionary = result.get("contract", {})
    var duration: int = int(contract.get("delivery_schedule", {}).get("duration_days", 1))
    state_adapter.set_value("contracts", "contract_days", duration)
    state_adapter.set_value("contracts", "contract_bonus", int(contract.get("price", 0)))
    state_adapter.log_message("CONTRACT: %s agreement signed with %s." % [label.to_lower(), str(contract.get("customer_id", "customer"))])
    state_adapter.message("%s contract signed. Premium terms, premium penalties." % label)

func sign_exclusive_contract() -> void:
    _sign_kind("exclusive", "create_exclusive_contract", 10, "Exclusive")

func sign_construction_contract() -> void:
    _sign_kind("construction", "create_construction_contract", 10, "Construction")

func sign_government_contract() -> void:
    _sign_kind("government", "create_government_contract", 40, "Government")

func sign_export_contract() -> void:
    if int(state_adapter.get_value("supply_chain", "transport_level", 1)) < 2:
        state_adapter.message("Export freight needs transport level 2. Upgrade the fleet first.")
        return
    _sign_kind("export", "create_export_contract", 20, "Export")

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
        _sync_cash_mirror(int(payment.get("cash", finance.get("cash"))))
    var result: Dictionary = contracts.cancel_contract(str(active.get("id", "")), reason, int(state_adapter.get_value("player", "day", 1)))
    if not bool(result.get("ok", false)):
        if fee > 0 and finance != null:
            var refund: Dictionary = finance.receive(fee, "refund after failed contract cancellation")
            _sync_cash_mirror(int(refund.get("cash", finance.get("cash"))))
        state_adapter.message(str(result.get("message", "Contract cancellation failed."))); return
    state_adapter.set_value("contracts", "contract_days", 0)
    state_adapter.set_value("contracts", "contract_bonus", 0)
    state_adapter.message("Contract cancelled. The $%s cancellation fee was paid." % state_adapter.money(fee))
    state_adapter.log_message("CONTRACT: cancelled %s (-$%s)." % [str(active.get("id", "")), state_adapter.money(fee)])
