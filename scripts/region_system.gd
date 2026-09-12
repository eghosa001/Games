extends Node

## Phase 23: one focused V1 region with several cities and resource locations.
## Region facts live in GameState.regions; this system owns region behavior/query rules.
const DomainSystem = preload("res://scripts/domain_system.gd")
const REGION_ID := "renew_region"
const REGION_NAME := "Renew Region"
const CITIES := [{"id":"capital_city","name":"Capital City","type":"capital","description":"Administrative and commercial center of Renew Region."},{"id":"industrial_city","name":"Industrial City","type":"industrial","description":"Manufacturing center connected to the region's resource network."},{"id":"port_city","name":"Port City","type":"port","description":"Regional trade and logistics gateway."},{"id":"rural_town","name":"Rural Town","type":"rural","description":"Agricultural community supplying the region."}]
const RESOURCE_LOCATIONS := [{"id":"forest","name":"Forest","resource":"timber","city_id":"rural_town","capacity":100,"description":"Managed woodland supplying timber."},{"id":"iron_mine","name":"Iron Mine","resource":"iron","city_id":"industrial_city","capacity":80,"description":"Mine supplying iron for industrial production."},{"id":"energy_plant","name":"Energy Plant","resource":"energy","city_id":"industrial_city","capacity":120,"description":"Regional energy generation facility."},{"id":"farm","name":"Farm","resource":"food","city_id":"rural_town","capacity":100,"description":"Agricultural land producing food."},{"id":"technology_hub","name":"Technology Hub","resource":"electronics","city_id":"capital_city","capacity":60,"description":"Technology cluster supplying advanced components and expertise."}]
const BASIN_ID := "iron_basin"
const BASIN_NAME := "Iron Basin"
const BASIN_UNLOCK_REPUTATION := 30
const BASIN_CHARTER_COST := 15000
const BASIN_CITIES := [{"id":"furnace_city","name":"Furnace City","type":"industrial","description":"Smelting city at the heart of the Iron Basin."},{"id":"ore_town","name":"Ore Town","type":"rural","description":"Mining community above the deep iron seams."},{"id":"basin_port","name":"Basin Port","type":"port","description":"Bulk-material export terminal for basin ore and energy."}]
const BASIN_LOCATIONS := [{"id":"deep_iron_seam","name":"Deep Iron Seam","resource":"iron","city_id":"ore_town","capacity":160,"description":"Rich deep iron deposit, the basin's prize asset."},{"id":"coal_seams","name":"Coal Seams","resource":"energy","city_id":"furnace_city","capacity":140,"description":"Dense coal seams feeding basin furnaces."},{"id":"basin_timber","name":"Basin Timber Stand","resource":"timber","city_id":"ore_town","capacity":40,"description":"Sparse highland timber, barely enough for local use."},{"id":"basin_workshops","name":"Basin Workshops","resource":"electronics","city_id":"basin_port","capacity":30,"description":"Imported-component workshops near the port."}]
const VALLEY_ID := "energy_valley"
const VALLEY_NAME := "Energy Valley"
const VALLEY_UNLOCK_REPUTATION := 50
const VALLEY_CHARTER_COST := 25000
const VALLEY_CITIES := [{"id":"geothermal_town","name":"Geothermal Town","type":"industrial","description":"Power town built over the valley's geothermal fields."},{"id":"solar_flats","name":"Solar Flats","type":"rural","description":"Mirror arrays stretching across the valley floor."},{"id":"grid_port","name":"Grid Port","type":"port","description":"Energy export terminal feeding the regional grid."}]
const VALLEY_LOCATIONS := [{"id":"geothermal_vent","name":"Geothermal Vent","resource":"energy","city_id":"geothermal_town","capacity":200,"description":"The valley's prize: relentless geothermal output."},{"id":"solar_array","name":"Solar Array","resource":"energy","city_id":"solar_flats","capacity":120,"description":"Utility-scale solar across the flats."},{"id":"valley_timber","name":"Valley Timber Belt","resource":"timber","city_id":"solar_flats","capacity":60,"description":"Managed timber buffering the arrays."},{"id":"grid_workshops","name":"Grid Workshops","resource":"electronics","city_id":"grid_port","capacity":40,"description":"Component shops serving the energy trade."}]
var state_adapter = null
var finance_adapter = DomainSystem.new()
func _ready() -> void:
    state_adapter = get_node_or_null("/root/RenewGameState")
    add_child(finance_adapter)
    _ensure_region_state()
