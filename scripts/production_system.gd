extends Node
class_name RenewProductionSystem

const SYSTEM_VERSION := 2
const MAX_HISTORY := 500

const RECIPES := {
    "extract_ore": {"stage":"extraction","inputs":{},"outputs":{"iron_ore":4},"machine":"extractor","technology":"extraction","base_quality":58,"waste":0.03},
    "extract_timber": {"stage":"extraction","inputs":{},"outputs":{"timber":5},"machine":"harvester","technology":"extraction","base_quality":62,"waste":0.04},
    "process_steel": {"stage":"processing","inputs":{"iron_ore":2,"fuel":1},"outputs":{"steel":1},"machine":"processor","technology":"steel_processing","base_quality":68,"waste":0.06},
    "process_lumber": {"stage":"processing","inputs":{"timber":2,"fuel":1},"outputs":{"lumber":2},"machine":"processor","technology":"lumber_processing","base_quality":70,"waste":0.05},
    "manufacture_furniture": {"stage":"manufacturing","inputs":{"lumber":2,"steel":1,"packaging":1},"outputs":{"furniture":1},"machine":"factory","technology":"furniture_manufacturing","base_quality":76,"waste":0.08},
    "manufacture_appliance": {"stage":"manufacturing","inputs":{"steel":2,"packaging":1,"fuel":1},"outputs":{"appliance":1},"machine":"factory","technology":"appliance_manufacturing","base_quality":80,"waste":0.10},
    "distribute_furniture": {"stage":"distribution","inputs":{"furniture":1,"fuel":1},"outputs":{"distributed_furniture":1},"machine":"fleet","technology":"logistics","base_quality":74,"waste":0.03},
    "distribute_appliance": {"stage":"distribution","inputs":{"appliance":1,"fuel":1},"outputs":{"distributed_appliance":1},"machine":"fleet","technology":"logistics","base_quality":78,"waste":0.04},
    "retail_furniture": {"stage":"retail","inputs":{"distributed_furniture":1},"outputs":{"customer_furniture":1},"machine":"store","technology":"retail","base_quality":78,"waste":0.01},
    "retail_appliance": {"stage":"retail","inputs":{"distributed_appliance":1},"outputs":{"customer_appliance":1},"machine":"store","technology":"retail","base_quality":82,"waste":0.01}
}

const DEFAULT_MACHINES := {
    "extractor":{"owned":true,"condition":100.0,"capacity":2,"maintenance_due":0,"automation":0},
    "harvester":{"owned":true,"condition":100.0,"capacity":2,"maintenance_due":0,"automation":0},
    "processor":{"owned":false,"condition":100.0,"capacity":2,"maintenance_due":0,"automation":0},
    "factory":{"owned":false,"condition":100.0,"capacity":2,"maintenance_due":0,"automation":0},
    "fleet":{"owned":false,"condition":100.0,"capacity":3,"maintenance_due":0,"automation":0},
    "store":{"owned":false,"condition":100.0,"capacity":4,"maintenance_due":0,"automation":0}
}

var inventory: Dictionary = {}
var finished_goods: int = 0
var quality: int = 60
var machines: Dictionary = DEFAULT_MACHINES.duplicate(true)
var technologies: Dictionary = {"extraction":1,"steel_processing":0,"lumber_processing":0,"furniture_manufacturing":0,"appliance_manufacturing":0,"logistics":0,"retail":0}
var utilization: Dictionary = {}
var waste: Dictionary = {}
var automation: Dictionary = {}
var history: Array[Dictionary] = []
var last_run: Dictionary = {}

func _ready() -> void:
    _ensure_inventory()
    _ensure_machine_state()

func _ensure_inventory() -> void:
    for recipe_id in RECIPES:
        var recipe: Dictionary = RECIPES[recipe_id]
        for item in recipe["inputs"]: inventory[item] = int(inventory.get(item, 0))
        for item in recipe["outputs"]: inventory[item] = int(inventory.get(item, 0))
    inventory["goods"] = int(inventory.get("goods", finished_goods))

func _ensure_machine_state() -> void:
    for machine_id in DEFAULT_MACHINES:
        if not machines.has(machine_id): machines[machine_id] = DEFAULT_MACHINES[machine_id].duplicate(true)
        var machine: Dictionary = machines[machine_id]
        machine["condition"] = clamp(float(machine.get("condition", 100.0)), 0.0, 100.0)
        machine["automation"] = clamp(int(machine.get("automation", 0)), 0, 5)
        machine["capacity"] = max(1, int(machine.get("capacity", 1)))
        machine["maintenance_due"] = max(0, int(machine.get("maintenance_due", 0)))
        machines[machine_id] = machine
        utilization[machine_id] = float(utilization.get(machine_id, 0.0))
        automation[machine_id] = int(machine.get("automation", 0))

