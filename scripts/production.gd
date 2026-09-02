extends RefCounted
class_name RenewProduction

# Compatibility facade for the old Main API. All production rules now live in
# RenewProductionSystem so there is one production authority.
const ProductionSystem = preload("res://scripts/production_system.gd")
var system = ProductionSystem.new()

var recipe: Dictionary:
    get: return {"materials":1,"packaging":1,"fuel":1}
var output_per_cycle: int:
    get: return 2
var quality: int:
    get: return int(system.quality)
var finished_goods: int:
    get: return int(system.finished_goods)

func produce(economy: RenewEconomy, cycles: int) -> Dictionary:
    return system.produce(economy, cycles)

func run_recipe(recipe_id: String, cycles: int = 1) -> Dictionary:
    return system.run_recipe(recipe_id, cycles)

func recipe_ids(stage: String = "") -> Array:
    return system.recipe_ids(stage)

func get_recipe(recipe_id: String) -> Dictionary:
    return system.get_recipe(recipe_id)

func add_inventory(item: String, amount: int) -> void:
    system.add_inventory(item, amount)

func stock(item: String) -> int:
    return system.stock(item)

func acquire_machine(machine_id: String, capacity: int = 1) -> bool:
    return system.acquire_machine(machine_id, capacity)

func unlock_technology(technology: String, level: int = 1) -> void:
    system.unlock_technology(technology, level)

func set_automation(machine_id: String, level: int) -> bool:
    return system.set_automation(machine_id, level)

func maintain_machine(machine_id: String, finance = null) -> Dictionary:
    return system.maintain_machine(machine_id, finance)

func advance_day() -> void:
    system.advance_day()

func consume_goods(amount: int) -> bool:
    return system.consume_goods(amount)

func capture_state() -> Dictionary:
    return system.capture_state()

func restore_state(snapshot: Dictionary) -> void:
    system.restore_state(snapshot)
