extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var state = load("res://scripts/game_state.gd").new()
    var adapter = load("res://scripts/expansion_state.gd")
    state.new_game()

    var expansion: Dictionary = state.get_value(["expansion"], {})
    check(expansion.has("properties") and expansion["properties"] is Array, "canonical expansion properties exist")
    check(expansion.has("resource_sites") and expansion["resource_sites"] is Array, "canonical resource sites exist")

    var cash_before := int(expansion.get("cash", 0))
    check(adapter.record_purchase(state, 0, 12000, 5), "canonical expansion purchase")
    expansion = state.get_value(["expansion"], {})
    check(bool(expansion["properties"][0]["owned"]), "purchased property ownership persists")
    check(int(expansion["properties"][0]["condition"]) == 100, "purchased property is restored")
    check(int(expansion["cash"]) == cash_before - 12000, "purchase cash mutation is atomic")

    check(adapter.record_property_upgrade(state, 0, 7000, 500, 5000), "canonical property upgrade")
    expansion = state.get_value(["expansion"], {})
    check(int(expansion["properties"][0]["level"]) == 2, "property upgrade level persists")
    check(int(expansion["properties"][0]["income"]) == 1700, "property upgrade income persists")

    var resource_cash_before := int(expansion["cash"])
    var resource_rep_before := int(expansion.get("reputation", 0))
    check(adapter.record_resource_purchase(state, 0, 15000, 2), "canonical resource purchase")
    expansion = state.get_value(["expansion"], {})
    check(bool(expansion["resource_sites"][0]["owned"]), "resource ownership persists")
    check(int(expansion["cash"]) == resource_cash_before - 15000, "resource purchase cash mutation persists")
    check(int(expansion["reputation"]) == resource_rep_before + 2, "resource purchase reputation mutation persists")

    # Main's transitional wrapper historically supplied the calculated output.
    # The canonical adapter now owns that calculation but accepts the argument for compatibility.
    var generated: Dictionary = adapter.record_resource_generation(state, 0, 8)
    check(bool(generated.get("ok", false)), "canonical resource generation with legacy argument")
    check(int(generated.get("output", 0)) == 8, "resource generation output is correct")
    check(int(generated.get("stock", 0)) == 8, "resource stock persists")

    check(adapter.record_resource_upgrade(state, 0, 9000, 2, -1), "canonical resource upgrade")
    expansion = state.get_value(["expansion"], {})
    check(int(expansion["resource_sites"][0]["level"]) == 2, "resource upgrade level persists")
    check(int(expansion["resource_sites"][0]["output"]) == 10, "resource upgrade output persists")
    check(int(expansion["resource_sites"][0]["risk"]) == 11, "resource upgrade risk persists")

    var snapshot: Dictionary = state.capture({})
    state.clear()
    check(not state.has_state(), "canonical state can be cleared")
    state.restore(snapshot)
    expansion = state.get_value(["expansion"], {})
    check(bool(expansion["properties"][0]["owned"]), "purchase survives state restore")
    check(int(expansion["properties"][0]["level"]) == 2, "property upgrade survives state restore")
    check(bool(expansion["resource_sites"][0]["owned"]), "resource purchase survives state restore")
    check(int(expansion["resource_sites"][0]["stock"]) == 8, "resource stock survives state restore")
    check(int(expansion["resource_sites"][0]["level"]) == 2, "resource upgrade survives state restore")

    print("EXPANSION STATE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
