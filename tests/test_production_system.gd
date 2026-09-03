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
    var Production = load("res://scripts/production_system.gd")
    check(Production != null, "ProductionSystem loads")
    if Production == null:
        quit(1)
        return
    var production = Production.new()
    root.add_child(production)
    await process_frame

    for stage in ["extraction", "processing", "manufacturing", "distribution", "retail"]:
        check(production.recipe_ids(stage).size() > 0, "Recipes exist for " + stage)

    check(production.acquire_machine("processor", 3), "Processor machinery can be acquired")
    check(production.acquire_machine("factory", 3), "Factory machinery can be acquired")
    check(production.acquire_machine("fleet", 3), "Fleet machinery can be acquired")
    check(production.acquire_machine("store", 3), "Retail machinery can be acquired")
    production.unlock_technology("steel_processing")
    production.unlock_technology("furniture_manufacturing")
    production.unlock_technology("logistics")
    production.unlock_technology("retail")
    production.add_inventory("iron_ore", 10)
    production.add_inventory("fuel", 20)
    production.add_inventory("packaging", 10)

    var steel = production.run_recipe("process_steel", 2)
    check(steel["ok"], "Processing converts intermediate input")
    check(production.stock("steel") > 0, "Intermediate goods are stored")

    production.add_inventory("lumber", 10)
    var furniture = production.run_recipe("manufacture_furniture", 2)
    check(furniture["ok"], "Manufacturing recipe runs")
    check(production.stock("furniture") > 0, "Manufactured goods are stored")

    var before_condition := float(production.machines["factory"]["condition"])
    var distributed = production.run_recipe("distribute_furniture", 1)
    check(distributed["ok"], "Distribution recipe runs")
    check(float(production.machines["fleet"]["condition"]) < 100.0, "Distribution machinery condition degrades")
    check(before_condition < 100.0, "Manufacturing consumes machine condition")

    var retail = production.run_recipe("retail_furniture", 1)
    check(retail["ok"], "Retail recipe runs")
    check(production.finished_goods > 0, "Retail creates customer-ready output")

    check(float(production.utilization["factory"]) > 0.0, "Utilization is tracked")
    check(production.waste.has("furniture"), "Waste is tracked")

    check(production.set_automation("factory", 3), "Automation can be upgraded")
    check(int(production.machines["factory"]["automation"]) == 3, "Automation level is tracked")
    var condition_before_maintenance := float(production.machines["factory"]["condition"])
    var maintenance = production.maintain_machine("factory")
    check(maintenance["ok"], "Maintenance restores machinery")
    check(float(production.machines["factory"]["condition"]) == 100.0, "Maintenance restores condition")
    check(condition_before_maintenance < 100.0, "Maintenance starts from degraded machine")

    var snapshot: Dictionary = production.capture_state()
    var restored = Production.new()
    root.add_child(restored)
    restored.restore_state(snapshot)
    check(restored.stock("steel") == production.stock("steel"), "Production inventory survives save/restore")
    check(restored.machines["factory"]["automation"] == production.machines["factory"]["automation"], "Automation survives save/restore")
    check(restored.history.size() == production.history.size(), "Production history survives save/restore")

    print("PRODUCTION SYSTEM RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
