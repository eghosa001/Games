extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const Economy = preload("res://scripts/economy.gd")
const Production = preload("res://scripts/production.gd")
const SupplyChain = preload("res://scripts/supply_chain_system.gd")

var state_adapter = DomainSystem.new()
var economy = Economy.new()
var production = Production.new()
var supply_chain = SupplyChain.new()
var employee_system = null

## V1 industries: each has a real production recipe and warehouse output.
const INDUSTRIES := {
    "furniture": {"id":"furniture","name":"Furniture","inputs":{"timber":1.0,"metal":0.5,"energy":2.0},"output":{"product":"furniture","units":1},"workers":3,"capacity":6,"operating_cost":70,"base_price":220,"market_demand":80},
    "construction_materials": {"id":"construction_materials","name":"Construction Materials","inputs":{"timber":1.0,"iron":1.0,"energy":2.5},"output":{"product":"construction_materials","units":1},"workers":4,"capacity":5,"operating_cost":95,"base_price":180,"market_demand":100},
    "consumer_electronics": {"id":"consumer_electronics","name":"Consumer Electronics","inputs":{"iron":1.0,"electronics":1.0,"energy":3.0},"output":{"product":"consumer_electronics","units":1},"workers":5,"capacity":4,"operating_cost":130,"base_price":360,"market_demand":70}
}

## The production layer is deliberately separate from the UI purpose IDs.
## This makes industry_id the authoritative dispatch key for production.
const INDUSTRY_PRODUCTION := {
    "furniture": {"purpose":"furniture_factory","inputs":{"timber":1.0,"metal":0.5,"energy":2.0},"product":"furniture","base_price":220,"operating_cost":70},
    "construction_materials": {"purpose":"construction_materials_factory","inputs":{"timber":1.0,"iron":1.0,"energy":2.5},"product":"construction_materials","base_price":180,"operating_cost":95},
    "consumer_electronics": {"purpose":"consumer_electronics_factory","inputs":{"iron":1.0,"electronics":1.0,"energy":3.0},"product":"consumer_electronics","base_price":360,"operating_cost":130}
}

## Every V1 property type offers the same three industry choices.
const PURPOSES := {
    "Warehouse": [
        {"id":"furniture_factory","name":"Furniture Factory","type":"Factory","product":"furniture","industry_id":"furniture"},
        {"id":"construction_materials_factory","name":"Construction Materials Plant","type":"Factory","product":"construction_materials","industry_id":"construction_materials"},
        {"id":"consumer_electronics_factory","name":"Consumer Electronics Factory","type":"Factory","product":"consumer_electronics","industry_id":"consumer_electronics"}
    ],
    "Workshop": [
        {"id":"furniture_factory","name":"Furniture Factory","type":"Factory","product":"furniture","industry_id":"furniture"},
        {"id":"construction_materials_factory","name":"Construction Materials Plant","type":"Factory","product":"construction_materials","industry_id":"construction_materials"},
        {"id":"consumer_electronics_factory","name":"Consumer Electronics Factory","type":"Factory","product":"consumer_electronics","industry_id":"consumer_electronics"}
    ],
    "Commercial Building": [
        {"id":"furniture_factory","name":"Furniture Factory","type":"Factory","product":"furniture","industry_id":"furniture"},
        {"id":"construction_materials_factory","name":"Construction Materials Plant","type":"Factory","product":"construction_materials","industry_id":"construction_materials"},
        {"id":"consumer_electronics_factory","name":"Consumer Electronics Factory","type":"Factory","product":"consumer_electronics","industry_id":"consumer_electronics"}
    ]
}

func _ready() -> void:
    add_child(state_adapter)
    add_child(supply_chain)
    supply_chain.set_economy(economy)

func _technology():
    return get_node_or_null("/root/RenewTechnologySystem")

func get_industries() -> Array:
    var result: Array = []
    for key in INDUSTRIES.keys():
        result.append(INDUSTRIES[key].duplicate(true))
    return result

func get_industry(industry_id: String) -> Dictionary:
    return INDUSTRIES.get(industry_id, {}).duplicate(true)

