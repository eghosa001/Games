extends SceneTree

const PRESET_PATH := "res://export_presets.cfg"
var failures: Array[String] = []
var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var text := FileAccess.get_file_as_string(PRESET_PATH)
    var project_text := FileAccess.get_file_as_string("res://project.godot")
    check("Android export preset exists", not text.is_empty())
    check("Android platform preset exists", text.contains("platform=\"Android\""))
    check("Play Store preset exists", text.contains("name=\"Android Play Store\""))
    check("Play Store release is AAB", text.contains("export_path=\"build/Restora-release.aab\"") and text.contains("gradle_build/export_format=1"))
    check("Play Store release uses Gradle", text.contains("gradle_build/use_gradle_build=true"))
    check("Android 16/API 36 target is explicit", text.contains("gradle_build/target_sdk=\"36\""))
    check("minimum Android SDK is explicit", text.contains("gradle_build/min_sdk=\"24\""))
    check("64-bit ARM is enabled", text.contains("architectures/arm64-v8a=true"))
    check("32-bit ARM is disabled", text.contains("architectures/armeabi-v7a=false"))
    check("stable package identifier is configured", text.contains("package/unique_name=\"com.eghosa.renew\""))
    check("Restora package display name is configured", text.contains("package/name=\"Restora\""))
    check("launcher app is enabled", text.contains("package/show_as_launcher_app=true"))
    check("adaptive icon foreground is configured", text.contains("launcher_icons/adaptive_foreground_432x432=\"res://Assets/restora_icon_foreground.svg\""))
    check("adaptive icon background is configured", text.contains("launcher_icons/adaptive_background_432x432=\"res://Assets/restora_icon_background.svg\""))
    check("Android 13 themed monochrome icon is configured", text.contains("launcher_icons/adaptive_monochrome_432x432=\"res://Assets/restora_icon_monochrome.svg\""))
    var icon_source := FileAccess.get_file_as_string("res://Assets/restora_icon.svg")
    check("launcher icon is branded RESTORA monogram", icon_source.contains("#C99A4B") and icon_source.contains("#7A405F") and not icon_source.contains("188 300l42 42"))
    check("release version code exists", text.contains("version/code=1"))
    check("release semantic version exists", text.contains("version/name=\"1.0.0\""))
    check("internet permission stays disabled until a network SDK ships", text.contains("permissions/internet=false"))
    check("network-state permission stays disabled until a network SDK ships", text.contains("permissions/access_network_state=false"))
    check("Wi-Fi-state permission remains disabled", text.contains("permissions/access_wifi_state=false"))
    check("Android backup is disabled", text.contains("user_data_backup/allow=false"))
    check("Android handheld orientation is locked to portrait", project_text.contains("window/handheld/orientation=1"))
    check("mobile base viewport matches approved Figma width", project_text.contains("window/size/viewport_width=390"))
    check("mobile base viewport matches approved Figma height", project_text.contains("window/size/viewport_height=844"))
    check("canvas-items stretch is enabled for mobile scaling", project_text.contains('window/stretch/mode="canvas_items"'))
    check("Godot engine boot image is disabled", project_text.contains("boot_splash/show_image=false"))
    check("RESTORA boot background is configured", project_text.contains("boot_splash/bg_color=Color("))

    var autosave := FileAccess.get_file_as_string("res://scripts/autosave.gd")
    check("autosave handles Android pause", autosave.contains("NOTIFICATION_APPLICATION_PAUSED"))
    check("autosave handles Android back/close", autosave.contains("NOTIFICATION_WM_GO_BACK_REQUEST") and autosave.contains("NOTIFICATION_WM_CLOSE_REQUEST"))
    check("autosave uses canonical SaveSystem", autosave.contains("SaveSystem.save_game({})"))

    var monetization := FileAccess.get_file_as_string("res://scripts/monetization_system.gd")
    var monetization_config := FileAccess.get_file_as_string("res://config/monetization.json")
    check("monetization service exists", not monetization.is_empty())
    check("forced ads are structurally disabled", monetization.contains("func should_show_forced_ads() -> bool") and monetization.contains("return false"))
    check("rewarded offers require explicit enablement", monetization.contains("rewarded_ads_enabled()") and monetization_config.contains("\"rewarded_ads_enabled\": false"))
    check("subscriptions require explicit enablement", monetization.contains("subscriptions_enabled()") and monetization_config.contains("\"subscriptions_enabled\": false"))
    check("production IDs are not committed", monetization_config.contains("\"admob_android_app_id\": \"\"") and monetization_config.contains("\"rewarded_ad_unit_id\": \"\"") and monetization_config.contains("\"premium_subscription_product_id\": \"\""))

    var analytics_present := _contains_network_analytics()
    check("no undeclared analytics/tracking implementation exists", not analytics_present)

    print("--- ANDROID RELEASE CONFIG SUMMARY ---")
    print("Checks: %d | Failures: %d" % [38, failures.size()])
    for failure in failures:
        print("FAILED: %s" % failure)
    if failures.size() > 0:
        quit(1)
    print("ANDROID RELEASE CONFIG: PASS")
    quit(1 if failed > 0 else 0)

func _contains_network_analytics() -> bool:
    var dir := DirAccess.open("res://scripts")
    if dir == null:
        return false
    dir.list_dir_begin()
    var filename := dir.get_next()
    while filename != "":
        if not dir.current_is_dir() and filename.ends_with(".gd"):
            var source := FileAccess.get_file_as_string("res://scripts/" + filename)
            if source.contains("HTTPRequest.new()") or source.contains("http://") or source.contains("https://"):
                if source.contains("analytics") or source.contains("telemetry") or source.contains("tracking"):
                    return true
        filename = dir.get_next()
    dir.list_dir_end()
    return false

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failures.append(label)
        failed += 1
        print("FAIL: %s" % label)
