extends SceneTree

const PropertyVisual = preload("res://scripts/property_visual.gd")
const MainHUD = preload("res://scripts/restora_command_ui.gd")
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
    var hud := PropertyVisual.new()
    check("320px restoration HUD uses compact layout", hud._uses_compact_layout(320.0))
    check("480px viewport height stays on-screen", is_equal_approx(hud._hud_height_for_viewport(480.0), 480.0))
    hud.free()
    var main_hud := MainHUD.new()
    check("Figma command HUD exposes responsive layout", main_hud.has_method("_layout_responsive"))
    check("Figma command HUD exposes production view routing", main_hud.has_method("open_figma_view"))
    main_hud.free()
    var overlay_text := FileAccess.get_file_as_string("res://scripts/property_visual.gd")
    check("restoration HUD uses selected property ownership", overlay_text.contains("property.get(\"owned\""))
    var project_text := FileAccess.get_file_as_string("res://project.godot")
    check("GL compatibility remains enabled", project_text.contains("renderer/rendering_method=\"gl_compatibility\""))
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
