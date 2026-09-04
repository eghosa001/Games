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
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads")
    if scene == null:
        quit(1)
        return

    var game = scene.instantiate()
    root.add_child(game)
    await process_frame

    for method in ["inspect_property", "acquire_property", "restore_property", "choose_business_purpose", "open_business", "buy_inputs", "produce_goods", "advance_day", "save_game", "load_game", "upgrade_transport"]:
        check(game.has_method(method), "Main API " + method)

    check(game.command_system != null, "Command system is attached")
    check(game.command_system.property_system != null, "Property command system is attached")
    check(game.command_system.business_system != null, "Business command system is attached")
    check(game.command_system.employee_system != null, "Employee command system is attached")
    check(game.command_system.finance_system != null, "Finance command system is attached")
    check(game.command_system.supply_system != null, "Supply command system is attached")
    check(game.command_system.expansion_system != null, "Expansion command system is attached")
    check(game.command_system.business_system.production != null, "Business owns authoritative production")

    var corporate = game.get_node_or_null("World/Corporate")
    check(corporate != null, "Corporate controller exists")
    if corporate != null:
        for method in ["show_status", "raise_capital", "buyback_shares", "pay_dividend", "strengthen_defense", "influence_board", "hostile_takeover", "process_day", "get_summary", "save_state", "load_state"]:
            check(corporate.has_method(method), "Corporate API " + method)

    var market = game.get_node_or_null("Systems/MarketDirector")
    check(market != null, "Market director exists")
    if market != null:
        for method in ["market_status", "respond_aggressively", "respond_balanced", "respond_defensively", "snapshot"]:
            check(market.has_method(method), "Market API " + method)

    var region = game.get_node_or_null("World/RegionController")
    check(region != null, "Region controller exists")
    if region != null:
        for method in ["select_region", "establish_region", "upgrade_infrastructure", "establish_trade_route", "dispatch_goods"]:
            check(region.has_method(method), "Region API " + method)

    var branch = game.get_node_or_null("World/BranchController")
    check(branch != null, "Branch controller exists")
    if branch != null:
        for method in ["select_branch", "launch_selected", "stock_selected", "hire_selected", "upgrade_selected", "price_selected"]:
            check(branch.has_method(method), "Branch API " + method)

    var rival_supply = game.get_node_or_null("World/RivalSupplyController")
    check(rival_supply != null, "Rival supply controller exists")
    if rival_supply != null:
        check(rival_supply.has_method("control_summary"), "Rival supply summary API")
        check(rival_supply.has_method("_advance_competition"), "Rival supply simulation API")

    var missions = game.get_node_or_null("World/WorldMissions")
    check(missions != null, "World missions controller exists")
    if missions != null:
        check(missions.has_method("_spawn"), "World mission spawn API")
        check(missions.has_method("choose_a") and missions.has_method("choose_b"), "World mission choice API")

    var state = get_root().get_node_or_null("RenewGameState")
    check(state != null, "Canonical GameState autoload exists")
    var finance = get_root().get_node_or_null("RenewFinanceSystem")
    var simulation = get_root().get_node_or_null("RenewSimulationSystem")
    check(finance != null, "FinanceSystem autoload exists")
    check(simulation != null, "SimulationSystem autoload exists")

    if state != null:
        check(state.get_domain("economy") is Dictionary, "Economy domain exists")
        check(state.get_domain("properties") is Dictionary, "Properties domain exists")
        check(state.get_domain("employees") is Dictionary, "Employees domain exists")
        check(state.get_domain("production") is Dictionary, "Production domain exists")
        state.set_value("economy", "cash", 25000)
        check(int(finance.get("cash")) == 25000, "Domain cash writes synchronize finance ledger")
        state.set_value("finance", "debt", 0)
        state.set_value("finance", "loan_payment", 0)

    game.command_system.finance_system.take_loan()
    check(int(finance.get("debt")) > 0, "Loan command updates canonical finance debt")
    check(int(finance.get("cash")) == int(state.get_value("economy", "cash", 0)), "Loan cash mirror matches finance ledger")
    var debt_before_repay: int = int(finance.get("debt"))
    game.command_system.finance_system.repay_loan()
    check(int(finance.get("debt")) < debt_before_repay, "Repayment command reduces canonical debt")
    check(int(finance.get("cash")) == int(state.get_value("economy", "cash", 0)), "Repayment cash mirror matches finance ledger")

    game.queue_free()
    await process_frame

    var production = load("res://scripts/production_system.gd").new()
    check(production != null, "ProductionSystem loads")
    var economy = load("res://scripts/economy.gd").new()
    economy.resources["timber"]["stock"] = 20
    economy.resources["iron"]["stock"] = 20
    economy.resources["energy"]["stock"] = 20
    var produced = production.produce(economy, 3, "furniture")
    check(bool(produced.get("ok", false)), "ProductionSystem furniture fixture succeeds")

    print("EXTENDED RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
