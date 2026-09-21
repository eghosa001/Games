extends SceneTree

const Presenter = preload("res://scripts/property_3d_presenter.gd")
var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var presenter = Presenter.new()
    var source := FileAccess.get_file_as_string("res://scripts/property_3d_presenter.gd")
    check("property transition cancels stale tween", source.contains("_building_tween.kill()"))
    presenter.apply_snapshot({"stage":"painted", "archetype":"factory", "business_open":false}, false)
    check("presenter stores visual stage", presenter.get_visual_stage() == "painted")
    check("factory uses industrial profile", presenter.get_archetype_profile() == "industrial_stack")
    check("factory keeps shared loading bays", presenter.uses_loading_bays() and presenter.uses_base_front_windows())
    presenter.apply_snapshot({"stage":"painted", "archetype":"office", "business_open":false}, false)
    check("office removes warehouse loading front", not presenter.uses_loading_bays() and not presenter.uses_base_front_windows())
    presenter.apply_snapshot({"stage":"painted", "archetype":"retail", "business_open":false}, false)
    check("retail removes warehouse loading front", not presenter.uses_loading_bays() and not presenter.uses_base_front_windows())
    presenter.apply_snapshot({"stage":"operational", "archetype":"factory", "business_open":true}, false)
    check("operational property enables machinery", presenter.is_operational_motion_enabled())
    var source_operational := FileAccess.get_file_as_string("res://scripts/property_3d_presenter.gd")
    check("finished goods drive visible inventory crates", source_operational.contains("_inventory_crates") and source_operational.contains("_finished_goods"))
    check("capacity upgrades have physical property modules", source_operational.contains("_capacity_modules") and source_operational.contains("_capacity_level"))
    check("property workers use articulated walking limbs", source_operational.contains("LegL") and source_operational.contains("ArmL") and source_operational.contains("swing"))
    presenter.apply_snapshot({}, false)
    check("warehouse fallback is safe", presenter.get_visual_stage() == "neglected" and presenter.get_archetype_profile() == "warehouse_bays")
    presenter.free()
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
