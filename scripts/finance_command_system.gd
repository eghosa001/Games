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
    # Mirror fields are authoritative in FinanceSystem; DomainSystem.set_value
    # rejects them by design, so sync directly into GameState here.
    var state = state_adapter.game_state()
    if state == null:
        return
    for key in ["cash", "debt", "loan_payment"]:
        if snapshot.has(key):
            state.set_value("finance" if key != "cash" else "economy", key, snapshot[key])

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
    var score := float(finance.get("credit_score"))
    var rate := 0.12
    var amount: int = 20000 + reputation * 300
    if score >= 80.0:
        rate = 0.08
        amount = 20000 + reputation * 500
    elif score >= 60.0:
        rate = 0.12
        amount = 20000 + reputation * 300
    elif score >= 40.0:
        rate = 0.16
        amount = 10000 + reputation * 200
    else:
        rate = 0.22
        amount = 5000
    var result: Dictionary = finance.create_loan(amount, rate, 20, false, "unsecured loan")
    if not bool(result.get("ok", false)):
        state_adapter.message(str(result.get("message", "Loan could not be approved.")))
        return
    _sync_legacy_finance(finance)
    state_adapter.log_message("BANK: borrowed $%s at %.0f%% (credit %s). Daily repayment is $%s." % [state_adapter.money(amount), rate * 100.0, str(finance.get("credit_rating")), state_adapter.money(int(result.get("payment", 0)))])
    state_adapter.message("Loan approved at %.0f%% for your %s rating. Growth is faster, but default will hurt your company." % [rate * 100.0, str(finance.get("credit_rating"))])

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

func _ownership():
    var tree := get_tree()
    if tree == null:
        return null
    var root_node = tree.root
    if root_node != null:
        var node = root_node.get_node_or_null("Renew/Systems/OwnershipSystem")
        if node != null:
            return node
    var scene = tree.current_scene if tree != null else null
    if scene != null:
        var node = scene.get_node_or_null("Systems/OwnershipSystem")
        if node == null:
            node = scene.get_node_or_null("OwnershipSystem")
        if node != null:
            return node
    return null

func _pending_offer() -> Dictionary:
    var offer = state_adapter.game_state().get_value("ownership", "pending_offer", {}) if state_adapter.game_state() != null else {}
    return offer if offer is Dictionary else {}

func _set_pending_offer(offer: Dictionary) -> void:
    var state = state_adapter.game_state()
    if state != null:
        state.set_value("ownership", "pending_offer", offer)

func request_investment() -> void:
    var finance := _finance()
    if finance == null:
        state_adapter.message("Finance system unavailable.")
        return
    var ownership = _ownership()
    if ownership == null or not ownership.has_method("get_entity"):
        state_adapter.message("Incorporate first: investor offers need a registered company.")
        return
    if not ownership.has_entity("renew_co"):
        state_adapter.message("Incorporate first: investor offers need a registered company.")
        return
    var confidence := float(ownership.get_entity("renew_co").get("investor_confidence", 50.0))
    if confidence < 30.0:
        state_adapter.message("Investors are watching but not ready. Raise confidence above 30 first.")
        return
    var valuation := max(25000.0, float(finance.valuation())) if finance.has_method("valuation") else 25000.0
    var percent := clampf(10.0 + confidence / 10.0, 10.0, 20.0)
    var amount := max(5000, int(round(valuation * percent / max(1.0, 100.0 - percent))))
    var investor := "fund_a"
    var offer := {"investor": investor, "amount": amount, "percent": percent, "valuation": int(round(valuation)), "day": int(state_adapter.get_value("player", "day", 1))}
    _set_pending_offer(offer)
    state_adapter.log_message("INVESTOR: %s offers $%s for %.1f%% of the company." % [investor, state_adapter.money(amount), percent])
    state_adapter.message("%s offers $%s for %.1f%%. ACCEPT DEAL to take it, or DECLINE DEAL to walk away." % [investor, state_adapter.money(amount), percent])

func accept_investment() -> void:
    var finance := _finance()
    if finance == null:
        state_adapter.message("Finance system unavailable.")
        return
    var offer := _pending_offer()
    if offer.is_empty():
        state_adapter.message("No investor offer is on the table. Request one first.")
        return
    var ownership = _ownership()
    if ownership == null or not ownership.has_method("issue_for_percent"):
        state_adapter.message("Incorporate first: investor offers need a registered company.")
        return
    var issued: Dictionary = ownership.issue_for_percent("renew_co", str(offer.get("investor", "investor")), float(offer.get("percent", 10.0)), "ordinary", "investor_accepted")
    if not bool(issued.get("ok", false)):
        state_adapter.message("Investment failed: %s." % str(issued.get("error", "issuance rejected")))
        return
    var funded: Dictionary = finance.record_equity(int(offer.get("amount", 0)), "investor capital: %s" % str(offer.get("investor", "investor")))
    if not bool(funded.get("ok", false)):
        state_adapter.message("Investment failed: capital could not be recorded.")
        return
    _sync_legacy_finance(finance)
    ownership.adjust_investor_confidence("renew_co", 5.0, "investment_accepted")
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    _set_pending_offer({})
    state_adapter.log_message("INVESTMENT: %s invested $%s for %.1f%%." % [str(offer.get("investor", "investor")), state_adapter.money(int(offer.get("amount", 0))), float(offer.get("percent", 0.0))])
    state_adapter.message("Investment accepted. Growth capital landed; ownership diluted."); var _rs=get_node_or_null("/root/RenewReputationSystem");if _rs!=null and _rs.has_method("adjust"):_rs.adjust("investor",3)

func decline_investment() -> void:
    var offer := _pending_offer()
    if offer.is_empty():
        state_adapter.message("No investor offer is on the table.")
        return
    _set_pending_offer({})
    var ownership = _ownership()
    if ownership != null and ownership.has_method("adjust_investor_confidence") and ownership.has_entity("renew_co"):
        ownership.adjust_investor_confidence("renew_co", -2.0, "investment_declined")
    state_adapter.message("Offer declined. The market will remember your discipline.")

func invest_term() -> void:
    var finance := _finance()
    if finance == null or not finance.has_method("place_term_deposit"):
        state_adapter.message("Finance system unavailable.")
        return
    var amount := 5000
    var score := float(finance.get("credit_score"))
    var rate := 0.05 + (0.02 if score >= 80.0 else 0.0)
    var result: Dictionary = finance.place_term_deposit(amount, 30, rate)
    if not bool(result.get("ok", false)):
        state_adapter.message(str(result.get("message", "Term deposit could not be placed.")))
        return
    _sync_legacy_finance(finance)
    state_adapter.log_message("BANK: $%s locked in a 30-day bill at %.1f%%." % [state_adapter.money(amount), rate * 100.0])
    state_adapter.message("Term deposit placed. It matures automatically in 30 days.")