func _state():
    if state_adapter == null: state_adapter = get_node_or_null("/root/RenewGameState")
    return state_adapter
func _ensure_region_state() -> void:
    var state = _state(); if state == null: return
    var districts = state.get_value("regions", "districts", {}).duplicate(true); if not districts is Dictionary: districts = {}
    if not districts.has(REGION_ID): districts[REGION_ID] = {"id":REGION_ID,"name":REGION_NAME,"cities":CITIES.duplicate(true),"resource_locations":RESOURCE_LOCATIONS.duplicate(true)}
    if not districts.has(BASIN_ID): districts[BASIN_ID] = {"id":BASIN_ID,"name":BASIN_NAME,"cities":BASIN_CITIES.duplicate(true),"resource_locations":BASIN_LOCATIONS.duplicate(true),"chartered":false,"unlock_reputation":BASIN_UNLOCK_REPUTATION,"charter_cost":BASIN_CHARTER_COST}
    if not districts.has(VALLEY_ID): districts[VALLEY_ID] = {"id":VALLEY_ID,"name":VALLEY_NAME,"cities":VALLEY_CITIES.duplicate(true),"resource_locations":VALLEY_LOCATIONS.duplicate(true),"chartered":false,"unlock_reputation":VALLEY_UNLOCK_REPUTATION,"charter_cost":VALLEY_CHARTER_COST}
    state.set_value("regions", "districts", districts)
    var sites = state.get_value("supply_chain", "resource_sites", {}).duplicate(true); if not sites is Dictionary: sites = {}
    for location in RESOURCE_LOCATIONS:
        if not sites.has(location["id"]): sites[location["id"]] = {"id":location["id"],"name":location["name"],"resource":location["resource"],"city_id":location["city_id"],"capacity":location["capacity"],"active":true}
    var basin = districts.get(BASIN_ID, {})
    if bool(basin.get("chartered", false)):
        for location in BASIN_LOCATIONS:
            if not sites.has(location["id"]): sites[location["id"]] = {"id":location["id"],"name":location["name"],"resource":location["resource"],"city_id":location["city_id"],"capacity":location["capacity"],"active":true}
    var valley = districts.get(VALLEY_ID, {})
    if bool(valley.get("chartered", false)):
        for location in VALLEY_LOCATIONS:
            if not sites.has(location["id"]): sites[location["id"]] = {"id":location["id"],"name":location["name"],"resource":location["resource"],"city_id":location["city_id"],"capacity":location["capacity"],"active":true}
    state.set_value("supply_chain", "resource_sites", sites)
func is_basin_chartered() -> bool:
    var state = _state(); if state == null: return false
    var districts = state.get_value("regions", "districts", {})
    if not districts is Dictionary: return false
    return bool(districts.get(BASIN_ID, {}).get("chartered", false))
func charter_basin(reputation: int) -> Dictionary:
    if is_basin_chartered(): return {"ok":false,"reason":"already_chartered","message":"The Iron Basin is already chartered."}
    if reputation < BASIN_UNLOCK_REPUTATION: return {"ok":false,"reason":"reputation","required":BASIN_UNLOCK_REPUTATION,"message":"The Iron Basin charter requires %d reputation." % BASIN_UNLOCK_REPUTATION}
    var state = _state(); if state == null: return {"ok":false,"reason":"state_unavailable","message":"Region state is unavailable."}
    var districts = state.get_value("regions", "districts", {}).duplicate(true)
    if not districts is Dictionary or not districts.has(BASIN_ID): return {"ok":false,"reason":"region_not_found","message":"Iron Basin survey data is missing."}
    var spend: Dictionary = finance_adapter.spend(BASIN_CHARTER_COST, "iron basin charter")
    if not bool(spend.get("ok", false)):
        return {"ok":false,"reason":"money","cost":BASIN_CHARTER_COST,"message":str(spend.get("message","The basin charter requires sufficient cash."))}
    districts[BASIN_ID]["chartered"] = true
    state.set_value("regions", "districts", districts)
    var sites = state.get_value("supply_chain", "resource_sites", {}).duplicate(true); if not sites is Dictionary: sites = {}
    for location in BASIN_LOCATIONS:
        if not sites.has(location["id"]): sites[location["id"]] = {"id":location["id"],"name":location["name"],"resource":location["resource"],"city_id":location["city_id"],"capacity":location["capacity"],"active":true}
    state.set_value("supply_chain", "resource_sites", sites)
    return {"ok":true,"cost":BASIN_CHARTER_COST,"payment":spend,"message":"Iron Basin chartered. Deep iron and coal seams are now accessible."}
