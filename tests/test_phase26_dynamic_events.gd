extends Node

## Phase 26 regression checks. Run with Godot's test runner when available.
func _ready() -> void:
    var events=load("res://scripts/events.gd").new()
    var definitions:Array=events.definitions()
    assert(definitions.size()==7)
    var ids:Array=[]
    for event in definitions:
        ids.append(str(event.get("id","")))
        assert(event.has("effects"))
        assert(int(event.get("duration_days",0))>=1)
    for required in ["energy_shortage","resource_discovery","supply_disruption","demand_boom","recession","natural_disaster","technology_breakthrough"]:
        assert(ids.has(required))
    var energy:Dictionary=definitions[0]
    assert(is_equal_approx(float(energy["effects"]["supply"]["energy"]),0.80))
    assert(is_equal_approx(float(energy["effects"]["market"]["energy"]),1.30))
    var boom:Dictionary=definitions[3]
    assert(is_equal_approx(float(boom["effects"]["demand_multiplier"]),1.35))
    var recession:Dictionary=definitions[4]
    assert(is_equal_approx(float(recession["effects"]["demand_multiplier"]),0.70))
    print("Phase 26 dynamic event checks passed.")