func recipe_ids(stage: String = "") -> Array:
    var result: Array = []
    for recipe_id in RECIPES:
        if stage.is_empty() or String(RECIPES[recipe_id]["stage"]) == stage: result.append(recipe_id)
    return result

func get_recipe(recipe_id: String) -> Dictionary:
    return RECIPES.get(recipe_id, {}).duplicate(true)

func stock(item: String) -> int:
    return int(inventory.get(item, 0))

func add_inventory(item: String, amount: int) -> void:
    if amount == 0: return
    inventory[item] = max(0, int(inventory.get(item, 0)) + amount)

func unlock_technology(technology: String, level: int = 1) -> void:
    technologies[technology] = max(int(technologies.get(technology, 0)), level)

func acquire_machine(machine_id: String, capacity: int = 1) -> bool:
    if not machines.has(machine_id): return false
    machines[machine_id]["owned"] = true
    machines[machine_id]["capacity"] = max(int(machines[machine_id].get("capacity", 1)), capacity)
    return true

func set_automation(machine_id: String, level: int) -> bool:
    if not machines.has(machine_id) or not bool(machines[machine_id].get("owned", false)): return false
    var value: int = int(clamp(level, 0, 5))
    machines[machine_id]["automation"] = value
    automation[machine_id] = value
    return true

func can_run(recipe_id: String, cycles: int = 1) -> Dictionary:
    if not RECIPES.has(recipe_id) or cycles <= 0: return {"ok":false,"reason":"invalid_recipe"}
    var recipe: Dictionary = RECIPES[recipe_id]
    var machine_id := String(recipe["machine"])
    if not machines.has(machine_id) or not bool(machines[machine_id].get("owned", false)): return {"ok":false,"reason":"machine_required","machine":machine_id}
    if int(technologies.get(recipe["technology"], 0)) <= 0: return {"ok":false,"reason":"technology_required","technology":recipe["technology"]}
    var machine: Dictionary = machines[machine_id]
    if float(machine.get("condition", 0.0)) <= 5.0: return {"ok":false,"reason":"maintenance_required","machine":machine_id}
    var capacity := int(machine.get("capacity", 1)) + int(machine.get("automation", 0))
    var requested := min(cycles, capacity)
    for item in recipe["inputs"]:
        var required: int = int(recipe["inputs"][item]) * requested
        if stock(item) < required: return {"ok":false,"reason":"missing_input","item":item,"required":required,"available":stock(item)}
    return {"ok":true,"cycles":requested,"machine":machine_id}

func run_recipe(recipe_id: String, cycles: int = 1) -> Dictionary:
    var check := can_run(recipe_id, cycles)
    if not check["ok"]: return check
    var recipe: Dictionary = RECIPES[recipe_id]
    var machine_id := String(recipe["machine"])
    var run_cycles := int(check["cycles"])
    var machine: Dictionary = machines[machine_id]
    var automation_level := int(machine.get("automation", 0))
    var condition := float(machine.get("condition", 100.0))
    var effective_waste := clamp(float(recipe["waste"]) - automation_level * 0.012 + (100.0 - condition) * 0.0015, 0.0, 0.35)
    for item in recipe["inputs"]: add_inventory(item, -int(recipe["inputs"][item]) * run_cycles)
    var outputs: Dictionary = {}
    var total_output := 0
    for item in recipe["outputs"]:
        var planned := int(recipe["outputs"][item]) * run_cycles
        var waste_amount := int(floor(float(planned) * effective_waste))
        var actual := max(0, planned - waste_amount)
        add_inventory(item, actual)
        outputs[item] = actual
        total_output += actual
        waste[item] = int(waste.get(item, 0)) + waste_amount
    var run_quality := clamp(int(recipe["base_quality"]) + randi_range(-2, 3) + automation_level + int(round((condition - 80.0) / 20.0)), 25, 100)
    quality = int(round((float(quality) + run_quality) / 2.0))
    machine["condition"] = max(0.0, condition - (0.7 + run_cycles * 0.55 - automation_level * 0.08))
    machine["maintenance_due"] = int(machine.get("maintenance_due", 0)) + run_cycles
    machines[machine_id] = machine
    utilization[machine_id] = clamp(float(utilization.get(machine_id, 0.0)) * 0.75 + float(run_cycles) / float(max(1, int(machine.get("capacity", 1)) + automation_level)) * 25.0, 0.0, 100.0)
    last_run = {"recipe":recipe_id,"stage":recipe["stage"],"cycles":run_cycles,"outputs":outputs,"quality":run_quality,"waste":effective_waste,"machine":machine_id,"condition":machine["condition"]}
    history.append(last_run.duplicate(true))
    if history.size() > MAX_HISTORY: history.pop_front()
    if recipe["stage"] == "retail":
        for item in outputs:
            if String(item).begins_with("customer_"): finished_goods += int(outputs[item])
    inventory["goods"] = finished_goods
    return {"ok":true,"recipe":recipe_id,"stage":recipe["stage"],"cycles":run_cycles,"outputs":outputs,"output":total_output,"quality":run_quality,"waste_rate":effective_waste,"machine":machine_id,"condition":machine["condition"],"utilization":utilization[machine_id]}

