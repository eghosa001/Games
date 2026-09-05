extends SceneTree

var passed := 0
var failed := 0

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("run")

func _read(path: String) -> String:
    if not FileAccess.file_exists(path):
        return ""
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return ""
    return file.get_as_text()

func run() -> void:
    var market := _read("res://scripts/market_director.gd")
    check(not market.contains("game.cash -="), "Market responses do not directly subtract game cash")
    check(not market.contains("game.cash +="), "Market responses do not directly add game cash")
    check(market.contains("finance.spend"), "Market spending routes through FinanceSystem")
    check(market.contains("finance.receive"), "Market rewards route through FinanceSystem")
    check(market.contains("_sync_legacy_cash"), "Legacy cash mirror is synchronized after finance transactions")

    var simulation := _read("res://scripts/simulation_system.gd")
    check(not simulation.contains("finance.cash = int(game_state.get_value(\"economy\", \"cash\""), "Simulation does not overwrite Finance cash from legacy state")
    check(not simulation.contains("finance.debt = int(game_state.get_value(\"finance\", \"debt\""), "Simulation does not overwrite Finance debt from legacy state")
    check(simulation.contains("func _sync_state_from_finance"), "Simulation has an explicit Finance-to-state mirror")

    var bankruptcy := _read("res://scripts/bankruptcy_system.gd")
    check(not bankruptcy.contains("finance.cash = int(game.cash)"), "Bankruptcy does not overwrite Finance cash from legacy game cash")
    check(not bankruptcy.contains("finance.debt = int(game.debt)"), "Bankruptcy does not overwrite Finance debt from legacy game debt")
    check(not bankruptcy.contains("finance.loan_payment = int(game.loan_payment)"), "Bankruptcy does not overwrite Finance payment schedule from legacy game state")

    var finance_script := _read("res://scripts/finance_system.gd")
    check(finance_script.contains("func capture_state()"), "FinanceSystem exposes transaction snapshots")
    check(finance_script.contains("func restore_state(snapshot: Dictionary)"), "FinanceSystem exposes transaction rollback")
    check(finance_script.contains("accrued_interest"), "FinanceSystem models accrued interest explicitly")
    check(finance_script.contains("func validate_invariants()"), "FinanceSystem exposes accounting invariants")

    print("\nRENEW FINANCE AUTHORITY PATH RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