func get_business_purposes() -> Array:
    return PURPOSES.get(_origin_property_type(), []).duplicate(true)

func get_business_purpose(purpose) -> Dictionary:
    var choices: Array = get_business_purposes()
    if purpose is int:
        var index: int = int(purpose)
        if index < 0 or index >= choices.size():
            return {}
        return choices[index].duplicate(true)
    var purpose_id: String = str(purpose)
    for choice in choices:
        if str(choice.get("id", "")) == purpose_id:
            return choice.duplicate(true)
    return {}

func open_business() -> void:
    if not bool(state_adapter.get_value("properties", "owned", false)) or str(state_adapter.get_value("properties", "stage", "Neglected")) != "Operational":
        state_adapter.message("Finish restoration first.")
        return
    if bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("%s is already open." % _business_name())
        return
    var existing_purpose: String = str(state_adapter.get_value("businesses", "business_purpose", ""))
    if existing_purpose.is_empty():
        state_adapter.message("Choose what this restored property will become: press 4, 5 or 6.")
        return
    create_business(existing_purpose)

func choose_business_purpose(index: int) -> void:
    if not bool(state_adapter.get_value("properties", "owned", false)):
        state_adapter.message("Acquire a property first.")
        return
    if str(state_adapter.get_value("properties", "stage", "Neglected")) != "Operational":
        state_adapter.message("Finish restoring the property before choosing its purpose.")
        return
    if bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("The property has already been converted into %s." % _business_name())
        return
    var purpose: Dictionary = get_business_purpose(index)
    if purpose.is_empty():
        state_adapter.message("Invalid business purpose.")
        return
    state_adapter.set_value("businesses", "business_purpose", str(purpose.get("id", "")))
    state_adapter.log_message("PURPOSE SELECTED: %s -> %s." % [_origin_property_name(), purpose.get("name", "Business")])
    create_business(str(purpose.get("id", "")))

func create_business(purpose_id: String = "") -> void:
    if not bool(state_adapter.get_value("properties", "owned", false)) or str(state_adapter.get_value("properties", "stage", "Neglected")) != "Operational":
        state_adapter.message("Finish restoration first.")
        return
    if bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("%s is already open." % _business_name())
        return
    var purpose: Dictionary = get_business_purpose(purpose_id if not purpose_id.is_empty() else str(state_adapter.get_value("businesses", "business_purpose", "")))
    if purpose.is_empty():
        state_adapter.message("Choose a business purpose first: press 4, 5 or 6.")
        return
    var cash: int = int(state_adapter.get_value("economy", "cash", 25000))
    if cash < 3000:
        state_adapter.message("Need $3,000 working capital to launch the business.")
        return
    var property: Dictionary = _selected_property()
    var property_id: String = str(property.get("id", ""))
    var business_id: String = "%s_%s" % [purpose.get("id", "business"), property_id]
    state_adapter.set_value("economy", "cash", cash - 3000)
    state_adapter.set_value("businesses", "business_open", true)
    state_adapter.set_value("businesses", "business_id", business_id)
    state_adapter.set_value("businesses", "business_name", str(purpose.get("name", "Business")))
    state_adapter.set_value("businesses", "business_type", str(purpose.get("type", "Business")))
    state_adapter.set_value("businesses", "business_purpose", str(purpose.get("id", "")))
    state_adapter.set_value("businesses", "industry_id", str(purpose.get("industry_id", "furniture")))
    state_adapter.set_value("businesses", "origin_property_id", property_id)
    state_adapter.set_value("businesses", "origin_property_name", str(property.get("name", "Property")))
    state_adapter.set_value("businesses", "origin_property_type", str(property.get("type", "Property")))
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    state_adapter.message("%s created inside %s. The restored property is now the origin of your business." % [purpose.get("name", "Business"), property.get("name", "Property")])
    state_adapter.log_message("BUSINESS CREATED: %s — origin %s (%s)." % [purpose.get("name", "Business"), property.get("name", "Property"), property_id])

func _purpose_by_id(purpose_id: String) -> Dictionary:
    return get_business_purpose(purpose_id)

