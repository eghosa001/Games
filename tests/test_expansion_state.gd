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

    var generated: Dictionary = adapter.record_resource_generation(state, 0, 8)
    check(bool(generated.get("ok", false)), "canonical resource generation with legacy argument")
    check(int(generated.get("output", 0)) == 10, "resource generation ignores stale legacy output argument")
    check(int(generated.get("stock", 0)) == 18, "resource stock remains canonical after second generation")

    var operating := adapter.calculate_operating_day(state)
    check(int(operating.get("revenue", 0)) == 5400, "canonical operating revenue calculation")
    check(int(operating.get("expense", 0)) == 850, "canonical operating expense calculation")
    check(int(operating.get("profit", 0)) == 4550, "canonical operating profit calculation")
    check(int(operating.get("businesses", 0)) == 1, "canonical operating business count")
    check(int(operating.get("cash", 0)) == int(canonical["cash"]) + 4550, "canonical operating cash projection")
    check(int(operating.get("day", 0)) == int(canonical.get("day", 1)) + 1, "canonical operating next day")
    check(int(operating.get("population_delta", 0)) == 2, "canonical operating population delta")
    check(int(canonical["day"]) == 1, "operating calculation is non-mutating")
    check(int(canonical["cash"]) == 7000, "operating calculation does not mutate cash")

    var advanced := adapter.advance_day(state, int(operating["profit"]), int(operating["population_delta"]))
    check(int(advanced["day"]) == 2, "canonical operating day commit")
    check(int(advanced["cash"]) == 11550, "canonical operating profit committed once")
    check(int(advanced["population"]) == 102, "canonical operating population committed")

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
    check(int(canonical["day"]) == 2 and int(canonical["cash"]) == 11550, "operating-day state survives restore")

    print("EXPANSION STATE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)