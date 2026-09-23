extends SceneTree
var failed:=0
const ICONS:=["home","business","empire","world","property","production","people","market","finance","supply","opportunities","intelligence","settings","decisions"]
func _initialize()->void:call_deferred("_run")
func check(label:String,ok:bool)->void:
    if ok:print("PASS: "+label)
    else:failed+=1;push_error("FAIL: "+label)
func _run()->void:
    for icon_name in ICONS:
        var path:="res://Assets/Art/Icons/%s.svg" % icon_name
        check("bespoke icon exists: "+icon_name,ResourceLoader.exists(path))
        if ResourceLoader.exists(path):check("bespoke icon loads: "+icon_name,load(path) is Texture2D)
    var shell:=FileAccess.get_file_as_string("res://scripts/restora_command_ui.gd")
    check("Figma production shell exists",not shell.is_empty())
    check("shell exposes five-destination runtime",shell.contains('["LIVE", "OPERATE", "EMPIRE", "WORLD", "MORE"]'))
    check("shell contains approved Figma surfaces",shell.contains("ExecutiveHero") and shell.contains("ProductionControl") and shell.contains("RegionalMap") and shell.contains("Monetization"))
    check("shell uses semantic theme manager",shell.contains("RestoraThemeManager") and shell.contains('_color("gold")') and shell.contains('_color("plum")'))
    var theme:=FileAccess.get_file_as_string("res://scripts/theme_manager.gd")
    check("premium graphite palette",theme.contains('Color("0b0d10")') and theme.contains('Color("c99a4b")') and theme.contains('Color("7a405f")'))
    check("premium limestone light palette",theme.contains('Color("e8e2d8")') and theme.contains('Color("98672a")') and theme.contains('Color("66374f")'))
    var screens:=FileAccess.get_file_as_string("res://scripts/ui_screen_manager.gd")
    check("focused-screen motion honors reduced motion",screens.contains("renew/ui/reduce_motion"))
    check("focused-screen transition uses cubic easing",screens.contains("Tween.TRANS_CUBIC"))
    var property:=FileAccess.get_file_as_string("res://scripts/property_3d_presenter.gd")
    check("property branded 3D signage",property.contains("BrandLabel") and property.contains("RESTORA INDUSTRIES"))
    var district:=FileAccess.get_file_as_string("res://scripts/restora_district_3d_presenter.gd")
    check("district branded environmental signage",district.contains("DistrictBrand") and district.contains("RESTORA DISTRICT"))
    var tutorial:=FileAccess.get_file_as_string("res://scripts/tutorial_overlay.gd")
    check("onboarding progress remains visible",tutorial.contains("progress_bar") and tutorial.contains("STEP %d/%d"))
    print("PREMIUM ART DIRECTION: %s" % ("PASS" if failed==0 else "FAIL"))
    quit(1 if failed>0 else 0)