func _selected_property() -> Dictionary:
    var catalog = state_adapter.get_value("properties", "catalog", [])
    if not catalog is Array or catalog.is_empty():
        return {}
    var index: int = clampi(int(state_adapter.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    return catalog[index].duplicate(true)

func _origin_property_type() -> String:
    var stored: String = str(state_adapter.get_value("businesses", "origin_property_type", ""))
    if not stored.is_empty():
        return stored
    return str(_selected_property().get("type", ""))

func _origin_property_name() -> String:
    var stored: String = str(state_adapter.get_value("businesses", "origin_property_name", ""))
    if not stored.is_empty():
        return stored
    return str(_selected_property().get("name", "Property"))

func _business_name() -> String:
    return str(state_adapter.get_value("businesses", "business_name", "RENEW Goods"))

func upgrade_business() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Create the business first.")
        return
    var level: int = int(state_adapter.get_value("businesses", "capacity_level", 1))
    var cost: int = 4500 * level
    var cash: int = int(state_adapter.get_value("economy", "cash", 25000))
    if cash < cost:
        state_adapter.message("Capacity upgrade requires $%s." % state_adapter.money(cost))
        return
    state_adapter.set_value("economy", "cash", cash - cost)
    state_adapter.set_value("businesses", "capacity_level", level + 1)
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    state_adapter.log_message("UPGRADE: %s capacity level %d." % [_business_name(), level + 1])
    state_adapter.message("%s production capacity upgraded to level %d." % [_business_name(), level + 1])

func marketing_campaign() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Create the business first.")
        return
    var level: int = int(state_adapter.get_value("businesses", "marketing_level", 0))
    var cost: int = 1800 + level * 700
    var cash: int = int(state_adapter.get_value("economy", "cash", 25000))
    if cash < cost:
        state_adapter.message("Marketing requires $%s." % state_adapter.money(cost))
        return
    state_adapter.set_value("economy", "cash", cash - cost)
    state_adapter.set_value("businesses", "marketing_level", level + 1)
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    state_adapter.log_message("MARKETING: %s campaign %d launched (-$%s)." % [_business_name(), level + 1, state_adapter.money(cost)])
    state_adapter.message("Brand strength increased.")

func change_price() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Create the business first.")
        return
    var price: int = int(state_adapter.get_value("businesses", "player_price", 110)) + 10
    if price > 160:
        price = 80
    state_adapter.set_value("businesses", "player_price", price)
    state_adapter.message("Selling price is now $%s." % state_adapter.money(price))

func _property_condition_multiplier() -> float:
    var restoration: int = int(state_adapter.get_value("properties", "restoration", 100))
    return clamp(0.70 + float(restoration) / 100.0 * 0.30, 0.70, 1.0)

func _technology_multiplier() -> float:
    var technology = state_adapter.get_value("technology", "technology", {})
    if not technology is Dictionary:
        return 1.0
    var level: int = 0
    for key in technology.keys():
        level += int(technology[key])
    return clamp(1.0 + float(level) * 0.025, 1.0, 1.35)

func _industry_production_config(industry_id: String) -> Dictionary:
    return INDUSTRY_PRODUCTION.get(industry_id, {}).duplicate(true)

func _prepare_derived_inputs(inputs: Dictionary, cycles: int) -> bool:
    # Metal is an intermediate V1 resource produced from iron + energy.
    var metal_needed: float = float(inputs.get("metal", 0.0)) * float(cycles)
    if metal_needed <= supply_chain.stock("metal"):
        return true
    var missing: float = metal_needed - supply_chain.stock("metal")
    var metal_cycles: int = int(ceil(missing / 1.0))
    var result: Dictionary = supply_chain.process_iron_to_metal(metal_cycles)
    return bool(result.get("ok", false)) and supply_chain.stock("metal") >= metal_needed

func produce_goods() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Create the business first.")
        return

    var industry_id: String = str(state_adapter.get_value("businesses", "industry_id", "furniture"))
    var config: Dictionary = _industry_production_config(industry_id)
    if config.is_empty():
        state_adapter.message("Unknown V1 industry: %s." % industry_id)
        return

    var employee_count: int = 3
    var employee_factor: float = 1.0
    var morale_multiplier: float = 1.0
    if employee_system != null:
        employee_count = employee_system.get_active_employee_count()
        employee_factor = employee_system.get_productivity_multiplier("factory_001")
        morale_multiplier = employee_system.get_morale_multiplier()

    var capacity: int = int(state_adapter.get_value("businesses", "capacity_level", 1))
    var business_efficiency: float = clamp(0.85 + float(capacity) * 0.10, 0.85, 1.50)
    var base_output: int = max(1, employee_count + capacity - 1)
    var output_factor: float = employee_factor * business_efficiency * _technology_multiplier() * _property_condition_multiplier() * morale_multiplier
    var cycles: int = max(1, int(floor(float(base_output) * output_factor)))
    var inputs: Dictionary = config.get("inputs", {}).duplicate(true)
    var cash: int = int(state_adapter.get_value("economy", "cash", 25000))

    # Procure all market inputs that are not derived warehouse intermediates.
    var orders: Array = []
    for resource in inputs:
        var input_name: String = str(resource)
        if input_name == "metal":
            continue
        var needed: float = float(inputs[resource]) * float(cycles)
        var current_stock: float = supply_chain.stock(input_name)
        if current_stock < needed:
            orders.append({"resource":input_name,"amount":needed - current_stock})

    if not orders.is_empty():
        var transport_level: int = int(state_adapter.get_value("supply_chain", "transport_level", 1))
        var delivery: Dictionary = supply_chain.procure_bundle(orders, cash, transport_level)
        if not bool(delivery.get("ok", false)):
            state_adapter.message("%s stopped: supply delivery failed (%s)." % [_business_name(), str(delivery.get("reason", "unknown"))])
            return
        cash -= int(delivery["cost"])
        state_adapter.set_value("economy", "cash", cash)
        state_adapter.log_message("SUPPLY: market resources delivered to %s." % _business_name())

    if not _prepare_derived_inputs(inputs, cycles):
        state_adapter.message("%s stopped: intermediate inputs are unavailable." % _business_name())
        return

    var input_result: Dictionary = supply_chain.consume_inputs(inputs, cycles)
    if not bool(input_result.get("ok", false)):
        state_adapter.message("%s stopped: warehouse inputs are too low." % _business_name())
        return

    var quality: int = clamp(int(round(72.0 + employee_factor * 5.0 + morale_multiplier * 4.0 + _technology_multiplier() * 3.0 + randi_range(-3, 4))), 30, 100)
    var output: int = max(1, cycles - int(floor(float(cycles) * 0.08)))
    var product: String = str(config.get("product", industry_id))
    production.finished_goods += output
    production.inventory[product] = int(production.inventory.get(product, 0)) + output
    production.inventory["goods"] = production.finished_goods
    production.last_run = {"product":product,"industry_id":industry_id,"stage":"manufacturing","cycles":cycles,"output":output,"quality":quality,"resources":input_result.get("consumed", {}),"resource_requirements":inputs,"production_time":2.0,"employee_capacity":int(config.get("workers", 3)),"base_price":int(config.get("base_price", 0)),"operating_cost":int(config.get("operating_cost", 0)),"reputation_effect":2}
    supply_chain.receive_product(product, output)
    state_adapter.set_value("production", "finished_goods", production.finished_goods)
    state_adapter.message("%s produced %d %s at quality %d. Staff efficiency %.2fx." % [_business_name(), output, product.replace("_", " "), quality, output_factor])
    state_adapter.log_message("FACTORY: %s (from %s) -> Warehouse -> Customer; %d %s produced." % [_business_name(), _origin_property_name(), output, product])

func capture_state() -> Dictionary:
    return {"system_version":2,"businesses":state_adapter.get_value("businesses","businesses",{}).duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty():
        return
    var businesses = snapshot.get("businesses", {})
    if businesses is Dictionary:
        state_adapter.set_value("businesses", "businesses", businesses.duplicate(true))
