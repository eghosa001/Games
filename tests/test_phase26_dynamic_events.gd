extends SceneTree

## Phase 26 regression checks for dynamic event definitions.
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
    var Events = load("res://scripts/events.gd")
    check(Events != null, "Events script loads")
    if Events == null:
        quit(1)
        return
    var events = Events.new()
    var definitions: Array = events.definitions()
    check(definitions.size() == 7, "Seven dynamic events defined")
    var ids: Array = []
    var defs_ok := true
    for event in definitions:
        ids.append(str(event.get("id", "")))
        if not event.has("effects"):
            defs_ok = false
        if int(event.get("duration_days", 0)) < 1:
            defs_ok = false
    check(defs_ok, "Every event has effects and lasts at least one day")
    for required in ["energy_shortage", "resource_discovery", "supply_disruption", "demand_boom", "recession", "natural_disaster", "technology_breakthrough"]:
        check(ids.has(required), "Event present: %s" % required)
    var energy: Dictionary = definitions[0]
    check(is_equal_approx(float(energy["effects"]["supply"]["energy"]), 0.80), "Energy shortage cuts supply")
    check(is_equal_approx(float(energy["effects"]["market"]["energy"]), 1.30), "Energy shortage raises market price")
    var boom: Dictionary = definitions[3]
    check(is_equal_approx(float(boom["effects"]["demand_multiplier"]), 1.35), "Demand boom multiplier")
    var recession: Dictionary = definitions[4]
    check(is_equal_approx(float(recession["effects"]["demand_multiplier"]), 0.70), "Recession multiplier")
    print("PHASE 26 RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
