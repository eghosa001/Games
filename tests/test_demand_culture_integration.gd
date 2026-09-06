extends SceneTree

const DemandModel = preload("res://scripts/demand_model.gd")

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var failures: Array[String] = []
    var culture = root.get_node_or_null("RenewCompanyCultureSystem")
    if culture == null or not culture.has_method("set_dimension"):
        failures.append("Company Culture System must be available for demand integration")
    else:
        var model = DemandModel.new()
        root.add_child(model)
        await process_frame
        culture.set_dimension("quality", 40, 1, "demand integration baseline")
        var low: Dictionary = model.calculate("furniture", 110.0, 120.0, 10, 75, 0, 0, 1.0, 1.0, 0.0, 0.0, 0.0)
        culture.set_dimension("quality", 100, 1, "demand integration improvement")
        var high: Dictionary = model.calculate("furniture", 110.0, 120.0, 10, 75, 0, 0, 1.0, 1.0, 0.0, 0.0, 0.0)
        if not bool(low.get("ok", false)) or not bool(high.get("ok", false)):
            failures.append("Demand model must remain operational with culture integration")
        if int(high.get("demand", 0)) <= int(low.get("demand", 0)):
            failures.append("Higher company culture quality must improve customer demand")
        var modifiers: Dictionary = high.get("modifiers", {})
        if not modifiers.has("culture_quality") or not modifiers.has("quality"):
            failures.append("Demand result must expose effective culture quality modifiers")
        culture.set_dimension("quality", 55, 1, "restore demand integration baseline")

    if failures.is_empty(): print("DEMAND CULTURE INTEGRATION TESTS PASSED")
    else:
        for failure in failures: push_error(failure)
        print("DEMAND CULTURE INTEGRATION TESTS FAILED: %d" % failures.size())
    quit(0 if failures.is_empty() else 1)
