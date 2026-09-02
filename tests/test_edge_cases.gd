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
    test_refcounted_systems()
    await test_scene_controllers()
    test_save_system()
    print("EDGE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

func test_refcounted_systems() -> void:
    var e = load("res://scripts/economy.gd").new()
    check(e.supplier_for("unknown").is_empty(), "Economy unknown supplier")
    check(not bool(e.quote("unknown", 1).get("ok", true)), "Economy unknown quote")
    check(not bool(e.buy_resource("materials", 100, 1).get("ok", true)), "Economy insufficient cash")
    e.set_market_modifier("materials", 99.0)
    check(float(e.market_multipliers["materials"]) == 1.6, "Economy modifier upper clamp")
    e.set_market_modifier("materials", 0.1)
    check(float(e.market_multipliers["materials"]) == 0.65, "Economy modifier lower clamp")
    e.clear_market_modifiers()

    var p = load("res://scripts/production.gd").new()
    var empty = load("res://scripts/economy.gd").new()
    empty.resources["materials"]["stock"] = 0
    check(not bool(p.produce(empty, 1).get("ok", true)), "Production missing materials")
    check(not bool(p.produce(e, 0).get("ok", true)), "Production zero quantity")

    var d = load("res://scripts/districts.gd").new()
    d.update_unlocks(0)
    check(not bool(d.select(-1).get("ok", true)), "District invalid negative index")
    check(not bool(d.select(99).get("ok", true)), "District invalid high index")
    d.update_unlocks(100)
    check(bool(d.select(3).get("ok", false)), "District highest unlock")
    check(d.business_multiplier("Building Materials") > 0.0, "District industry multiplier")

    var r = load("res://scripts/restoration_strategy.gd").new()
    check(r.has_method("current_plan"), "Restoration current plan API")
    var fake = load("res://tests/fake_game.gd").new()
    root.add_child(fake)
    r.game = fake
    r.choose_budget(); r.choose_standard(); r.choose_premium()
    check(r.selected == "Premium", "Restoration plan switching")
    fake.free()

    var x = load("res://scripts/expansion.gd").new()
    x.unlock_from_reputation(0)
    check(x.selected(0).has("name"), "Expansion selected starter")
    check(not bool(x.buy(1, 1).get("ok", true)), "Expansion locked purchase")
    x.unlock_from_reputation(100)
    check(not bool(x.buy(0, 1).get("ok", true)), "Expansion insufficient cash")
    check(bool(x.buy(0, 100000).get("ok", false)), "Expansion purchase")
    check(bool(x.upgrade(0, 100000).get("ok", false)), "Expansion upgrade")
    check(bool(x.buy_resource_site(0, 100000).get("ok", false)), "Expansion resource purchase")
    check(bool(x.generate_resource(0).get("ok", false)), "Expansion resource generation")
    check(bool(x.upgrade_resource_site(0, 100000).get("ok", false)), "Expansion resource upgrade")
    check(x.get_summary().has("properties") and x.get_summary().has("resource_sites"), "Expansion full summary")

    var regions = load("res://scripts/regions.gd").new()
    regions.update_unlocks(0)
    check(not bool(regions.select(1, 0).get("ok", true)), "Regions locked selection")
    regions.update_unlocks(100)
    check(bool(regions.select(5, 100).get("ok", false)), "Regions highest tier selection")
    check(regions.logistics_cost(100.0, 0, 5) > 0, "Regions long-distance logistics")
    regions.daily_update(12)
    check(regions.trade_route_bonus(5) >= 0.0, "Regions route bonus after update")

    var rivals = load("res://scripts/competitors.gd").new()
    rivals._normalize()
    var before_rel := int(rivals.rivals[0]["relationship"])
    rivals.improve_relationship(0)
    check(int(rivals.rivals[0]["relationship"]) >= before_rel, "Rivals relationship improvement")
    check(rivals.district_pressure(0) >= 0, "Rivals pressure calculation")
    check(rivals.supplier_pressure(0) >= 0, "Rivals supplier pressure")
    check(rivals.alliance_bonus(0).has("sales"), "Rivals alliance calculation")
    check(rivals.deal_bonus(0).has("sales"), "Rivals deal calculation")
    rivals.daily_update(10)
    rivals.strategic_update(10, 0, 100)

    var supply = load("res://scripts/supply_chain.gd").new()
    supply._normalize()
    check(not bool(supply.acquire_from_market("unknown", 1, 100000, null).get("ok", true)), "Supply unknown resource")
    check(supply.snapshot().has("network_stock"), "Supply snapshot")
    supply.reset_day()
    check(supply.competitor_pressure >= 0, "Supply reset day")

    var contracts = load("res://scripts/supply_contracts.gd").new()
    contracts._normalize()
    check(contracts.snapshot().has("contracts"), "Contracts snapshot")
    var contract_state = contracts.snapshot()
    contracts.load_snapshot(contract_state)
    check(contracts.resource_discount("materials") >= 0.0, "Contracts snapshot restore")
    check(contracts.pressure_reduction("materials") >= 0, "Contracts pressure reduction")

    var missions = load("res://scripts/world_missions.gd").new()
    check(missions.missions.size() == 6, "World mission catalog")
    check(missions.has_method("_spawn") and missions.has_method("_spend") and missions.has_method("_complete"), "World mission helpers")

    var events = load("res://scripts/events.gd").new()
    var seen := {}
    for i in range(50):
        var event = events.roll()
        check(event.has("title") and event.has("cash") and event.has("rep"), "Event schema %d" % i)
        seen[String(event["title"])] = true
    check(seen.size() > 1, "Event variety")

    var goals = load("res://scripts/empire_goals.gd").new()
    check(goals.current_goal().has("title"), "Empire goal current")
    check(goals.completed_count() >= 0, "Empire goal count")
    check(goals.goals.size() >= 8, "Empire goal catalog")

    var tutorial = load("res://scripts/tutorial.gd").new()
    var t0 = tutorial.current()
    check(t0["action"] == "INSPECT", "Tutorial initial step")
    tutorial.load_snapshot({"step":999,"completed":false})
    check(tutorial.completed, "Tutorial clamps completed state")
    check(tutorial.snapshot().has("step"), "Tutorial snapshot")

    var branches = load("res://scripts/branches.gd").new()
    branches._normalize()
    check(not bool(branches.select(-1).get("ok", true)), "Branches invalid negative index")
    check(not bool(branches.select(99).get("ok", true)), "Branches invalid high index")
    check(not bool(branches.stock(1, 0).get("ok", true)), "Branches zero shipment")
    check(bool(branches.launch(1, 100000).get("ok", false)), "Branches launch edge")
    check(branches.operate_day(regions).has("profit"), "Branches operate day")
    check(branches._money(123456) == "123456", "Branches money formatting")

func test_scene_controllers() -> void:
    var scene = load("res://scenes/Main.tscn")
    if scene == null:
        check(false, "Controller scene available")
        return
    var g = scene.instantiate()
    root.add_child(g)
    await process_frame
    g.cash = 500000
    g.reputation = 100
    g.expansion.unlock_from_reputation(100)

    var rc = g.get_node("RegionController")
    check(rc.has_method("select_region") and rc.has_method("establish_region") and rc.has_method("upgrade_infrastructure") and rc.has_method("establish_trade_route") and rc.has_method("dispatch_goods"), "Region controller full API")
    rc.select_region(1)
    check(rc.regions.selected == 1, "Region controller selection")
    rc.establish_region()
    check(rc.regions.player_presence[1] > 0, "Region controller establishment")
    var income_before: int = int(g.cash)
    check(rc.branch_income() >= 0, "Region controller branch income")
    rc.apply_branch_income()
    check(g.cash >= income_before, "Region controller income application")
    rc.upgrade_infrastructure()
    rc.establish_trade_route()

    var es = g.get_node("EmpireController")
    for n in ["select_business","select_resource","produce_selected","sell_selected","hire_selected","price_selected","toggle_selected","harvest_selected_resource","buy_selected_resource_site","upgrade_selected_resource_site","dispatch_internal_supply","management_upgrade","district_cycle","upgrade_transport"]:
        check(es.has_method(n), "Empire controller API " + n)
    es.select_business(0)
    es.select_resource(0)
    es.toggle_selected()
    es.toggle_selected()
    es.price_selected(5)
    es.price_selected(-5)
    es.district_cycle()
    check(es.selected == 0 and es.selected_resource == 0, "Empire controller selection")

    var rs = g.get_node("RivalSupplyController")
    check(rs.has_method("control_summary") and rs.has_method("_advance_competition"), "Rival supply controller API")
    check(rs.control_summary() != "", "Rival supply control summary")
    rs._advance_competition(6)
    check(g.get_node("SupplyChainController").supply.competitor_pressure >= 0, "Rival supply pressure update")

    var bridge = g.get_node("GameStateBridge")
    check(bridge.has_method("_state") and bridge.has_method("_save_extended_state") and bridge.has_method("_load_extended_state"), "State bridge full API")
    var state = bridge._state()
    check(int(state.get("version", 0)) == 2, "State bridge version")
    bridge._save_extended_state(false)
    bridge._load_extended_state()

    var save = load("res://scripts/save_system.gd")
    check(save != null, "Save system loads")
    check(save.save_game({"edge":true}), "Save system writes")
    check(bool(save.load_game().get("edge", false)), "Save system reads")

    var sh = g.get_node("StrategyHUD")
    check(sh.label != null, "Strategy HUD label")
    sh._process(0.0)
    check(String(sh.label.text) != "", "Strategy HUD refresh")

    var ui = g.get_node("MobileUI")
    for width in [320.0, 360.0, 480.0, 700.0, 1080.0]:
        ui.root.size = Vector2(width, 720.0)
        ui._layout_responsive()
        check(ui.tabs.size.x > 0 and ui.action_scroll.size.x > 0, "Mobile responsive width %.0f" % width)

    var wm = g.get_node("WorldMissions")
    g.cash = 500000
    wm._spawn()
    check(wm.active and wm.title != "" and wm.option_a != "" and wm.option_b != "", "World mission spawn")
    wm.choose_b()
    check(not wm.active and wm.completed > 0, "World mission decline")

    g.free()
    await process_frame

func test_save_system() -> void:
    var save = load("res://scripts/save_system.gd")
    check(save.save_game({"number":123,"nested":{"ok":true}}), "Save system roundtrip write")
    var data = save.load_game()
    check(int(data.get("number", 0)) == 123, "Save system roundtrip number")
    check(bool(data.get("nested", {}).get("ok", false)), "Save system roundtrip nested")
