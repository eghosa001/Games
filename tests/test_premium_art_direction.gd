extends SceneTree

var failed := 0

const ICONS := [
    "home", "business", "empire", "world", "property", "production",
    "people", "market", "finance", "supply", "opportunities",
    "intelligence", "settings", "decisions"
]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for icon_name in ICONS:
        var path := "res://Assets/Art/Icons/%s.svg" % icon_name
        check("bespoke icon exists: " + icon_name, ResourceLoader.exists(path))
        if ResourceLoader.exists(path):
            check("bespoke icon loads: " + icon_name, load(path) is Texture2D)

    var shell := FileAccess.get_file_as_string("res://scripts/renew_sims_ui.gd")
    check("primary shell wires bespoke action icons", shell.contains("ACTION_ICON_MAP") and shell.contains("_apply_button_icon"))
    check("primary shell has tactile button motion", shell.contains("_wire_button_motion") and shell.contains("renew/ui/reduce_motion"))

    var property := FileAccess.get_file_as_string("res://scripts/property_3d_presenter.gd")
    check("property has branded 3D signage", property.contains("BrandLabel") and property.contains("RESTORA INDUSTRIES"))
    check("property has authored rooftop and bay detail", property.contains("RoofVent") and property.contains("BayStripe"))
    check("property workers have visual role variation", property.contains("SafetyVest") and property.contains("_worker_blue"))

    var district := FileAccess.get_file_as_string("res://scripts/restora_district_3d_presenter.gd")
    check("district has branded environmental signage", district.contains("DistrictBrand") and district.contains("RESTORA DISTRICT"))
    check("district adds transit-scale environment detail", district.contains("BusShelterRoof"))
    check("district vehicles use visual variants", district.contains("_car_blue") and district.contains("_car_coral"))

    var liveops := FileAccess.get_file_as_string("res://scripts/liveops_ui.gd")
    check("live operations uses bespoke event iconography", liveops.contains("_make_icon(\"opportunities\"") and liveops.contains("_make_icon(\"intelligence\""))
    check("live operations has premium progress styling", liveops.contains("_progress_style"))
    check("live operations has distinct seasonal hero identity", liveops.contains("_add_season_hero") and liveops.contains("_season_theme"))

    var screens := FileAccess.get_file_as_string("res://scripts/ui_screen_manager.gd")
    check("focused-screen motion honors reduced motion", screens.contains("renew/ui/reduce_motion"))
    check("focused-screen transition uses cubic easing", screens.contains("Tween.TRANS_CUBIC"))

    var settings := FileAccess.get_file_as_string("res://scripts/save_load_ui.gd")
    check("settings exposes reduce motion control", settings.contains("REDUCE MOTION") and settings.contains("UI_PREFS_PATH"))
    check("settings matches premium navy art direction", settings.contains("0b1630") and settings.contains("5367af"))

    var tutorial := FileAccess.get_file_as_string("res://scripts/tutorial_overlay.gd")
    check("first-session onboarding has visible progress", tutorial.contains("progress_bar") and tutorial.contains("STEP %d/%d"))

    var visual_state := FileAccess.get_file_as_string("res://scripts/restora_3d_visual_state.gd")
    check("3D state carries prosperity rivalry and live events", visual_state.contains("prosperity_tier") and visual_state.contains("rival_market_share") and visual_state.contains("active_event_category"))

    print("PREMIUM ART DIRECTION: %s" % ("PASS" if failed == 0 else "FAIL"))
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
