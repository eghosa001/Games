extends SceneTree

const Presenter = preload("res://scripts/property_3d_presenter.gd")
var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var presenter = Presenter.new()
    presenter.apply_snapshot({"stage":"painted", "archetype":"factory", "business_open":false}, false)
    check("presenter stores visual stage", presenter.get_visual_stage() == "painted")
    check("presenter stores archetype", presenter.get_archetype() == "factory")
    presenter.apply_snapshot({}, false)
    check("presenter fallback is safe", presenter.get_visual_stage() == "neglected" and presenter.get_archetype() == "warehouse")
    presenter.free()
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
