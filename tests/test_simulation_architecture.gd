extends SceneTree

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
    if ok: passed += 1; print("PASS: " + label)
    else: failed += 1; push_error("FAIL: " + label)

func _init() -> void: call_deferred("run")

func run() -> void:
    var Finance = load("res://scripts/finance_system.gd")
    var Production = load("res://scripts/production_system.gd")
    var Simulation = load("res://scripts/simulation_system.gd")
    check(Finance != null, "FinanceSystem loads")
    check(Production != null, "ProductionSystem loads")
    check(Simulation != null, "SimulationSystem loads")
    if Finance == null or Production == null or Simulation == null:
        quit(1); return

    var finance = Finance.new(); root.add_child(finance)
    var production = Production.new(); root.add_child(production)
    var simulation = Simulation.new(); root.add_child(simulation)
    await process_frame

    check(finance.spend(1000, "test")["ok"], "Finance owns spending")
    check(finance.available_cash() == 24000, "Finance mutates authoritative cash")
    check(finance.take_loan(5000)["ok"], "Finance owns borrowing")
    check(finance.debt == 5000, "Finance owns debt")

    var economy_script = load("res://scripts/economy.gd")
    var economy = economy_script.new()
    economy.resources["materials"]["stock"] = 5
    economy.resources["packaging"]["stock"] = 5
    economy.resources["fuel"]["stock"] = 5
    var produced = production.produce(economy, 3)
    check(produced["ok"], "Production command succeeds")
    check(production.finished_goods == produced["output"], "ProductionSystem owns finished goods")

    var snapshot = simulation.capture_state()
    check(snapshot.has("finance"), "Simulation captures Finance state")
    check(snapshot.has("production"), "Simulation captures Production state")
    check(simulation.execute("receive", {"amount": 500, "reason": "test"})["ok"], "Simulation routes finance command")

    print("SIMULATION ARCHITECTURE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
