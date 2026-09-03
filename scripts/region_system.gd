extends Node

## Phase 23: one focused V1 region with several cities and resource locations.
## Region facts live in GameState.regions; this system owns region behavior/query rules.
const REGION_ID := "renew_region"
const REGION_NAME := "Renew Region"
const CITIES := [{"id":"capital_city","name":"Capital City","type":"capital","description":"Administrative and commercial center of Renew Region."},{"id":"industrial_city","name":"Industrial City","type":"industrial","description":"Manufacturing center connected to the region's resource network."},{"id":"port_city","name":"Port City","type":"port","description":"Regional trade and logistics gateway."},{"id":"rural_town","name":"Rural Town","type":"rural","description":"Agricultural community supplying the region."}]
const RESOURCE_LOCATIONS := [{"id":"forest","name":"Forest","resource":"timber","city_id":"rural_town","capacity":100,"description":"Managed woodland supplying timber."},{"id":"iron_mine","name":"Iron Mine","resource":"iron","city_id":"industrial_city","capacity":80,"description":"Mine supplying iron for industrial production."},{"id":"energy_plant","name":"Energy Plant","resource":"energy","city_id":"industrial_city","capacity":120,"description":"Regional energy generation facility."},{"id":"farm","name":"Farm","resource":"food","city_id":"rural_town","capacity":100,"description":"Agricultural land producing food."},{"id":"technology_hub","name":"Technology Hub","resource":"electronics_components","city_id":"capital_city","capacity":60,"description":"Technology cluster supplying advanced components and expertise."}]
var state_adapter = null
func _ready() -> void: state_adapter = get_node_or_null("/root/RenewGameState"); _ensure_region_state()
func _state():
    if state_adapter == null: state_adapter = get_node_or_null("/root/RenewGameState")
    return state_adapter
func _ensure_region_state() -> void:
    var state = _state(); if state == null: return
    var districts = state.get_value("regions", "districts", {}); if not districts is Dictionary: districts = {}
    if not districts.has(REGION_ID): districts[REGION_ID] = {"id":REGION_ID,"name":REGION_NAME,"cities":CITIES.duplicate(true),"resource_locations":RESOURCE_LOCATIONS.duplicate(true)}; state.set_value("regions", "districts", districts)
    var sites = state.get_value("supply_chain", "resource_sites", {}); if not sites is Dictionary: sites = {}
    for location in RESOURCE_LOCATIONS:
        if not sites.has(location["id"]): sites[location["id"]] = {"id":location["id"],"name":location["name"],"resource":location["resource"],"city_id":location["city_id"],"capacity":location["capacity"],"active":true}
    state.set_value("supply_chain", "resource_sites", sites)
func get_region() -> Dictionary: return {"id":REGION_ID,"name":REGION_NAME,"cities":CITIES.duplicate(true),"resource_locations":RESOURCE_LOCATIONS.duplicate(true)}
func get_cities() -> Array: return CITIES.duplicate(true)
func get_resource_locations() -> Array: return RESOURCE_LOCATIONS.duplicate(true)
func get_city(city_id: String) -> Dictionary:
    for city in CITIES:
        if city["id"] == city_id: return city.duplicate(true)
    return {}
func get_resource_location(location_id: String) -> Dictionary:
    for location in RESOURCE_LOCATIONS:
        if location["id"] == location_id: return location.duplicate(true)
    return {}
func get_locations_for_resource(resource_id: String) -> Array:
    var result:Array = []
    for location in RESOURCE_LOCATIONS:
        if location["resource"] == resource_id: result.append(location.duplicate(true))
    return result
