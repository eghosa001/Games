extends SceneTree

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

func run() -> void:
    var finance = load("res://scripts/finance_system.gd").new()
    check(finance != null, "FinanceSystem fixture loads")
    finance.cash = 50000
    finance.debt = 15000
    finance.loan_payment = 0
    finance.financing = {
        "loan_a": {"balance": 10000.0, "principal": 10000.0, "annual_rate": 0.12, "payment": 0},
        "loan_b": {"balance": 5000.0, "principal": 5000.0, "annual_rate": 0.08, "payment": 0}
    }
    var invariant_before = finance.validate_invariants()
    check(bool(invariant_before.get("ok", false)), "Finance fixture starts with valid debt invariants")
    var cash_before_interest: int = finance.cash
    var debt_before_interest: int = finance.debt
    var debt_day = finance.settle_debt_day()
    check(int(debt_day.get("interest", -1)) == 4, "Finance accrues interest independently per instrument")
    check(finance.cash == cash_before_interest - 4, "Finance cash reflects total multi-loan interest")
    check(float(finance.financing["loan_a"]["accrued_interest"]) == 3.0, "First financing stores accrued interest separately")
    check(float(finance.financing["loan_b"]["accrued_interest"]) == 1.0, "Second financing stores accrued interest separately")
    check(float(finance.financing["loan_a"]["balance"]) == 10003.0, "First financing balance includes accrued interest")
    check(float(finance.financing["loan_b"]["balance"]) == 5001.0, "Second financing balance includes accrued interest")
    check(finance.debt == debt_before_interest, "Interest does not incorrectly increase principal debt")
    var invariant_after_interest = finance.validate_invariants()
    check(bool(invariant_after_interest.get("ok", false)), "Finance invariants survive interest accrual")

    var cash_before_repay: int = finance.cash
    var repay_result: Dictionary = finance.repay(2)
    check(bool(repay_result.get("ok", false)), "Small repayment succeeds")
    check(int(repay_result.get("interest_paid", 0)) == 2, "Repayment settles accrued interest before principal")
    check(int(repay_result.get("principal_paid", 0)) == 0, "Interest-only repayment does not reduce principal")
    check(finance.debt == debt_before_interest, "Interest-only repayment preserves principal debt")
    check(finance.cash == cash_before_repay - 2, "Repayment reduces cash by exact payment")
    check(bool(finance.validate_invariants().get("ok", false)), "Finance invariants survive interest repayment")

    var principal_before_repay: int = finance.debt
    var full_repay: Dictionary = finance.repay(20000)
    check(bool(full_repay.get("ok", false)), "Full remaining repayment succeeds")
    check(finance.debt == 0, "Full repayment clears principal debt")
    check(finance._total_accrued_interest() == 0, "Full repayment clears accrued interest")
    check(finance._total_financing_balance() == 0.0, "Full repayment clears financing balances")
    check(bool(finance.validate_invariants().get("ok", false)), "Finance invariants survive full repayment")
    check(principal_before_repay > 0, "Principal existed before final repayment")

    var old_snapshot: Dictionary = {
        "system_version": 2,
        "cash": 1000,
        "debt": 100,
        "financing": {"legacy": {"balance": 103.0, "principal": 100.0, "annual_rate": 0.12}}
    }
    var migrated = load("res://scripts/finance_system.gd").new()
    migrated.restore_state(old_snapshot)
    check(float(migrated.financing["legacy"]["accrued_interest"]) == 3.0, "Legacy financing snapshot migrates accrued interest")
    check(float(migrated.financing["legacy"]["balance"]) == 103.0, "Legacy financing balance is preserved during migration")
    check(bool(migrated.validate_invariants().get("ok", false)), "Migrated finance snapshot satisfies invariants")

    print("FINANCE INVARIANT RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
