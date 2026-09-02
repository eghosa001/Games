extends RefCounted
class_name RenewProduction

var recipe := {"materials": 1, "packaging": 1, "fuel": 1}
var output_per_cycle := 2
var quality := 60

# Production now consumes the role-aware metric published by EmployeeController.
# Technician/Worker/Supervisor/Manager staffing is therefore more valuable to a
# factory than assigning a sales or accounting specialist to the production line.
func produce(economy: RenewEconomy, cycles: int) -> Dictionary:
    var requested_cycles := max(0, cycles)
    var staffing_efficiency := _staffing_efficiency()
    var staffed_cycles := int(floor(float(requested_cycles) * staffing_efficiency))
    if requested_cycles > 0 and staffed_cycles <= 0:
        return {"ok": false, "cycles": 0, "output": 0, "quality": quality, "staffing_efficiency": staffing_efficiency, "reason": "insufficient_staffing"}

    var possible := staffed_cycles
    for resource in recipe:
        if not economy.resources.has(resource):
            return {"ok": false, "cycles": 0, "output": 0, "quality": quality, "staffing_efficiency": staffing_efficiency, "reason": "missing_resource"}
        possible = min(possible, int(economy.resources[resource]["stock"] / recipe[resource]))
    if possible <= 0:
        return {"ok": false, "cycles": 0, "output": 0, "quality": quality, "staffing_efficiency": staffing_efficiency}
    for resource in recipe:
        economy.resources[resource]["stock"] -= recipe[resource] * possible
    var output := possible * output_per_cycle
    quality = clamp(quality + randi_range(-3, 4), 30, 100)
    return {"ok": true, "cycles": possible, "output": output, "quality": quality, "staffing_efficiency": staffing_efficiency}

func _staffing_efficiency() -> float:
    var tree := Engine.get_main_loop()
    if tree == null:
        return 1.0
    var root := tree.get_root()
    if root == null:
        return 1.0
    var game_state = root.get_node_or_null("RenewGameState")
    if game_state == null:
        return 1.0
    var role_metric = game_state.get_value(["analytics", "employee_production_efficiency"], null)
    if role_metric != null:
        return clampf(float(role_metric), 0.25, 2.5)
    var legacy_metric = game_state.get_value(["analytics", "employee_average_productivity"], 1.0)
    return clampf(float(legacy_metric), 0.25, 2.5)
