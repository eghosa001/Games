extends SceneTree

var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var base := FileAccess.get_file_as_string("res://scripts/renew_sims_ui.gd")
    var final := FileAccess.get_file_as_string("res://scripts/renew_sims_ui_final.gd")

    check("shell reserves a world-first play space", base.contains("WorldPlaySpace") and base.contains("world_spacer"))
    check("section header can leave the world unobstructed", base.contains("section_header"))
    check("PLAY tab hides duplicate management grid over 3D world", final.contains("world_first") and final.contains("action_scroll.visible = not world_first"))
    check("PLAY tab keeps center space for simulation", final.contains("world_spacer.visible = world_first"))
    check("home action duplication is suppressed", final.contains("active_tab:") and final.contains("child.visible = false"))
    check("business surface is intentionally capped", final.contains("_limit_visible_actions") and final.contains("\"Operations\""))
    check("empire surface prioritizes portfolio and expansion", final.contains("\"Portfolio & projects\"") and final.contains("\"Expansion\""))
    check("world surface prioritizes regions and supply", final.contains("\"Regions\"") and final.contains("\"Supply network\""))
    check("late strategy layers unlock progressively", final.contains("EMPIRE\\nLV 3") and final.contains("WORLD\\nLV 3"))
    check("operational progress bar switches to company XP", final.contains("_update_progress_strip") and final.contains("get_progress"))
    check("settings is utility not a theme-mode gameplay action", final.contains('theme_button.text = "SETTINGS"'))
    check("core-loop primary action remains state driven", final.contains('"INSPECT"') and final.contains('"ACQUIRE"') and final.contains('"RESTORE"') and final.contains('"PRODUCE"') and final.contains('"SELL GOODS"'))

    var property := FileAccess.get_file_as_string("res://scripts/property_3d_presenter.gd")
    var world := FileAccess.get_file_as_string("res://scripts/restora_world_3d_controller.gd")
    var operations := FileAccess.get_file_as_string("res://scripts/business_operations_ui.gd")
    check("primary 3D property exposes direct interaction", property.contains("property_interacted") and property.contains("PropertyInteractionArea"))
    check("property taps route through inspect acquire restore operate", world.contains("_on_property_interacted") and world.contains("inspect_property") and world.contains("acquire_property") and world.contains("restore_property") and world.contains("BusinessOperationsPanel"))
    check("frequent operating actions use a contextual sheet", operations.contains("contextual sheet") and operations.contains("viewport.y - h - 8.0"))
    check("empty HUD space passes input through to 3D", base.contains("shell.mouse_filter = Control.MOUSE_FILTER_IGNORE") and base.contains("page.mouse_filter = Control.MOUSE_FILTER_IGNORE"))

    print("WORLD-FIRST GAMEPLAY SHELL: %s" % ("PASS" if failed == 0 else "FAIL"))
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