func is_valley_chartered() -> bool:
    var state = _state(); if state == null: return false
    var districts = state.get_value("regions", "districts", {})
    if not districts is Dictionary: return false
    return bool(districts.get(VALLEY_ID, {}).get("chartered", false))
func charter_valley(reputation: int) -> Dictionary:
    if is_valley_chartered(): return {"ok":false,"reason":"already_chartered","message":"The Energy Valley is already chartered."}
    if reputation < VALLEY_UNLOCK_REPUTATION: return {"ok":false,"reason":"reputation","required":VALLEY_UNLOCK_REPUTATION,"message":"The Energy Valley charter requires %d reputation." % VALLEY_UNLOCK_REPUTATION}
    var state = _state(); if state == null: return {"ok":false,"reason":"state_unavailable","message":"Region state is unavailable."}
    var districts = state.get_value("regions", "districts", {}).duplicate(true)
    if not districts is Dictionary or not districts.has(VALLEY_ID): return {"ok":false,"reason":"region_not_found","message":"Energy Valley survey data is missing."}
    var spend: Dictionary = finance_adapter.spend(VALLEY_CHARTER_COST, "energy valley charter")
    if not bool(spend.get("ok", false)):
        return {"ok":false,"reason":"money","cost":VALLEY_CHARTER_COST,"message":str(spend.get("message","The valley charter requires sufficient cash."))}
    districts[VALLEY_ID]["chartered"] = true
    state.set_value("regions", "districts", districts)
    var sites = state.get_value("supply_chain", "resource_sites", {}).duplicate(true); if not sites is Dictionary: sites = {}
    for location in VALLEY_LOCATIONS:
        if not sites.has(location["id"]): sites[location["id"]] = {"id":location["id"],"name":location["name"],"resource":location["resource"],"city_id":location["city_id"],"capacity":location["capacity"],"active":true}
    state.set_value("supply_chain", "resource_sites", sites)
    return {"ok":true,"cost":VALLEY_CHARTER_COST,"payment":spend,"message":"Energy Valley chartered. Geothermal and solar output flow to the grid."}
func get_region() -> Dictionary: return {"id":REGION_ID,"name":REGION_NAME,"cities":CITIES.duplicate(true),"resource_locations":RESOURCE_LOCATIONS.duplicate(true)}
func list_regions() -> Array:
    return [
        {"id":REGION_ID,"name":REGION_NAME,"cities":CITIES.duplicate(true),"resource_locations":RESOURCE_LOCATIONS.duplicate(true)},
        {"id":BASIN_ID,"name":BASIN_NAME,"cities":BASIN_CITIES.duplicate(true),"resource_locations":BASIN_LOCATIONS.duplicate(true),"chartered":is_basin_chartered(),"unlock_reputation":BASIN_UNLOCK_REPUTATION,"charter_cost":BASIN_CHARTER_COST},
        {"id":VALLEY_ID,"name":VALLEY_NAME,"cities":VALLEY_CITIES.duplicate(true),"resource_locations":VALLEY_LOCATIONS.duplicate(true),"chartered":is_valley_chartered(),"unlock_reputation":VALLEY_UNLOCK_REPUTATION,"charter_cost":VALLEY_CHARTER_COST}
    ]
func get_region_by_id(region_id: String) -> Dictionary:
    for region in list_regions():
        if str(region.get("id", "")) == region_id:
            return region.duplicate(true)
    return {}
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