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

func _disable_scheduled_payments(finance: Node) -> void:
    for id in finance.financing:
        var instrument: Dictionary = finance.financing[id]
        instrument["payment"] = 0
        finance.financing[id] = instrument
    finance._recalculate_loan_payment()

func run() -> void:
    await test_interest_is_accrual_not_immediate_cash_outflow()
    await test_accrued_interest_is_not_cash_flow_until_paid()
    await test_repayment_rejects_non_positive_amount()
    await test_settlement_rejects_negative_inputs()
    await test_multiple_loans_have_aggregate_scheduled_payment()
    await test_assumed_debt_does_not_create_cash()
    await test_asset_sale_is_investing_cash_flow_and_recognizes_gain_loss()
    await test_equity_buyback_reduces_equity_once()
    print("\nRENEW FINANCE REGRESSION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

func test_interest_is_accrual_not_immediate_cash_outflow() -> void:
    var finance = _finance()
    finance.cash = 50000
    var loan = finance.create_loan(15000, 0.10, 365)
    check(bool(loan.get("ok", false)), "loan created for accrual test")
    _disable_scheduled_payments(finance)
    var cash_before = finance.cash
    var result = finance.settle_debt_day()
    check(int(result["interest"]) > 0, "daily interest accrued")
    check(finance.cash == cash_before, "accrued interest does not immediately reduce cash")
    check(finance._total_accrued_interest() == int(result["interest"]), "accrued interest is carried as liability")
    check(float(finance.interest_expense) == float(result["interest"]), "accrued interest is recognized as expense once")
    check(bool(finance.validate_invariants().get("ok", false)), "finance invariants hold after accrual")
    finance.free()
    await process_frame

func test_accrued_interest_is_not_cash_flow_until_paid() -> void:
    var finance = _finance()
    finance.cash = 50000
    var loan = finance.create_loan(15000, 0.10, 365)
    check(bool(loan.get("ok", false)), "loan created for cash-flow accrual test")
    _disable_scheduled_payments(finance)
    var cash_before = finance.cash
    var accrual = finance.settle_debt_day()
    var statement_after_accrual = finance.cash_flow_statement()
    check(float(statement_after_accrual["operating"]) == 0.0, "accrued interest is absent from operating cash flow before payment")
    check(float(statement_after_accrual["net_change"]) == float(finance.cash - 25000), "cash-flow net change matches actual recorded cash movement")
    check(finance.cash == cash_before, "cash remains unchanged after interest accrual")
    var payment = int(accrual["interest"])
    if payment > 0:
        var repayment = finance.repay(payment)
        check(bool(repayment.get("ok", false)), "accrued interest can be paid later")
        var statement_after_payment = finance.cash_flow_statement()
        check(float(statement_after_payment["financing"]) == float(loan.get("amount", 0) - payment), "financing cash flow reflects debt proceeds and actual repayment")
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

func test_settlement_rejects_negative_inputs() -> void:
    var finance = _finance()
    finance.cash = 25000
    var before := finance.capture_state()
    var cases := [
        [-1, 0, 0, 0],
        [0, -1, 0, 0],
        [0, 0, -1, 0],
        [0, 0, 0, -1]
    ]
    for values in cases:
        var result := finance.settle_sales(values[0], values[1], values[2], values[3])
        check(not bool(result.get("ok", false)), "negative settlement input rejected")
        check(finance.cash == int(before["cash"]) and finance.revenue == float(before["revenue"]) and finance.operating_expenses == float(before["operating_expenses"]), "rejected settlement leaves ledger unchanged")
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

func test_asset_sale_is_investing_cash_flow_and_recognizes_gain_loss() -> void:
    var finance = _finance()
    finance.cash = 25000
    finance.fixed_assets = 10000
    var revenue_before = finance.revenue
    var equity_before = float(finance.balance_sheet()["equity"])
    var result = finance.record_asset_sale("factory", 6500, 10000)
    check(bool(result.get("ok", false)), "asset sale accepted")
    check(finance.cash == 31500, "asset sale increases cash by sale proceeds")
    check(abs(float(finance.fixed_assets)) < 0.01, "asset book value leaves fixed assets")
    check(abs(finance.revenue - revenue_before) < 0.01, "asset sale does not create operating revenue")
    check(float(finance.cash_flow_statement()["investing"]) == 6500.0, "asset sale is recorded as investing cash flow")
    check(abs(finance.retained_earnings + 3500.0) < 0.01, "asset sale loss is recognized in retained earnings")
    check(abs(float(finance.balance_sheet()["equity"]) - (equity_before - 3500.0)) < 0.01, "asset sale gain or loss changes equity by the disposal result")
    finance.free()
    await process_frame

func test_equity_buyback_reduces_equity_once() -> void:
    var finance = _finance()
    finance.cash = 25000
    finance.equity_contributed = 10000
    finance.retained_earnings = 5000
    var equity_before = float(finance.balance_sheet()["equity"])
    var result = finance.buyback_equity(2000)
    check(bool(result.get("ok", false)), "equity buyback accepted")
    check(finance.cash == 23000, "buyback reduces cash once")
    check(abs(finance.equity_contributed - 10000.0) < 0.01, "buyback does not reduce contributed capital and retained earnings together")
    check(abs(finance.retained_earnings - 3000.0) < 0.01, "buyback reduces retained earnings once")
    check(abs(float(finance.balance_sheet()["equity"]) - (equity_before - 2000.0)) < 0.01, "buyback reduces total equity by the cash paid")
    check(float(finance.cash_flow_statement()["financing"]) == -2000.0, "buyback is recorded as financing cash flow")
    finance.free()
    await process_frame
