extends SceneTree

const District = preload("res://scripts/restora_district_3d_presenter.gd")
var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var district = District.new()
    district.apply_snapshot({"stage": "operational", "business_open": true, "archetype": "factory"}, false)
    check("district stores stage", district.get_visual_stage() == "operational")
    check("district stores activity", district.is_activity_enabled())
    check("positive-x truck faces travel direction", is_equal_approx(district.heading_for_x_velocity(1.0), PI))
    check("negative-x truck keeps native heading", is_equal_approx(district.heading_for_x_velocity(-1.0), 0.0))
    var scene_text := FileAccess.get_file_as_string("res://scenes/RestoraWorld3D.tscn")
    check("world contains district presenter", scene_text.contains("RestoraDistrict3D"))
    district.free()
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
