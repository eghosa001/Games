extends SceneTree

## V2.7: regional infrastructure with teeth. Power, logistics, storage,
## research and factory bonuses flow from founder-owned active assets into
## freight, operating costs, warehouse limits, research and production.
## Capital construction, upgrades and repairs must debit FinanceSystem exactly once.
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

func _set_finance_cash(finance: Node, target: int) -> void:
    var current := int(finance.available_cash())
    if current < target:
        finance.receive(target - current, "infrastructure test seed")
    elif current > target:
        finance.spend(current - target, "infrastructure test normalization")

func run() -> void:
    var Infra = load("res://scripts/infrastructure_system.gd")
    check(Infra != null, "Infrastructure system loads")
    if Infra == null:
        quit(1)
        return
    var finance = root.get_node_or_null("RenewFinanceSystem")
    check(finance != null, "Authoritative finance system resolves")
    if finance == null:
        quit(1)
        return
    _set_finance_cash(finance, 1000000)

    var infra = Infra.new()
    root.add_child(infra)
    await process_frame
    var neutral: Dictionary = infra.founder_modifiers()
    check(float(neutral.get("logistics", 0.0)) == 1.0, "No assets means neutral logistics")
    check(float(neutral.get("energy", 0.0)) == 1.0, "No assets means neutral energy")

    var before_road := int(finance.available_cash())
    var road: Dictionary = infra.build("road", 0, "founder", before_road, 1)
    check(bool(road.get("ok", false)), "Road construction starts")
    check(int(finance.available_cash()) == before_road - int(road.get("cost", 0)), "Road construction debits authoritative finance exactly once")

    var before_power := int(finance.available_cash())
    var power: Dictionary = infra.build("power_plant", 0, "founder", before_power, 1)
    check(bool(power.get("ok", false)), "Power plant construction starts")
    check(int(finance.available_cash()) == before_power - int(power.get("cost", 0)), "Power plant construction debits authoritative finance exactly once")

    var bad_before := int(finance.available_cash())
    var bad: Dictionary = infra.build("moon_base", 0, "founder", bad_before, 1)
    check(not bool(bad.get("ok", false)), "Unknown type rejected")
    check(int(finance.available_cash()) == bad_before, "Rejected infrastructure does not alter finance")

    for day in range(1, 12):
        infra.process_day(day)
    var mods: Dictionary = infra.founder_modifiers()
    check(float(mods.get("logistics", 1.0)) < 1.0, "Roads cut freight")
    check(float(mods.get("energy", 1.0)) > 1.0, "Power plants add energy")

    var active_road := ""
    for asset in infra.list_assets():
        if str(asset.get("type", "")) == "road" and str(asset.get("status", "")) == infra.ACTIVE:
            active_road = str(asset.get("id", ""))
            break
    check(not active_road.is_empty(), "Completed road is available for upgrades")
    if not active_road.is_empty():
        var before_upgrade := int(finance.available_cash())
        var upgraded: Dictionary = infra.upgrade(active_road, "founder", before_upgrade, 12)
        check(bool(upgraded.get("ok", false)), "Active infrastructure upgrades")
        check(int(finance.available_cash()) == before_upgrade - int(upgraded.get("cost", 0)), "Infrastructure upgrade debits authoritative finance exactly once")
        infra.disrupt(active_road, 5, "audit test incident", 12)
        var before_repair := int(finance.available_cash())
        var repaired: Dictionary = infra.repair(active_road, "founder", before_repair, 12)
        check(bool(repaired.get("ok", false)), "Disrupted infrastructure repairs")
        check(int(finance.available_cash()) == before_repair - int(repaired.get("cost", 0)), "Infrastructure repair debits authoritative finance exactly once")

    var store: Dictionary = infra.capture_state()
    var restored = Infra.new()
    root.add_child(restored)
    restored.restore_state(store)
    check(restored.founder_modifiers().get("logistics", 1.0) == infra.founder_modifiers().get("logistics", 1.0), "Modifiers persist across save/load")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for infrastructure commands")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        current_scene = game
        await process_frame
        await process_frame
        check(game.get_node_or_null("UI/InfrastructurePanel") != null, "Infrastructure panel is mounted")
        for method in ["infra_build", "infra_type", "infra_repair"]:
            check(game.has_method(method), "Main exposes %s" % method)
        game.cash = 300000
        game.infra_type()
        var ui_before := int(game.cash)
        var services = root.get_node_or_null("RenewServices")
        var live_infra = services.get_service("RenewInfrastructureSystem") if services != null else null
        var assets_before:int = int(live_infra.list_assets().size()) if live_infra != null else 0
        game.infra_build()
        await process_frame
        check(live_infra != null and live_infra.list_assets().size() > assets_before, "Touch command builds infrastructure")
        if live_infra != null and live_infra.list_assets().size() > assets_before:
            var latest: Dictionary = live_infra.list_assets().back()
            var charged := int(latest.get("construction_cost", 0))
            check(int(game.cash) == ui_before - charged, "Touch infrastructure command charges exactly once")
        game.free()
        await process_frame
    infra.queue_free()
    restored.queue_free()
    await process_frame
    print("V27 INFRASTRUCTURE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
