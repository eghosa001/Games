extends SceneTree
var failed:=0
const ICONS:=["home","business","empire","world","property","production","people","market","finance","supply","opportunities","intelligence","settings","decisions"]
const NAV_ICONS:=["home","business","property","finance","more"]
func _initialize()->void:call_deferred("_run")
func check(label:String,ok:bool)->void:
    if ok:print("PASS: "+label)
    else:failed += 1;push_error("FAIL: "+label)
func _run()->void:
    for icon_name in ICONS:
        var path:="res://Assets/Art/Icons/%s.svg" % icon_name
        check("bespoke icon exists: "+icon_name,ResourceLoader.exists(path))
        if ResourceLoader.exists(path):check("bespoke icon loads: "+icon_name,load(path) is Texture2D)
    for icon_name in NAV_ICONS:
        var nav_path:="res://Assets/Art/NavIcons/%s.svg" % icon_name
        check("minimal nav icon exists: "+icon_name,ResourceLoader.exists(nav_path))
        if ResourceLoader.exists(nav_path):check("minimal nav icon loads: "+icon_name,load(nav_path) is Texture2D)
    var shell:=FileAccess.get_file_as_string("res://scripts/restora_command_ui.gd")
    check("Figma production shell exists",not shell.is_empty())
    check("shell exposes five-destination runtime",shell.contains('["HOME", "BUSINESS", "PROPERTY", "FINANCE", "MORE"]'))
    check("shell contains approved management surfaces",shell.contains("ExecutiveHero") and shell.contains("ProductionControl") and shell.contains("RegionalCatalog") and shell.contains("Monetization"))
    check("shell uses semantic theme manager",shell.contains("RestoraThemeManager") and shell.contains('_color("gold")') and shell.contains('_color("plum")'))
    var theme:=FileAccess.get_file_as_string("res://scripts/theme_manager.gd")
    check("premium dark heritage palette",theme.contains('Color("171714")') and theme.contains('Color("d2a85a")') and theme.contains('Color("985b72")'))
    check("premium warm management palette",theme.contains('Color("f1ece1")') and theme.contains('Color("9a6728")') and theme.contains('Color("74465a")'))
    var screens:=FileAccess.get_file_as_string("res://scripts/ui_screen_manager.gd")
    check("focused-screen motion honors reduced motion",screens.contains("renew/ui/reduce_motion"))
    check("focused-screen transition uses cubic easing",screens.contains("Tween.TRANS_CUBIC"))
    var main_scene:=FileAccess.get_file_as_string("res://scenes/Main.tscn")
    check("production runtime no longer mounts World3D",not main_scene.contains("RestoraWorld3D.tscn") and not main_scene.contains("name=\"World3D\""))
    var enhancer:=FileAccess.get_file_as_string("res://scripts/restora_figma_enhancer.gd")
    check("property presentation uses Figma-inspired restoration imagery",enhancer.contains("restora_calder_works.svg") and enhancer.contains("restora_region_map.svg"))
    check("navigation uses dedicated minimal icon set",shell.contains("NavIcons/") and shell.contains("NAV_ICON_ROOT"))
    var tutorial:=FileAccess.get_file_as_string("res://scripts/tutorial_overlay.gd")
    check("onboarding progress remains visible",tutorial.contains("progress_bar") and tutorial.contains("STEP %d/%d"))
    print("PREMIUM ART DIRECTION: %s" % ("PASS" if failed==0 else "FAIL"))
    quit(1 if failed > 0 else 0)
