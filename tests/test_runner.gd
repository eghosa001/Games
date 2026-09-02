extends SceneTree

var passed := 0
var failed := 0
var failures: Array[String] = []

func _init() -> void:
    call_deferred("run")

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        failures.append(label)
        push_error("FAIL: " + label)

func run() -> void:
    randomize()
    test_economy()
    test_production()
    test_districts()
    test_restoration()
    test_expansion()
    test_regions()
    test_rivals()
    test_supply()
    test_contracts()
    test_world_missions()
    test_events()
    test_progression()
    test_main_scene()
    print("\nRENEW TEST RESULT: %d passed, %d failed" % [passed, failed])
    if failed > 0:
        for item in failures:
            print("FAILED: " + item)
        quit(1)
    quit(0)

func test_economy() -> void:
    var e = load("res://scripts/economy.gd").new()
    check(not e.supplier_for("materials", 1).is_empty(), "economy supplier_for")
    var quote = e.quote("materials", 10, 0)
    check(bool(quote.get("ok", false)) and int(quote["cost"]) > 0, "economy quote")
    var before = int(e.resources["materials"]["stock"])
    var bought := false
    for i in range(20):
        var buy = e.buy_resource("materials", 5, 100000, 2)
        if bool(buy.get("ok", false)):
            bought = true
            break
    check(bought and int(e.resources["materials"]["stock"]) == before + 5, "economy buy_resource")
    e.set_market_modifier("materials", 1.5)
    check(float(e.quote("materials", 1)["market_factor"]) == 1.5, "economy set_market_modifier")
    e.clear_market_modifiers()
    check(float(e.quote("materials", 1)["market_factor"]) == 1.0, "economy clear_market_modifiers")
    e.end_market_day()
    check(int(e.resources["materials"]["stock"]) >= 15, "economy end_market_day")

func test_production() -> void:
    var e = load("res://scripts/economy.gd").new()
    var p = load("res://scripts/production.gd").new()
    var result = p.produce(e, 3)
    check(bool(result["ok"]) and int(result["output"]) > 0, "production produce")
    var empty = load("res://scripts/economy.gd").new()
    empty.resources["materials"]["stock"] = 0
    var stopped = p.produce(empty, 3)
    check(not bool(stopped["ok"]), "production stops on missing input")

func test_districts() -> void:
    var d = load("res://scripts/districts.gd").new()
    d.update_unlocks(0)
    check(bool(d.current()["unlocked"]), "districts update_unlocks")
    check(not bool(d.select(1)["ok"]), "districts rejects locked district")
    d.update_unlocks(50)
    check(bool(d.select(3)["ok"]), "districts select unlocked district")
    check(d.business_multiplier("Consumer Goods") > 0.0, "districts business_multiplier")
    check(d.logistics_cost(100) > 0, "districts logistics_cost")
    check(d.competition_pressure() > 0.0, "districts competition_pressure")

func test_restoration() -> void:
    var r = load("res://scripts/restoration_strategy.gd").new()
    check(r.plans.has("Budget") and r.plans.has("Standard") and r.plans.has("Premium"), "restoration plans")
    var game = load("res://tests/fake_game.gd").new()
    root.add_child(game)
    r.game = game
    r.choose_budget()
    check(r.applied and r.selected == "Budget", "restoration choose_budget")
    check(r.summary().contains("Budget"), "restoration summary")
    r.choose_standard()
    check(r.selected == "Standard", "restoration choose_standard")
    r.choose_premium()
    check(r.selected == "Premium", "restoration choose_premium")
    game.free()

func test_expansion() -> void:
    var x = load("res://scripts/expansion.gd").new()
    check(x.get_property_count() == 3, "expansion property count")
    check(x.get_resource_site_count() == 3, "expansion resource site count")
    x.unlock_from_reputation(100)
    check(not x.selected(0).is_empty(), "expansion selected")
    check(bool(x.buy(0, 100000)["ok"]), "expansion buy")
    check(bool(x.upgrade(0, 100000)["ok"]), "expansion upgrade")
    check(bool(x.buy_resource_site(0, 100000)["ok"]), "expansion buy_resource_site")
    check(bool(x.generate_resource(0)["ok"]), "expansion generate_resource")
    var summary = x.get_summary()
    check(summary.has("management_level") and summary.has("management_overhead"), "expansion summary management state")
    var day = x.operate_day()
    check(day.has("profit") and day.has("businesses"), "expansion operate_day")

