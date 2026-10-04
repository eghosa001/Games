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
    var Bankruptcy = load("res://scripts/bankruptcy_system.gd")
    var Finance = load("res://scripts/finance_system.gd")
    check(Bankruptcy != null and Finance != null, "Distress dependencies load")
    if Bankruptcy == null or Finance == null:
        quit(1)
        return

    var finance: Node = Finance.new()
    root.add_child(finance)

    var History = load("res://scripts/history_system.gd")
    var Legacy = load("res://scripts/corporate_legacy_system.gd")
    var history: Node = History.new()
    history.name = "RenewHistorySystem"
    root.add_child(history)
    var legacy: Node = Legacy.new()
    legacy.name = "RenewCorporateLegacy"
    root.add_child(legacy)

    var distress: Node = Bankruptcy.new()
    root.add_child(distress)
    await process_frame

    check(not bool(distress.is_recovery_center_open()), "Healthy company does not show recovery center")
    distress.state = "cash_crisis"
    distress.recovery_center_open = false
    distress._refresh_distress_ui()
    check(not bool(distress.distress_layer.visible), "Cash-crisis warning does not forcibly block company navigation")
    check(bool(distress.show_recovery_center()), "Player can explicitly open recovery center during cash crisis")
    check(bool(distress.distress_layer.visible), "Explicit recovery center request shows recovery controls")
    distress.hide_recovery_center()
    check(not bool(distress.distress_layer.visible), "Player can return to company management from recovery center")

    distress._transition("covenant_pressure", "regression covenant pressure")
    check(bool(distress.is_recovery_center_open()), "Covenant pressure automatically opens critical recovery center")
    check(bool(distress.begin_restructuring("regression").get("ok", false)), "Formal restructuring starts")
    check(str(distress.state) == "restructuring", "State enters restructuring")

    var cash_before := int(finance.cash)
    check(bool(distress.secure_investment(finance, 5000, "test rescue").get("ok", false)), "Rescue investment succeeds")
    check(int(finance.cash) == cash_before + 5000, "Rescue equity reaches finance")
    check(int(distress.restructuring_plan.get("actions", 0)) == 1, "Turnaround action is recorded")

    check(bool(distress.mark_recovery().get("ok", false)), "Restructuring can enter recovery")
    check(str(distress.state) == "recovery", "Recovery state is active")

    var plan_id := str(distress.restructuring_plan.get("id", ""))
    var stabilized: Dictionary = distress.evaluate(finance, 0.0)
    check(str(stabilized.get("state", "")) == "stable", "Sustained healthy finance completes recovery")
    var recovery_history: Array = history.get_timeline("crisis", 20)
    var history_match := false
    for event in recovery_history:
        if event is Dictionary and str(event.get("title", "")) == "Corporate recovery completed":
            var details = event.get("details", {})
            if details is Dictionary and str(details.get("plan_id", "")) == plan_id:
                history_match = true
                break
    check(history_match, "Completed recovery is preserved in permanent history")
    var recovery_legacy: Array = legacy.list_category("crisis_recoveries")
    var legacy_match := false
    for item in recovery_legacy:
        if item is Dictionary:
            var details = item.get("details", {})
            if details is Dictionary and str(details.get("plan_id", "")) == plan_id:
                legacy_match = true
                break
    check(legacy_match, "Completed recovery becomes a corporate legacy artifact")
    var recovery_event_count := 0
    for item in distress.events:
        if item is Dictionary and str(item.get("kind", "")) == "recovery_completed":
            recovery_event_count += 1
    distress.evaluate(finance, 0.0)
    var recovery_event_count_after := 0
    for item in distress.events:
        if item is Dictionary and str(item.get("kind", "")) == "recovery_completed":
            recovery_event_count_after += 1
    check(recovery_event_count == 1 and recovery_event_count_after == 1, "Recovery completion is recorded exactly once")

    var snapshot: Dictionary = distress.capture_state()
    var restored: Node = Bankruptcy.new()
    root.add_child(restored)
    await process_frame
    restored.restore_state(snapshot)
    check(str(restored.state) == "recovery", "Distress state survives restore")
    check(restored.investment_history.size() == 1, "Rescue history survives restore")

    restored.state = "insolvent"
    check(bool(restored.enter_administration("regression insolvency").get("ok", false)), "Insolvency can enter administration")
    check(bool(restored.liquidate(finance, []).get("ok", false)), "Administration can resolve through liquidation")
    check(str(restored.state) == "liquidation", "Liquidation is terminal state")

    distress.free()
    restored.free()
    finance.free()
    history.free()
    legacy.free()
    print("BANKRUPTCY SYSTEM RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
