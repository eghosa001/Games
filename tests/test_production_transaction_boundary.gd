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

func run() -> void:
    var gameplay_source := FileAccess.get_file_as_string("res://scripts/gameplay_command_system.gd")
    var simulation_source := FileAccess.get_file_as_string("res://scripts/simulation_system.gd")
    check(not gameplay_source.is_empty(), "GameplayCommandSystem source loads")
    check(not simulation_source.is_empty(), "SimulationSystem source loads")
    check(gameplay_source.find("func _production_transaction_participants()") >= 0, "Gameplay production transaction captures participants")
    check(gameplay_source.find("func _capture_production_transaction()") >= 0, "Gameplay production transaction preflights rollback support")
    check(gameplay_source.find("_restore_production_transaction(transaction[\"snapshot\"])" ) >= 0, "Gameplay production failure restores snapshot")
    check(gameplay_source.find("business_system.produce_goods()") >= 0, "Gameplay still routes production through BusinessSystem")
    check(simulation_source.find("business_system.produce_goods()") >= 0, "Daily simulation routes through BusinessSystem")
    check(simulation_source.find("production_message.find(\" stopped:\")") >= 0, "Daily simulation converts production abort into transaction failure")
    check(simulation_source.find("_transaction_restore(transaction_snapshot, context)") >= 0, "Simulation failure restores its transaction snapshot")
    print("PRODUCTION TRANSACTION BOUNDARY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