func test_regions() -> void:
    var r = load("res://scripts/regions.gd").new()
    r._normalize()
    r.update_unlocks(100)
    var select = r.select(2, 100)
    check(bool(select["ok"]), "regions select")
    check(r.current().has("name"), "regions current")
    check(r.market_multiplier("Consumer Goods") > 0.0, "regions market_multiplier")
    check(r.logistics_cost(100.0, 0, 2) > 0.0, "regions logistics_cost")
    check(r.regional_resource_bonus("fuel") >= 0.0, "regions regional_resource_bonus")
    check(r.competition_pressure() >= 0.0, "regions competition_pressure")
    r.daily_update(7)
    check(r.trade_route_bonus(2) >= 0.0, "regions trade_route_bonus")

func test_rivals() -> void:
    var r = load("res://scripts/competitors.gd").new()
    r._normalize()
    check(r.rivals.size() >= 3, "rivals normalize")
    var idx = 0
    check(r.improve_relationship(idx) != "", "rivals improve_relationship")
    var alliance = r.offer_alliance(idx)
    check(alliance.has("ok") and alliance.has("message"), "rivals offer_alliance")
    var deal = r.propose_supply_deal(idx)
    check(deal.has("ok") and deal.has("message"), "rivals propose_supply_deal")
    var customer = r.propose_customer_partnership(idx)
    check(customer.has("ok") and customer.has("message"), "rivals propose_customer_partnership")
    check(r.district_pressure(0) >= 0, "rivals district_pressure")
    check(r.alliance_bonus(idx).has("sales"), "rivals alliance_bonus")
    check(r.deal_bonus(idx).has("sales"), "rivals deal_bonus")
    check(r.supplier_pressure(0) >= 0, "rivals supplier_pressure")
    r.daily_update(2)
    r.strategic_update(2, 0, 20)

func test_supply() -> void:
    var s = load("res://scripts/supply_chain.gd").new()
    s._normalize()
    check(s.network_stock.has("materials"), "supply normalize")
    var x = load("res://scripts/expansion.gd").new()
    x.unlock_from_reputation(100)
    check(bool(x.buy_resource_site(0, 100000)["ok"]), "supply resource prerequisite")
    check(bool(x.generate_resource(0)["ok"]), "supply generated stock")
    var moved = s.move_from_site(x.resource_sites[0], 3, 100)
    check(bool(moved["ok"]), "supply move_from_site")
    var market = s.acquire_from_market("materials", 5, 100000, null)
    check(market.has("ok") and market.has("message"), "supply acquire_from_market")
    check(bool(x.buy(0, 100000)["ok"]), "supply business prerequisite")
    var supplied = s.supply_business(x.properties[0], 1, 100)
    check(supplied.has("ok") and supplied.has("message"), "supply supply_business")
    var daily = s.daily_network_update(x, 100)
    check(daily.has("generated") and daily.has("moved"), "supply daily_network_update")
    var check_daily = s.daily_business_check(x)
    check(check_daily.has("count"), "supply daily_business_check")
    s.reset_day()

func test_contracts() -> void:
    var c = load("res://scripts/supply_contracts.gd").new()
    c._normalize()
    var fake = load("res://tests/fake_game.gd").new()
    fake.set("reputation", 100)
    fake.set("cash", 100000)
    root.add_child(fake)
    var negotiated = c.negotiate(0, "materials", fake)
    check(negotiated.has("ok") and negotiated.has("message"), "contracts negotiate")
    var rights = c.secure_resource("materials", fake)
    check(rights.has("ok") and rights.has("message"), "contracts secure_resource")
    check(c.resource_discount("materials") >= 0.0, "contracts resource_discount")
    c.daily_update()
    fake.free()

func test_world_missions() -> void:
    var w = load("res://scripts/world_missions.gd").new()
    check(w.missions.size() >= 6, "world missions data")
    check(w.has_method("_spawn"), "world missions spawn")
    check(w.has_method("choose_a") and w.has_method("choose_b"), "world missions choices")

func test_events() -> void:
    var e = load("res://scripts/events.gd").new()
    for i in range(10):
        var event = e.roll()
        check(event.has("title") and event.has("cash") and event.has("rep"), "events roll #%d" % (i + 1))

func test_progression() -> void:
    var p = load("res://scripts/progression.gd").new()
    check(p.milestones.size() >= 6, "progression milestones")
    check(p.has_method("_check_milestones"), "progression milestone checker")
    check(p.has_method("_save_state") and p.has_method("_load_state"), "progression persistence methods")

func test_main_scene() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "main scene loads")
    if scene == null:
        return
    var instance = scene.instantiate()
    check(instance != null, "main scene instantiates")
    root.add_child(instance)
    await process_frame
    check(instance.has_method("inspect_property"), "main inspect_property")
    check(instance.has_method("advance_day"), "main advance_day")
    check(instance.has_method("buy_expansion"), "main buy_expansion")
    check(instance.has_method("save_game"), "main save_game")
    check(instance.has_method("load_game"), "main load_game")
    instance.free()
    await process_frame