func produce(economy: RenewEconomy, cycles: int) -> Dictionary:
    if economy == null or cycles <= 0: return {"ok":false,"cycles":0,"output":0,"quality":quality}
    var possible := cycles
    for resource in ["materials","packaging","fuel"]:
        if not economy.resources.has(resource): return {"ok":false,"cycles":0,"output":0,"quality":quality}
        possible = min(possible, int(economy.resources[resource]["stock"]))
    if possible <= 0: return {"ok":false,"cycles":0,"output":0,"quality":quality}
    for resource in ["materials","packaging","fuel"]: economy.resources[resource]["stock"] -= possible
    var waste_amount := int(floor(float(possible) * 0.06))
    var output := max(0, possible * 2 - waste_amount)
    finished_goods += output
    inventory["goods"] = finished_goods
    quality = clamp(quality + randi_range(-3, 4), 30, 100)
    history.append({"recipe":"legacy_consumer_goods","stage":"manufacturing","cycles":possible,"output":output,"quality":quality,"waste":0.06})
    if history.size() > MAX_HISTORY: history.pop_front()
    return {"ok":true,"cycles":possible,"output":output,"quality":quality,"finished_goods":finished_goods,"waste":waste_amount}

func consume_goods(amount: int) -> bool:
    if amount < 0 or amount > finished_goods: return false
    finished_goods -= amount
    inventory["goods"] = finished_goods
    return true

func maintain_machine(machine_id: String, finance = null) -> Dictionary:
    if not machines.has(machine_id) or not bool(machines[machine_id].get("owned", false)): return {"ok":false,"reason":"machine_not_owned"}
    var machine: Dictionary = machines[machine_id]
    var condition := float(machine.get("condition", 100.0))
    var cost := int(round((100.0 - condition) * 35.0 + int(machine.get("maintenance_due", 0)) * 12.0))
    if cost > 0 and finance != null:
        var payment = finance.spend(cost, "maintenance:%s" % machine_id)
        if not payment["ok"]: return {"ok":false,"reason":"insufficient_funds","cost":cost}
    machine["condition"] = 100.0
    machine["maintenance_due"] = 0
    machines[machine_id] = machine
    return {"ok":true,"machine":machine_id,"cost":cost,"condition":100.0}

func advance_day() -> void:
    for machine_id in machines:
        var machine: Dictionary = machines[machine_id]
        machine["condition"] = max(0.0, float(machine.get("condition", 100.0)) - 0.25)
        machines[machine_id] = machine

func capture_state() -> Dictionary:
    return {"system_version":SYSTEM_VERSION,"finished_goods":finished_goods,"quality":quality,"inventory":inventory.duplicate(true),"machines":machines.duplicate(true),"technologies":technologies.duplicate(true),"utilization":utilization.duplicate(true),"waste":waste.duplicate(true),"automation":automation.duplicate(true),"history":history.duplicate(true),"last_run":last_run.duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    finished_goods = int(snapshot.get("finished_goods", 0))
    quality = int(snapshot.get("quality", 60))
    inventory = snapshot.get("inventory", {}).duplicate(true)
    machines = snapshot.get("machines", DEFAULT_MACHINES).duplicate(true)
    technologies = snapshot.get("technologies", technologies).duplicate(true)
    utilization = snapshot.get("utilization", {}).duplicate(true)
    waste = snapshot.get("waste", {}).duplicate(true)
    automation = snapshot.get("automation", {}).duplicate(true)
    history = snapshot.get("history", []).duplicate(true)
    last_run = snapshot.get("last_run", {}).duplicate(true)
    _ensure_inventory()
    _ensure_machine_state()
