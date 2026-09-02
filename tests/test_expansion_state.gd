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
    var expansion = load("res://scripts/expansion.gd").new()
    state.new_game()

    var canonical: Dictionary = state.get_value(["expansion"], {})
    check(canonical.has("properties") and canonical["properties"] is Array, "canonical expansion properties exist")
    check(canonical.has("resource_sites") and canonical["resource_sites"] is Array, "canonical resource sites exist")

    var cash_before := int(canonical.get("cash", 0))
    check(adapter.record_purchase(state, 0, 12000, 5), "canonical expansion purchase")
    canonical = state.get_value(["expansion"], {})
    check(bool(canonical["properties"][0]["owned"]), "purchased property ownership persists")
    check(int(canonical["properties"][0]["condition"]) == 100, "purchased property is restored")
    check(int(canonical["cash"]) == cash_before - 12000, "purchase cash mutation is atomic")

    check(adapter.record_property_upgrade(state, 0, 7000, 500, 5000), "canonical property upgrade")
    canonical = state.get_value(["expansion"], {})
    check(int(canonical["properties"][0]["level"]) == 2, "property upgrade level persists")
    check(int(canonical["properties"][0]["income"]) == 1700, "property upgrade income persists")

    var resource_cash_before := int(canonical["cash"])
    var resource_rep_before := int(canonical.get("reputation", 0))
    check(adapter.record_resource_purchase(state, 0, 15000, 2), "canonical resource purchase")
    canonical = state.get_value(["expansion"], {})
    check(bool(canonical["resource_sites"][0]["owned"]), "resource ownership persists")
    check(int(canonical["cash"]) == resource_cash_before - 15000, "resource purchase cash mutation persists")
    check(int(canonical["reputation"]) == resource_rep_before + 2, "resource purchase reputation mutation persists")

    # The public Expansion API is now canonical-aware when explicitly bound.
    expansion.bind_game_state(state)
    check(bool(expansion.get_resource_site(0).get("owned", false)), "bound Expansion reflects canonical resource ownership")
    var bound_generation: Dictionary = expansion.generate_resource(0)
    check(bool(bound_generation.get("ok", false)), "bound Expansion generation uses canonical state")
    check(int(bound_generation.get("output", 0)) == 8, "bound generation output is canonical")
    canonical = state.get_value(["expansion"], {})
    check(int(canonical["resource_sites"][0]["stock"]) == 8, "bound generation updates canonical stock")

    var bound_upgrade: Dictionary = expansion.upgrade_resource_site(0, 999999)
    check(bool(bound_upgrade.get("ok", false)), "bound Expansion upgrade uses canonical state")
    canonical = state.get_value(["expansion"], {})
    check(int(canonical["resource_sites"][0]["level"]) == 2, "bound upgrade level is canonical")
    check(int(canonical["resource_sites"][0]["output"]) == 10, "bound upgrade output is canonical")
    check(int(canonical["resource_sites"][0]["risk"]) == 11, "bound upgrade risk is canonical")
    check(int(canonical["cash"]) == resource_cash_before - 15000 - 9000, "bound upgrade deducts canonical cash once")

    # Main's transitional wrapper historically supplied the calculated output.
    # The canonical adapter now owns that calculation but accepts the argument for compatibility.
    var generated: Dictionary = adapter.record_resource_generation(state, 0, 8)
    check(bool(generated.get("ok", false)), "canonical resource generation with legacy argument")
    check(int(generated.get("output", 0)) == 10, "resource generation ignores stale legacy output argument")
    check(int(generated.get("stock", 0)) == 18, "resource stock remains canonical after second generation")

    var snapshot: Dictionary = state.capture({})
    state.clear()
    check(not state.has_state(), "canonical state can be cleared")
    state.restore(snapshot)
    canonical = state.get_value(["expansion"], {})
    check(bool(canonical["properties"][0]["owned"]), "purchase survives state restore")
    check(int(canonical["properties"][0]["level"]) == 2, "property upgrade survives state restore")
    check(bool(canonical["resource_sites"][0]["owned"]), "resource purchase survives state restore")
    check(int(canonical["resource_sites"][0]["stock"]) == 18, "resource stock survives state restore")
    check(int(canonical["resource_sites"][0]["level"]) == 2, "resource upgrade survives state restore")

    print("EXPANSION STATE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)