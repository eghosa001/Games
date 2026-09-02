extends SceneTree
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if ok: passed += 1; print("PASS: " + label)
    else: failed += 1; push_error("FAIL: " + label)
func run() -> void:
    var s = load("res://scenes/Main.tscn"); check(s != null, "scene loads")
    if s != null:
        var g = s.instantiate(); root.add_child(g); await process_frame
        for n in ["inspect_property","acquire_property","restore_property","open_business","buy_inputs","produce_goods","hire_employee","upgrade_business","marketing_campaign","change_price","cycle_supplier","sign_contract","advance_day","buy_expansion","upgrade_expansion","select_rival","select_expansion","select_district","improve_alliance","make_alliance_offer","propose_supply_deal","propose_customer_partnership","negotiate_selected_acquisition","reject_selected_acquisition","take_loan","repay_loan","upgrade_transport","acquire_rival_asset","save_game","load_game"]: check(g.has_method(n), "Main " + n)
        for n in ["Economy","Production","Districts","RestorationStrategy","Expansion","RegionController","Corporate","SupplyChainController","WorldMissions","MarketDirector","MobileUI","BranchController"]: check(g.get_node_or_null(n) != null, "Controller " + n)
        var c = g.get_node("Corporate")
        for n in ["_recalculate","_check_milestones","show_status","raise_capital","buyback_shares","pay_dividend","strengthen_defense","strategic_ally_defense","influence_board","hostile_takeover","process_day","get_summary","save_state","load_state"]: check(c.has_method(n), "Corporate " + n)
        g.cash = 500000; g.reputation = 100; g.total_profit = 100000; g.acquisition_count = 4; g.business_open = true; c.show_status(); check(String(g.message) != "", "Corporate status")
        var stake = c.investor_stake; c.raise_capital(); check(c.investor_stake > stake, "Corporate raise"); c.buyback_shares(); c.pay_dividend(); c.strengthen_defense(); c.influence_board(); c.takeover_cooldown = 2; c.hostile_takeover(); check(String(g.message).contains("cooling down"), "Corporate gate")
        c.process_day(); var state = c.save_state(); c.load_state(state); check(c.get_summary().has("valuation"), "Corporate persistence")
        var m = g.get_node("MarketDirector")
        for n in ["market_status","respond_aggressively","respond_balanced","respond_defensively","snapshot","_spawn_event","_apply_event_pressure","_clear_effect"]: check(m.has_method(n), "Market " + n)
        for e in m.events: m.active_event = e["name"]; m.event_text = e["text"]; m.event_expiry = g.day + 2; m.respond_balanced(); check(m.active_event == "", "Market response " + e["name"])
        m._apply_event_pressure("shortage", g.day + 2); check(float(g.economy.quote("materials",1)["market_factor"]) == 1.25, "Market shortage"); m._clear_effect(); check(float(g.economy.quote("materials",1)["market_factor"]) == 1.0, "Market clear")
        var u = g.get_node("MobileUI"); for n in ["_layout_responsive","_set_tab","_refresh","_run_action"]: check(u.has_method(n), "Mobile " + n)
        for i in range(4): u._set_tab(i); check(u.active_tab == i and u.actions.get_child_count() > 0, "Mobile tab %d" % i)
        g.free(); await process_frame
    var b = load("res://scripts/branches.gd").new(); b._normalize(); check(b.current().has("name"), "Branches current"); check(b.select(1)["ok"], "Branches select"); check(not b.launch(1, 1)["ok"], "Branches cash gate"); check(b.launch(1, 100000)["ok"], "Branches launch"); check(b.hire(1,100000)["ok"], "Branches hire"); check(b.stock(1,5)["ok"], "Branches stock"); check(b.change_price(1,10)["ok"], "Branches price"); check(b.upgrade(1,100000)["ok"], "Branches upgrade"); check(b._money(1234)=="1234", "Branches money")
    var r = load("res://scripts/regions.gd").new(); r.update_unlocks(100); check(r.select(1,100)["ok"], "Regions select deep"); check(r.current().has("name"), "Regions current deep"); check(r.trade_route_bonus(1)>=0, "Regions route bonus")
    var ec = load("res://scripts/empire_controller.gd").new(); check(ec != null, "Empire controller loads")
    var eg = load("res://scripts/empire_goals.gd").new(); check(eg.goals.size() >= 8, "Empire goals catalog"); check(eg.current_goal().has("title"), "Empire current goal"); check(eg.completed_count() >= 0, "Empire goal count")
    var bridge = load("res://scripts/game_state_bridge.gd").new(); check(bridge != null, "State bridge loads")
    for pair in [["economy.gd","supplier_for"],["production.gd","produce"],["districts.gd","business_multiplier"],["restoration_strategy.gd","choose_budget"],["expansion.gd","operate_day"],["regions.gd","market_multiplier"],["competitors.gd","alliance_bonus"],["supply_chain.gd","daily_network_update"],["supply_contracts.gd","snapshot"],["world_missions.gd","choose_a"],["events.gd","roll"],["progression.gd","_check_milestones"],["tutorial.gd","notify"]]:
        var obj = load("res://scripts/" + pair[0]).new(); check(obj != null, "Load " + pair[0]); check(obj.has_method(pair[1]), "API " + pair[0])
    var contracts = load("res://scripts/supply_contracts.gd").new(); contracts._normalize(); check(contracts.resource_discount("materials") == 0.0, "Contract initial discount"); check(contracts.pressure_reduction("materials") == 0, "Contract initial pressure")
    print("EXTENDED RESULT: %d passed, %d failed" % [passed, failed]); quit(1 if failed > 0 else 0)
