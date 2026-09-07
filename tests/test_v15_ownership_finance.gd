extends SceneTree

## V1.5: credit-gated financing and inbound investor offers. Banks price risk
## by credit score; investors approach with cash-for-equity term sheets the
## player can accept or decline; dividends return capital once shared.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _reset_ledger(finance: Node, cash: int) -> void:
    finance.financing = {}
    finance.debt = 0
    finance.loan_payment = 0
    finance.revenue = 0.0
    finance.operating_expenses = 0.0
    finance.interest_expense = 0.0
    finance.taxes = 0.0
    finance.retained_earnings = 0.0
    finance.equity_contributed = float(cash)
    finance.cash = cash
    finance.credit_score = 70.0
    finance.update_credit_rating()

func run() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for ownership and finance")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var state = root.get_node_or_null("RenewGameState")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    check(state != null and finance != null, "Canonical finance and state resolve")
    if state == null or finance == null:
        quit(1)
        return
    game.cash = 100000
    game.reputation = 60

    # Credit tiers price risk: prime borrowers pay less and borrow more.
    _reset_ledger(finance, 100000)
    finance.credit_score = 85.0
    finance.update_credit_rating()
    check(str(finance.get_credit_rating()) == "AA", "Prime credit rates AAA/AA")
    game.take_loan()
    check(int(finance.debt) == 20000 + 60 * 500, "Prime borrowing scales with reputation")
    var prime_rate := 0.0
    for id in finance.financing:
        prime_rate = float(finance.financing[id].get("annual_rate", 0.0))
    check(is_equal_approx(prime_rate, 0.08), "Prime rate is eight percent")
    var prime_guard := 0
    while int(finance.debt) > 0 and prime_guard < 40:
        game.repay_loan()
        prime_guard += 1
    check(int(finance.debt) == 0, "Prime loan repays in full")
    finance.credit_score = 70.0
    finance.update_credit_rating()
    game.take_loan()
    var mid_rate := 0.0
    for id in finance.financing:
        mid_rate = float(finance.financing[id].get("annual_rate", 0.0))
    check(is_equal_approx(mid_rate, 0.12), "Standard rate is twelve percent")
    var mid_guard := 0
    while int(finance.debt) > 0 and mid_guard < 40:
        game.repay_loan()
        mid_guard += 1
    check(int(finance.debt) == 0, "Standard loan repays in full")
    finance.credit_score = 45.0
    finance.update_credit_rating()
    game.take_loan()
    var sub_rate := 0.0
    for id in finance.financing:
        sub_rate = float(finance.financing[id].get("annual_rate", 0.0))
    check(is_equal_approx(sub_rate, 0.16), "Weak credit pays sixteen percent")
    check(bool(finance.validate_invariants().get("ok", false)), "Tiered lending keeps clean books")

    # Inbound investor offers: term sheet math, acceptance dilutes and funds.
    _reset_ledger(finance, 100000)
    var ownership = game.get_node_or_null("Systems/OwnershipSystem")
    if ownership != null and not ownership.has_entity("renew_co"):
        ownership.register_entity("renew_co", "company", 10000000)
        ownership.issue_shares("renew_co", "founder", 1000000, "ordinary", "test incorporation")
    check(ownership != null and ownership.has_entity("renew_co"), "Player corporation is registered")
    game.request_investment()
    var offer: Dictionary = state.get_value("ownership", "pending_offer", {})
    check(not offer.is_empty(), "Investor offer arrives")
    check(int(offer.get("amount", 0)) > 0, "Offer names an amount")
    var pct := float(offer.get("percent", 0.0))
    check(pct >= 10.0 and pct <= 20.0, "Offer takes ten to twenty percent")
    var founder_before := float(ownership.get_ownership_percent("renew_co", "founder"))
    var cash_before := int(finance.cash)
    game.accept_investment()
    check(state.get_value("ownership", "pending_offer", {}).is_empty(), "Acceptance clears the term sheet")
    check(int(finance.cash) == cash_before + int(offer.get("amount", 0)), "Accepted capital lands as cash")
    check(ownership.get_ownership_percent("renew_co", "founder") < founder_before, "Accepted capital dilutes the founder")
    check(float(ownership.get_entity("renew_co").get("investor_confidence", 0.0)) > 50.0, "Accepted capital lifts confidence")
    check(bool(finance.validate_invariants().get("ok", false)), "Investment keeps clean books")
    game.request_investment()
    check(not state.get_value("ownership", "pending_offer", {}).is_empty(), "Second offer arrives")
    var confidence_before_decline := float(ownership.get_entity("renew_co").get("investor_confidence", 0.0))
    game.decline_investment()
    check(state.get_value("ownership", "pending_offer", {}).is_empty(), "Decline clears the term sheet")
    check(float(ownership.get_entity("renew_co").get("investor_confidence", 0.0)) < confidence_before_decline, "Decline costs confidence")

    # Dividends return capital once outside investors hold equity.
    game.pay_dividend()
    var corporate = game.get_node_or_null("World/Corporate")
    check(corporate != null and int(corporate.get("dividends_paid")) > 0, "Dividend distributes to investors")
    check(bool(finance.validate_invariants().get("ok", false)), "Dividend keeps clean books")

    # Offers persist through save/load.
    game.request_investment()
    game.save_game()
    var snapshot = state.capture()
    check((snapshot.get("domains", {}) as Dictionary).get("ownership", {}).get("pending_offer", {}).is_empty() == false, "Pending offer persists in saves")
    print("V15 OWNERSHIP FINANCE RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
