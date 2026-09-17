extends SceneTree

var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var main_text := FileAccess.get_file_as_string("res://scenes/Main.tscn")
    check("main scene references 3D world", main_text.contains("res://scenes/RestoraWorld3D.tscn"))
    check("existing 2D world remains", main_text.contains("[node name=\"World\" type=\"Node2D\" parent=\".\"]"))
    check("existing management UI remains", main_text.contains("[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]"))
    check("portfolio selector remains", main_text.contains("[node name=\"PortfolioPanel\" type=\"CanvasLayer\" parent=\"UI\"]"))
    var controller_text := FileAccess.get_file_as_string("res://scripts/restora_world_3d_controller.gd")
    check("3D mode suppresses legacy property map", controller_text.contains("../World/PropertyMap"))
    var project_text := FileAccess.get_file_as_string("res://project.godot")
    check("GL compatibility remains enabled", project_text.contains("renderer/rendering_method=\"gl_compatibility\""))
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
