extends Node
class_name RenewGameStateBridge

## Small compatibility helper for systems that need the canonical state node.
## It never owns gameplay state; RenewGameState remains the single source of truth.

func state():
    return get_node_or_null("/root/RenewGameState")

func read(domain: String, key: String, default_value = null):
    var game_state = state()
    if game_state == null:
        return default_value
    return game_state.get_value(domain, key, default_value)

func write(domain: String, key: String, value) -> void:
    var game_state = state()
    if game_state != null:
        game_state.set_value(domain, key, value)

func domain(domain: String) -> Dictionary:
    var game_state = state()
    if game_state == null:
        return {}
    return game_state.get_domain(domain)
