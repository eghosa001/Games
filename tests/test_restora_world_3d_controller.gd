extends SceneTree

const Controller = preload("res://scripts/restora_world_3d_controller.gd")
var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var controller = Controller.new()
    var snapshot := controller.read_visual_snapshot(null)
    check("missing state returns warehouse fallback", snapshot.get("archetype") == "warehouse")
    check("missing state returns neglected fallback", snapshot.get("stage") == "neglected")
    check("controller polling interval is mobile friendly", controller.poll_interval >= 0.10)
    controller.free()
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
