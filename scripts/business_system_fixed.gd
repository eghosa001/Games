extends "res://scripts/business_system.gd"

## Compatibility layer for legacy technology save formats.
## Production transaction fixes now live in the base BusinessSystem so there is
## only one authoritative implementation of warehouse rollback behavior.

# Legacy saves stored technology entries as dictionaries such as
# {"researched": true}; newer saves store booleans. The base implementation
# casts entries directly to int, which can misread legacy state. Normalize both
# representations in the live gameplay subclass.
func _technology_multiplier() -> float:
    var technology = state_adapter.get_value("technology", "technology", {})
    if not technology is Dictionary:
        return 1.0
    var level := 0
    for key in (technology as Dictionary).keys():
        var entry: Variant = (technology as Dictionary)[key]
        var researched := false
        if entry is bool:
            researched = bool(entry)
        elif entry is Dictionary:
            researched = bool((entry as Dictionary).get("researched", false))
        if researched:
            level += 1
    return clamp(1.0 + float(level) * 0.025, 1.0, 1.35)
