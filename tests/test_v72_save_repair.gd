extends SceneTree

## V7.2: save repair. A one-time reconcile plugs accounting-equation damage
## (the legacy crash bug) so stalled saves advance again.
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
    var finance = root.get_node_or_null("RenewFinanceSystem")
    check(finance != null, "Finance system available")
    if finance == null:
        quit(1)
        return
    var state = root.get_node_or_null("RenewGameState")
    if state != null and state.has_method("clear"):
        state.clear()
    var saved: Dictionary = finance.capture_state()
    finance.financing = {}
    finance.debt = 0
    finance.loan_payment = 0
    finance.revenue = 0.0
    finance.operating_expenses = 0.0
    finance.interest_expense = 0.0
    finance.retained_earnings = 0.0
    finance.equity_contributed = 200000.0
    finance.cash = 200000
    check(bool(finance.validate_invariants().get("ok", false)), "Funded books validate")

    var repair_clean: Dictionary = finance.reconcile_books()
    check(bool(repair_clean.get("ok", false)) and not bool(repair_clean.get("repaired", false)), "Clean books need no repair")
    finance.set("retained_earnings", float(finance.get("retained_earnings")) - 150000.0)
    var broken: Dictionary = finance.validate_invariants()
    check(str(broken.get("error", "")) == "accounting_equation_mismatch", "Legacy damage detected")
    var repair: Dictionary = finance.reconcile_books()
    check(bool(repair.get("ok", false)) and bool(repair.get("repaired", false)), "Equation damage repaired")
    check(abs(float(repair.get("plugged", 0.0)) - 150000.0) < 0.01, "Repair plugs the exact gap")
    check(bool(finance.validate_invariants().get("ok", false)), "Repaired books validate")
    finance.financing = {"bad": {"principal": 100.0, "accrued_interest": 0.0, "balance": 999.0}}
    var other: Dictionary = finance.reconcile_books()
    check(not bool(other.get("ok", false)) and not bool(other.get("repaired", false)), "Foreign damage left alone")
    finance.financing = {}

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for repair hook")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        game.cash = 250000
        game.inspect_property()
        game.acquire_property()
        var guard := 0
        while str(state.get_value("properties", "stage", "")) != "Operational" and guard < 20:
            game.restore_property()
            guard += 1
            await process_frame
        game.choose_business_purpose(0)
        game.open_business()
        finance.set("retained_earnings", float(finance.get("retained_earnings")) - 5000.0)
        var day_before := int(state.get_value("player", "day", 1))
        game.advance_day()
        await process_frame
        check(int(state.get_value("player", "day", day_before)) == day_before + 1, "Repaired save advances")
        var mended := false
        for h in (finance.get("history") as Array):
            if str((h as Dictionary).get("kind", "")) == "reconcile":
                mended = true
        check(mended, "Repair recorded in finance history")
        game.free()
        await process_frame
    finance.restore_state(saved)
    await process_frame
    print("V72 SAVE REPAIR RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
