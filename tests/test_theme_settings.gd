extends SceneTree

var failed := 0
var checks := 0

func _init() -> void:
    call_deferred("_run")

func check(label: String, condition: bool) -> void:
    checks += 1
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        print("FAIL: %s" % label)

func _run() -> void:
    var theme_script := load("res://scripts/theme_manager.gd")
    check("theme manager script loads", theme_script != null)
    var manager = theme_script.new()
    manager.set_mode("dark")
    check("dark graphite background is available", manager.color("bg").to_html(false) == "0b0d10")
    check("dark brass accent is available", manager.color("gold").to_html(false) == "c99a4b")
    manager.set_mode("light")
    check("light limestone background is available", manager.color("bg").to_html(false) == "e8e2d8")
    check("light bronze accent is available", manager.color("gold").to_html(false) == "98672a")
    check("theme resource builds", manager.get_theme_resource() != null)
    manager.free()

    var project := FileAccess.get_file_as_string("res://project.godot")
    var scene := FileAccess.get_file_as_string("res://scenes/Main.tscn")
    var screens := FileAccess.get_file_as_string("res://scripts/ui_screen_manager.gd")
    var hud := FileAccess.get_file_as_string("res://scripts/renew_sims_ui.gd")
    var skin := FileAccess.get_file_as_string("res://scripts/premium_ui_skin.gd")
    var settings := FileAccess.get_file_as_string("res://scripts/settings_ui.gd")
    var audio := FileAccess.get_file_as_string("res://scripts/audio_manager.gd")

    check("theme manager is an autoload", project.contains('RestoraThemeManager="*res://scripts/theme_manager.gd"'))
    check("settings panel exists in main scene", scene.contains('[node name="SettingsPanel"'))
    check("settings panel is registered with screen manager", screens.contains('"SettingsPanel"'))
    check("home routes to settings panel", hud.contains('_screen("Settings", "SettingsPanel"'))
    check("premium skin consumes global theme manager", skin.contains('/root/RestoraThemeManager') and skin.contains('get_theme_resource'))
    check("premium skin no longer owns old fixed navy palette", not skin.contains('const SURFACE := Color("101d3d")'))
    check("settings exposes dark light and device modes", settings.contains('["dark", "light", "system"]'))
    check("settings exposes premium purchase", settings.contains("purchase_premium"))
    check("settings exposes purchase restore", settings.contains("restore_premium"))
    check("settings exposes privacy policy", settings.contains("privacy_policy_url"))
    check("audio exposes persistent music level", audio.contains("func set_music_level"))
    check("audio exposes persistent SFX level", audio.contains("func set_sfx_level"))

    print("--- THEME & SETTINGS SUMMARY ---")
    print("Checks: %d | Failures: %d" % [checks, failed])
    quit(1 if failed > 0 else 0)
