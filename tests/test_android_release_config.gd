extends SceneTree

const PRESET_PATH := "res://export_presets.cfg"
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var text := FileAccess.get_file_as_string(PRESET_PATH)
    check("Android export preset exists", not text.is_empty())
    check("Android platform preset exists", text.contains("platform=\"Android\""))
    check("64-bit ARM is enabled", text.contains("architectures/arm64-v8a=true"))
    check("32-bit ARM is disabled", text.contains("architectures/armeabi-v7a=false"))
    check("Android APK export path is configured", text.contains("export_path=\"build/RENEW-debug.apk\""))
    check("stable package identifier is configured", text.contains("package/unique_name=\"com.eghosa.renew\""))
    check("launcher app is enabled", text.contains("package/show_as_launcher_app=true"))
    check("internet permission is explicitly disabled", text.contains("permissions/internet=false"))
    check("network-state permission is explicitly disabled", text.contains("permissions/access_network_state=false"))
    check("Wi-Fi-state permission is explicitly disabled", text.contains("permissions/access_wifi_state=false"))

    var autosave := FileAccess.get_file_as_string("res://scripts/autosave.gd")
    check("autosave handles Android pause", autosave.contains("NOTIFICATION_APPLICATION_PAUSED"))
    check("autosave handles Android back/close", autosave.contains("NOTIFICATION_WM_GO_BACK_REQUEST") and autosave.contains("NOTIFICATION_WM_CLOSE_REQUEST"))
    check("autosave uses canonical SaveSystem", autosave.contains("SaveSystem.save_game({})"))

    var analytics_present := _contains_network_analytics()
    check("no undeclared analytics/network implementation exists", not analytics_present)

    print("--- ANDROID RELEASE CONFIG SUMMARY ---")
    print("Checks: %d | Failures: %d" % [13, failures.size()])
    for failure in failures:
        print("FAILED: %s" % failure)
    if failures.size() > 0:
        quit(1)
    print("ANDROID RELEASE CONFIG: PASS")
    quit(0)

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
        print("FAIL: %s" % label)
