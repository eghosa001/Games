extends SceneTree

var passed := 0
var failed := 0

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("run")

func _finance() -> Node:
    var script = load("res://scripts/finance_system_fixed.gd")
    var finance = Node.new()
    finance.set_script(script)
    root.add_child(finance)
    return finance

func run() -> void:
    await test_loan_interest_follows_current_principal()
    await test_loan_term_counts_down_and_matures()
    await test_bond_maturity_retires_principal()
    await test_missed_payment_does_not_consume_term()
    print("\nRENEW FINANCE AMORTIZATION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

func test_loan_interest_follows_current_principal() -> void:
    var finance = _finance()
    finance.cash = 50000
    var loan = finance.create_loan(10000, 0.10, 20)
    check(bool(loan.get("ok", false)), "amortization loan created")
    var id := str(loan.get("id", ""))
    var first = finance.settle_debt_day()
    var principal_after_first := float(finance.financing[id]["principal"])
    var second = finance.settle_debt_day()
    check(int(first.get("interest", 0)) == 3, "first-day interest uses original principal")
    check(int(second.get("interest", 0)) <= 3, "later interest does not exceed original-principal interest")
    check(principal_after_first < 10000.0, "scheduled payment reduces principal")
    check(float(finance.financing[id]["principal"]) < principal_after_first, "second scheduled payment reduces principal again")
    check(bool(finance.validate_invariants().get("ok", false)), "amortization invariants hold")
    finance.free()
    await process_frame

func test_loan_term_counts_down_and_matures() -> void:
    var finance = _finance()
    finance.cash = 50000
    var loan = finance.create_loan(10000, 0.10, 3)
    var id := str(loan.get("id", ""))
    check(int(finance.financing[id]["remaining_periods"]) == 3, "loan starts at full term")
    var first = finance.settle_debt_day()
    check(not bool(first.get("missed", true)), "first scheduled loan payment succeeds")
    check(int(finance.financing[id]["remaining_periods"]) == 2, "term decrements after first payment")
    finance.settle_debt_day()
    check(int(finance.financing[id]["remaining_periods"]) == 1, "term decrements after second payment")
    var final_day = finance.settle_debt_day()
    check(not bool(final_day.get("missed", true)), "final scheduled payment succeeds")
    check(finance.debt == 0, "loan principal is fully retired at maturity")
    check(int(finance.financing[id]["remaining_periods"]) == 0, "loan term reaches zero at maturity")
    check(int(finance.financing[id]["balance"]) == 0, "matured loan has no stale balance")
    check(int(finance.financing[id]["payment"]) == 0, "matured loan has no future scheduled payment")
    check(bool(finance.validate_invariants().get("ok", false)), "matured loan invariants hold")
    finance.free()
    await process_frame

func test_bond_maturity_retires_principal() -> void:
    var finance = _finance()
    finance.cash = 50000
    var bond = finance.issue_bond(5000, 0.08, 2)
    check(bool(bond.get("ok", false)), "bond created for maturity test")
    var id := ""
    for candidate in finance.financing:
        id = str(candidate)
    finance.settle_debt_day()
    check(int(finance.financing[id]["remaining_periods"]) == 1, "bond term decrements after interest payment")
    var final_day = finance.settle_debt_day()
    check(not bool(final_day.get("missed", true)), "bond maturity payment succeeds")
    check(finance.debt == 0, "bond principal is retired at maturity")
    check(int(finance.financing[id]["balance"]) == 0, "matured bond has no stale balance")
    check(bool(finance.validate_invariants().get("ok", false)), "bond maturity invariants hold")
    finance.free()
    await process_frame

func test_missed_payment_does_not_consume_term() -> void:
    var finance = _finance()
    finance.cash = 10000
    var loan = finance.create_loan(10000, 0.10, 3)
    var id := str(loan.get("id", ""))
    finance.cash = 0
    var missed = finance.settle_debt_day()
    check(bool(missed.get("missed", false)), "unfunded scheduled payment is marked missed")
    check(int(finance.financing[id]["remaining_periods"]) == 3, "missed payment does not consume loan term")
    check(finance.debt == 10000, "missed payment leaves principal outstanding")
    check(bool(finance.validate_invariants().get("ok", false)), "missed payment invariants hold")
    finance.free()
    await process_frame
