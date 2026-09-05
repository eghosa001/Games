extends "res://scripts/business_system.gd"

# BusinessSystem's public production transaction already snapshots all ledgers,
# but its local delivery-failure compensation must also restore the warehouse
# directionally. Keep the base implementation intact for compatibility while
# routing the live gameplay instance through this corrected override.
func warehouse_restore(resource: String, amount: float) -> void:
    if amount <= 0.0:
        return
    supply_chain.warehouse[resource] = max(0.0, float(supply_chain.warehouse.get(resource, 0.0)) + amount)
