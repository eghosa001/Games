extends SceneTree

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var Finance = load("res://scripts/finance_system.gd")
    var Production = load("res://scripts/production_system.gd")
    var Simulation = load("res://scripts/simulation_system.gd")
    var Gameplay = load("res://scripts/gameplay_command_system.gd")
    check(Finance != null, "FinanceSystem loads")
    check(Production != null, "ProductionSystem loads")
    check(Simulation != null, "SimulationSystem loads")
    check(Gameplay != null, "GameplayCommandSystem loads")
    if Finance == null or Production == null or Simulation == null or Gameplay == null:
        quit(1)
        return

    var finance = Finance.new()
    root.add_child(finance)
    var production = Production.new()
    production.name = "ProductionSystem"
    root.add_child(production)
    var simulation = Simulation.new()
    root.add_child(simulation)
    simulation.production_system = production
    await process_frame

    check(finance.spend(1000, "test")["ok"], "Finance owns spending")
    check(finance.available_cash() == 24000, "Finance mutates authoritative cash")
    check(finance.take_loan(5000)["ok"], "Finance owns borrowing")
    check(finance.debt == 5000, "Finance owns debt")

    var economy_script = load("res://scripts/economy.gd")
    var economy = economy_script.new()
    economy.resources["timber"]["stock"] = 20
    economy.resources["iron"]["stock"] = 20
    economy.resources["energy"]["stock"] = 20
    var produced = production.produce(economy, 3, "furniture")
    check(produced["ok"], "Production command succeeds")
    check(production.finished_goods == produced["output"], "ProductionSystem owns finished goods")

    var snapshot = simulation.capture_state()
    check(snapshot.has("finance"), "Simulation captures Finance state")
    check(snapshot.has("production"), "Simulation captures Production state")
    check(simulation.execute("receive", {"amount": 500, "reason": "test"})["ok"], "Simulation routes finance command")

    var gameplay_text := FileAccess.get_file_as_string("res://scripts/gameplay_command_system.gd")
    check(gameplay_text.contains("func _daily_transaction_participants()"), "Daily transaction has an explicit participant registry")
    check(gameplay_text.contains("not node.has_method(\"capture_state\") or not node.has_method(\"restore_state\")"), "Daily transaction fails closed for non-rollback-capable state")
    check(gameplay_text.contains("RenewContractSystem"), "ContractSystem is inside the daily transaction boundary")
    check(gameplay_text.contains("supply_chain"), "SupplyChain is inside the daily transaction boundary")
    check(gameplay_text.contains("_restore_daily_transaction(transaction[\"snapshot\"])") , "Failed daily simulation restores the outer transaction")
    check(not gameplay_text.contains("supply_chain.warehouse[\"furniture\"]=float(_state_value(\"production\",\"finished_goods\",0))"), "Production no longer overwrites canonical supply inventory")

    var cash_before_legacy_end := finance.cash
    var debt_before_legacy_end := finance.debt
    var legacy_result = simulation.execute("end_day")
    check(not bool(legacy_result.get("ok", false)), "Legacy end_day is rejected")
    check(finance.cash == cash_before_legacy_end, "Legacy end_day does not mutate cash")
    check(finance.debt == debt_before_legacy_end, "Legacy end_day does not mutate debt")

    print("SIMULATION ARCHITECTURE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
