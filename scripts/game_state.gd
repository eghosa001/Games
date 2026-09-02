extends Node
class_name RenewGameState

# Single persistence boundary for the simulation. Gameplay modules may keep their
# own runtime objects, but save/load always passes through this state snapshot.
const STATE_VERSION := 2

var data: Dictionary = {}

func capture(core: Dictionary) -> Dictionary:
    data = core.duplicate(true)
    data["state_version"] = STATE_VERSION
    return data.duplicate(true)

func restore(snapshot: Dictionary) -> Dictionary:
    data = snapshot.duplicate(true)
    data["state_version"] = STATE_VERSION
    return data.duplicate(true)

func has_state() -> bool:
    return not data.is_empty()

func clear() -> void:
    data.clear()
