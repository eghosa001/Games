extends "res://scripts/business_system.gd"

# BusinessSystem's public production transaction already snapshots all ledgers,
# but its local delivery-failure compensation must also restore the warehouse
# directionally. Keep the base implementation intact for compatibility while
# routing the live gameplay instance through this corrected override.
func warehouse_restore(resource: String, amount: float) -> void:
    if amount <= 0.0:
        return
    supply_chain.warehouse[resource] = max(0.0, float(supply_chain.warehouse.get(resource, 0.0)) + amount)

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
