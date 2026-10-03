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
    print("BANKRUPTCY SYSTEM RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
