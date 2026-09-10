extends SceneTree

const DemandModel = preload("res://scripts/demand_model.gd")

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var failures: Array[String] = []
    var failed := 0
    var packed := load("res://scenes/Main.tscn") as PackedScene
    var game: Node = null
    if packed == null:
        failed += 1; failures.append("Main scene must load for demand integration")
    else:
        game = packed.instantiate()
        root.add_child(game)
        current_scene = game
        await process_frame
        await process_frame
        await process_frame

    var culture: Node = null
    var services := root.get_node_or_null("RenewServices")
    if services != null and services.has_method("get_service"):
        culture = services.get_service("RenewCompanyCultureSystem")
    if culture == null or not culture.has_method("set_dimension"):
        failed += 1;failures.append("Company Culture System must be available for demand integration")
    else:
        var model = DemandModel.new()
        game.add_child(model)
        await process_frame
        culture.set_dimension("quality", 40, 1, "demand integration baseline")
        var low: Dictionary = model.calculate("furniture", 160.0, 120.0, 10, 75, 0, 0, 1.0, 1.0, 0.0, 0.0, 0.0)
        culture.set_dimension("quality", 100, 1, "demand integration improvement")
        var high: Dictionary = model.calculate("furniture", 160.0, 120.0, 10, 75, 0, 0, 1.0, 1.0, 0.0, 0.0, 0.0)
        if not bool(low.get("ok", false)) or not bool(high.get("ok", false)):
            failed += 1;failures.append("Demand model must remain operational with culture integration")
        if int(high.get("demand", 0)) <= int(low.get("demand", 0)):
            failed += 1;failures.append("Higher company culture quality must improve customer demand")
        var modifiers: Dictionary = high.get("modifiers", {})
        if not modifiers.has("culture_quality") or not modifiers.has("quality"):
            failed += 1;failures.append("Demand result must expose effective culture quality modifiers")
        culture.set_dimension("quality", 55, 1, "restore demand integration baseline")

    if game != null and is_instance_valid(game):
        game.free()
    if failures.is_empty(): print("DEMAND CULTURE INTEGRATION TESTS PASSED")
    else:
        for failure in failures: push_error(failure)
        print("DEMAND CULTURE INTEGRATION TESTS FAILED: %d" % failures.size())
    quit(1 if failed > 0 else 0)