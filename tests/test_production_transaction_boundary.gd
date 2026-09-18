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
    check(gameplay_source.find("func _production_transaction_participants()") < 0, "Gameplay does not duplicate BusinessSystem production transaction ownership")
    check(gameplay_source.find("var result:Dictionary=business_system.produce_goods()") >= 0, "Gameplay consumes BusinessSystem structured production result")
    check(gameplay_source.find("after_message.find") < 0, "Gameplay does not infer production success from UI copy")
    check(simulation_source.find("business_system.produce_goods()") >= 0, "Daily simulation routes through BusinessSystem")
    check(simulation_source.find("production_message.find(\" stopped:\")") >= 0, "Daily simulation converts production abort into transaction failure")
    check(simulation_source.find("_transaction_restore(transaction_snapshot, context)") >= 0, "Simulation failure restores its transaction snapshot")
    print("PRODUCTION TRANSACTION BOUNDARY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
