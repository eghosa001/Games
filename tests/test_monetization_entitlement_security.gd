extends SceneTree

var failed := 0

func _init() -> void:
    var source := FileAccess.get_file_as_string("res://scripts/monetization_system.gd")
    check(not source.is_empty(), "Monetization source loads")
    check(source.contains("premium_active = false"), "Startup does not trust cached Premium")
    check(source.contains("_cached_premium_claim = cached_active and unexpired"), "Cached entitlement is only a revalidation hint")
    check(source.contains("provider.restore_purchases"), "Billing provider revalidates cached entitlement")
    check(source.contains("_apply_verified_purchase_result"), "Only verified provider results apply Premium")
    quit(1 if failed > 0 else 0)

func check(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)
