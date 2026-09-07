extends SceneTree

## Pass 2: merger finance runs through the canonical ledger. Assumed debt
## becomes an instrument, absorptions stay balanced, rollback restores.
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
    var Acquire = load("res://scripts/acquisition_system.gd")
    check(Acquire != null, "Acquisition system loads")
    if Acquire == null:
        quit(1)
        return
    var finance = root.get_node_or_null("RenewFinanceSystem")
    check(finance != null, "Finance system available")
    if finance == null:
        quit(1)
        return
    var saved: Dictionary = finance.capture_state()
    finance.financing = {}
    finance.debt = 0
    finance.loan_payment = 0
    finance.cash = 300000
    finance.equity_contributed = 300000.0
    finance.retained_earnings = 0.0
    finance.revenue = 0.0
    finance.operating_expenses = 0.0
    finance.interest_expense = 0.0
    var acquirer: Node = Acquire.new()
    root.add_child(acquirer)
    await process_frame
    check(bool(acquirer.register_target("t1", "Target One", [{"id": "plant", "value": 80000.0}], 50000.0, 10, [], 10000.0, 40.0, []).get("ok", false)), "Target registered with debt")
    var merged: Dictionary = acquirer.merge_entities("renew_co", "t1", 0.0, 0.0, {})
    check(bool(merged.get("ok", false)), "Merger completes")
    check(bool(finance.validate_invariants().get("ok", false)), "Books validate after merger")
    check(int(finance.get("debt")) == 50000, "Assumed debt on the books")
    var assumed := false
    for id in (finance.get("financing") as Dictionary).keys():
        if str(id).begins_with("assumed_"):
            assumed = true
    check(assumed, "Assumption tracked as an instrument")
    check(bool(acquirer.register_target("t2", "Target Two", [{"id": "depot", "value": 30000.0}], 20000.0, 5, [], 5000.0, 30.0, []).get("ok", false)), "Second target registered")
    var debt_before := int(finance.get("debt"))
    var fixed_before := float(finance.get("fixed_assets"))
    var partial: Dictionary = acquirer._resolve_merger_finance((acquirer.targets as Dictionary)["t2"], 0.0, {})
    check(bool(partial.get("ok", false)), "Finance stage resolves")
    acquirer._rollback_merger_finance(partial)
    check(int(finance.get("debt")) == debt_before, "Rollback restores debt")
    check(abs(float(finance.get("fixed_assets")) - fixed_before) < 0.01, "Rollback restores fixed assets")
    check(bool(finance.validate_invariants().get("ok", false)), "Books validate after rollback")
    acquirer.queue_free()
    finance.restore_state(saved)
    await process_frame
    print("V93 MERGER LEDGER RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
