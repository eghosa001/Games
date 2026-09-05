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
    var script = load("res://scripts/finance_system.gd")
    var finance = Node.new()
    finance.set_script(script)
    root.add_child(finance)
    return finance

func run() -> void:
    await test_interest_is_accrual_not_immediate_cash_outflow()
    await test_repayment_rejects_non_positive_amount()
    await test_multiple_loans_have_aggregate_scheduled_payment()
    await test_assumed_debt_does_not_create_cash()
    print("\nRENEW FINANCE REGRESSION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

func test_interest_is_accrual_not_immediate_cash_outflow() -> void:
    var finance = _finance()
    finance.cash = 50000
    var loan = finance.create_loan(15000, 0.10, 365)
    check(bool(loan.get("ok", false)), "loan created for accrual test")
    finance.loan_payment = 0
    var cash_before = finance.cash
    var result = finance.settle_debt_day()
    check(int(result["interest"]) > 0, "daily interest accrued")
    check(finance.cash == cash_before, "accrued interest does not immediately reduce cash")
    check(finance._total_accrued_interest() == int(result["interest"]), "accrued interest is carried as liability")
    check(float(finance.interest_expense) == float(result["interest"]), "accrued interest is recognized as expense once")
    check(bool(finance.validate_invariants().get("ok", false)), "finance invariants hold after accrual")
    finance.free()
    await process_frame

func test_repayment_rejects_non_positive_amount() -> void:
    var finance = _finance()
    finance.cash = 10000
    finance.create_loan(5000, 0.10, 365)
    var before_cash = finance.cash
    var before_debt = finance.debt
    var zero = finance.repay(0)
    var negative = finance.repay(-10)
    check(not bool(zero.get("ok", false)), "zero repayment rejected")
    check(not bool(negative.get("ok", false)), "negative repayment rejected")
    check(finance.cash == before_cash and finance.debt == before_debt, "invalid repayments do not mutate ledger")
    finance.free()
    await process_frame

func test_multiple_loans_have_aggregate_scheduled_payment() -> void:
    var finance = _finance()
    finance.cash = 100000
    var first = finance.create_loan(10000, 0.12, 20)
    var first_payment = int(first["payment"])
    var second = finance.create_loan(5000, 0.08, 20)
    var second_payment = int(second["payment"])
    check(finance.loan_payment == first_payment + second_payment, "scheduled payment aggregates all financing instruments")
    check(finance.debt_service() == float(first_payment + second_payment), "debt service equals aggregate scheduled payment")
    finance.free()
    await process_frame

func test_assumed_debt_does_not_create_cash() -> void:
    var finance = _finance()
    finance.cash = 25000
    var before_cash = finance.cash
    var result = finance.assume_debt(12000, "merger target")
    check(bool(result.get("ok", false)), "assumed debt accepted")
    check(finance.cash == before_cash, "assumed debt creates no cash inflow")
    check(finance.debt == 12000, "assumed debt increases principal debt")
    check(bool(finance.validate_invariants().get("ok", false)), "finance invariants hold after debt assumption")
    finance.free()
    await process_frame
