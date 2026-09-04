# ===============================================
# File: scripts/game_state_bridge.gd
# ===============================================
extends Node

## Compatibility helper for systems that need quick state access.
## It never owns state; it only reads from the canonical GameState.

func _state():
    return get_node_or_null("/root/RenewGameState")

func read(domain: String, key: String, default_value = null):
    var state = _state()
    return state.get_value(domain, key, default_value) if state else default_value

func write(domain: String, key: String, value) -> void:
    var state = _state()
    if state:
        state.set_value(domain, key, value)

func domain(domain: String) -> Dictionary:
    var state = _state()
    return state.get_domain(domain) if state else {}
