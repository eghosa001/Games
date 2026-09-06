extends SceneTree

const CultureSystem = preload("res://scripts/company_culture_system.gd")

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var failures: Array[String] = []
    var system := CultureSystem.new()
    root.add_child(system)
    await process_frame

    var profile := system.get_profile()
    for dimension in CultureSystem.DIMENSIONS:
        if not profile.has(dimension):
            failures.append("Culture profile missing dimension: %s" % dimension)
        elif int(profile[dimension]) < 0 or int(profile[dimension]) > 100:
            failures.append("Culture dimension out of range: %s" % dimension)

    var before := system.get_dimension("innovation")
    var changed := system.adjust_dimension("innovation", 20, 5, "technology investment")
    if not bool(changed.get("ok", false)) or system.get_dimension("innovation") != min(before + 20, 100):
        failures.append("Culture dimension adjustment should be bounded and persistent")

    var clamped := system.set_dimension("quality", 999, 5, "quality initiative")
    if not bool(clamped.get("ok", false)) or system.get_dimension("quality") != 100:
        failures.append("Culture values must clamp to 100")

    var effects := system.get_effects()
    for key in ["recruitment_multiplier", "retention_multiplier", "productivity_multiplier", "research_multiplier", "quality_multiplier", "expansion_multiplier", "reputation_multiplier"]:
        if not effects.has(key) or float(effects[key]) <= 0.0:
            failures.append("Culture effects missing or invalid: %s" % key)

    var daily_first := system.daily_update(10)
    var after_first := system.capture_state()
    var daily_second := system.daily_update(10)
    var after_second := system.capture_state()
    if bool(daily_second.get("changed", true)):
        failures.append("Company culture daily update must be idempotent for the same day")
    if after_first.get("culture", {}) != after_second.get("culture", {}):
        failures.append("Repeated same-day culture updates must not apply modifiers twice")
    if int(after_first.get("last_day", 0)) != 10:
        failures.append("Culture daily update must record the processed day")

    var snapshot := system.capture_state()
    var restored := CultureSystem.new()
    root.add_child(restored)
    restored.restore_state(snapshot)
    if restored.get_dimension("innovation") != system.get_dimension("innovation"):
        failures.append("Culture must survive capture/restore")
    if restored.get_dimension("quality") != 100:
        failures.append("Restored culture must retain bounded values")
    if int(restored.capture_state().get("last_day", 0)) != 10:
        failures.append("Processed culture day must survive capture/restore")

    var invalid := restored.set_dimension("not_a_dimension", 50)
    if bool(invalid.get("ok", true)):
        failures.append("Unknown culture dimensions must be rejected")

    if failures.is_empty():
        print("COMPANY CULTURE SYSTEM TESTS PASSED")
    else:
        for failure in failures:
            push_error(failure)
        print("COMPANY CULTURE SYSTEM TESTS FAILED: %d" % failures.size())
    quit(0 if failures.is_empty() else 1)
