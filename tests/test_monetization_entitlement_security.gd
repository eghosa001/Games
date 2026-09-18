extends SceneTree

const Monetization = preload("res://scripts/monetization_system.gd")
var failed := 0
var _had_state := false
var _original_state := ""

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _had_state = FileAccess.file_exists(Monetization.LOCAL_STATE_PATH)
    if _had_state:
        _original_state = FileAccess.get_file_as_string(Monetization.LOCAL_STATE_PATH)

    var forged := ConfigFile.new()
    forged.set_value("premium", "active", true)
    forged.set_value("premium", "source", "forged_local")
    forged.set_value("premium", "verified_until_unix", Time.get_unix_time_from_system() + 86400.0)
    forged.save(Monetization.LOCAL_STATE_PATH)

    var service = Monetization.new()
    service._load_local_state()
    check(not service.is_premium(), "Cached local Premium cannot activate entitlement")
    check(bool(service.get("_cached_premium_claim")), "Unexpired cache is retained only as a revalidation hint")
    var source := FileAccess.get_file_as_string("res://scripts/monetization_system.gd")
    check(source.contains("if subscriptions_enabled() and provider_ready_for_billing()"), "Provider registration restores entitlement even without local cache")

    service.set_verified_premium_entitlement(true, "verified_test", Time.get_unix_time_from_system() + 86400.0)
    check(service.is_premium(), "Verified provider entitlement activates Premium")
    check(not bool(service.get("_cached_premium_claim")), "Verified decision clears cached revalidation hint")
    service.free()

    _restore_state_file()
    quit(1 if failed > 0 else 0)

func _restore_state_file() -> void:
    if _had_state:
        var file := FileAccess.open(Monetization.LOCAL_STATE_PATH, FileAccess.WRITE)
        if file != null:
            file.store_string(_original_state)
    elif FileAccess.file_exists(Monetization.LOCAL_STATE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(Monetization.LOCAL_STATE_PATH))

func check(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)
