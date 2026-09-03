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

## Phase 20: complete V1 industry definitions.
const INDUSTRIES = {"furniture":{"id":"furniture","name":"Furniture","inputs":{"timber":1.0,"metal":0.5,"energy":2.0},"output":{"product":"furniture","units":1},"workers":3,"capacity":6,"operating_cost":70,"base_price":220,"market_demand":80},"construction_materials":{"id":"construction_materials","name":"Construction Materials","inputs":{"timber":1.0,"stone":2.0,"energy":2.5},"output":{"product":"construction_materials","units":1},"workers":4,"capacity":5,"operating_cost":95,"base_price":180,"market_demand":100},"consumer_electronics":{"id":"consumer_electronics","name":"Consumer Electronics","inputs":{"metal":1.0,"electronics_components":1.0,"energy":3.0},"output":{"product":"consumer_electronics","units":1},"workers":5,"capacity":4,"operating_cost":130,"base_price":360,"market_demand":70}}
const PURPOSES = {"Warehouse":[{"id":"furniture_factory","name":"Furniture Factory","type":"Factory","product":"furniture","industry_id":"furniture"},{"id":"construction_materials_factory","name":"Construction Materials Plant","type":"Factory","product":"construction_materials","industry_id":"construction_materials"},{"id":"consumer_electronics_factory","name":"Consumer Electronics Factory","type":"Factory","product":"consumer_electronics","industry_id":"consumer_electronics"}],"Workshop":[{"id":"furniture_factory","name":"Furniture Factory","type":"Factory","product":"furniture","industry_id":"furniture"},{"id":"construction_materials_factory","name":"Construction Materials Plant","type":"Factory","product":"construction_materials","industry_id":"construction_materials"},{"id":"consumer_electronics_factory","name":"Consumer Electronics Factory","type":"Factory","product":"consumer_electronics","industry_id":"consumer_electronics"}],"Commercial Building":[{"id":"furniture_factory","name":"Furniture Factory","type":"Factory","product":"furniture","industry_id":"furniture"},{"id":"construction_materials_factory","name":"Construction Materials Plant","type":"Factory","product":"construction_materials","industry_id":"construction_materials"},{"id":"consumer_electronics_factory","name":"Consumer Electronics Factory","type":"Factory","product":"consumer_electronics","industry_id":"consumer_electronics"}]}

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
    var value = INDUSTRIES.get(industry_id, null)
    return value.duplicate(true) if value is Dictionary else {}

func get_business_purposes(property_type: String = "") -> Array:
    if PURPOSES.has(property_type):
        return PURPOSES[property_type].duplicate(true)
    var result: Array = []
    for entries in PURPOSES.values():
        for entry in entries:
            if entry not in result:
                result.append(entry.duplicate(true))
    return result

func get_business_purpose(purpose_id: String, property_type: String = "") -> Dictionary:
    for purpose in get_business_purposes(property_type):
        if str(purpose.get("id", "")) == purpose_id:
            return purpose.duplicate(true)
    return {}

func open_business(property_id: String, purpose_id: String = "furniture_factory") -> Dictionary:
    var properties = state_adapter.get_value("properties", "properties", {})
    if not properties is Dictionary or not properties.has(property_id):
        return {"ok": false, "reason": "property_not_found"}
    var property: Dictionary = properties[property_id]
    if not bool(property.get("owned", false)) or not bool(property.get("operational", false)):
        return {"ok": false, "reason": "property_not_operational"}
    var purpose := get_business_purpose(purpose_id, str(property.get("type", "")))
    if purpose.is_empty():
        return {"ok": false, "reason": "invalid_purpose"}
    var businesses = state_adapter.get_value("businesses", "businesses", {})
    if not businesses is Dictionary:
        businesses = {}
    var business_id := "business_%s" % property_id
    if businesses.has(business_id):
        return {"ok": false, "reason": "business_exists"}
    var cash := int(state_adapter.get_value("economy", "cash", 0))
    if cash < 3000:
        return {"ok": false, "reason": "insufficient_cash", "cost": 3000}
    state_adapter.set_value("economy", "cash", cash - 3000)
    var business := {"id": business_id, "name": "%s Business" % purpose.get("name", "Business"), "industry_id": purpose.get("industry_id", "furniture"), "purpose_id": purpose_id, "property_id": property_id, "property_name": property.get("name", property_id), "property_type": property.get("type", ""), "operational": true}
    businesses[business_id] = business
    state_adapter.set_value("businesses", "businesses", businesses)
    return {"ok": true, "business": business.duplicate(true), "cost": 3000}

func produce(cycles: int = 1) -> Dictionary:
    var selected = state_adapter.get_value("businesses", "selected_business_id", "")
    var business_id := str(selected)
    var businesses = state_adapter.get_value("businesses", "businesses", {})
    if not businesses is Dictionary or not businesses.has(business_id):
        return {"ok": false, "reason": "business_not_found"}
    var business: Dictionary = businesses[business_id]
    var industry_id := str(business.get("industry_id", "furniture"))
    if industry_id != "furniture":
        return {"ok": false, "reason": "industry_pipeline_not_connected", "industry_id": industry_id}
    return production.produce(economy, cycles)

func capture_state() -> Dictionary:
    return {"system_version": 1, "businesses": state_adapter.get_value("businesses", "businesses", {}).duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty():
        return
    var businesses = snapshot.get("businesses", {})
    if businesses is Dictionary:
        state_adapter.set_value("businesses", "businesses", businesses.duplicate(true))
