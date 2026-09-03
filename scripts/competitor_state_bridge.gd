extends Node

## Phase 14 integration bridge.
## Keeps the live competitor AI owned by GameplayCommandSystem while mirroring
## its persistent state into RenewGameState for saves, loads and UI consumers.
var _competitors = null
var _last_state_signature: Variant = ""
var _ready_to_sync: Variant = false

func _process(_delta: float) -> void:
    var scene: Variant = get_tree().current_scene
    if scene == null:
        return
    if _competitors == null:
        var commands = scene.get("command_system")
        if commands != null and commands.get("relationship_system") != null:
            _competitors = commands.relationship_system.rivals
            _ready_to_sync = true
    if not _ready_to_sync:
        return
    var state: Variant = get_node_or_null("/root/RenewGameState")
    if state == null:
        return
    var saved = state.get_value("competitors", "rivals", [])
    var live: Array = _competitors.rivals
    if saved is Array and not saved.is_empty() and _signature(saved) != _signature(live) and _last_state_signature != _signature(live):
        _competitors.restore_state({"rivals": saved})
        live = _competitors.rivals
    state.set_value("competitors", "rivals", live.duplicate(true))
    var selected: Variant = clamp(int(state.get_value("competitors", "selected_rival", 0)), 0, max(0, live.size() - 1))
    state.set_value("competitors", "selected_rival", selected)
    if not live.is_empty():
        state.set_value("competitors", "relationship", int(live[selected].get("relationship", 0)))
    _last_state_signature = _signature(live)

func _signature(value) -> String:
    return JSON.stringify(value)
