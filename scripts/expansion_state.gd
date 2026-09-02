extends RefCounted
class_name RenewExpansionState

# Canonical mutation adapter for expansion state.
# GameState remains the durable authority; the Expansion node is only a runtime projection.

const EXPANSION_PATH := ["expansion"]

static func ensure(state) -> Dictionary:
    if state == null:
        return {}
    var expansion = state.get_value(EXPANSION_PATH, {})
    if not (expansion is Dictionary):
        expansion = {}
    if not expansion.has("properties") or not (expansion["properties"] is Array):
        expansion["properties"] = []
    if not expansion.has("resource_sites") or not (expansion["resource_sites"] is Array):
        expansion["resource_sites"] = []
    state.set_value(EXPANSION_PATH, expansion)
    return expansion

static func set_property(state, index: int, values: Dictionary) -> bool:
    var expansion := ensure(state)
    var properties: Array = expansion["properties"]
    if index < 0 or index >= properties.size():
        return false
    if not (properties[index] is Dictionary):
        return false
    var record: Dictionary = properties[index]
    for key in values.keys():
        record[key] = values[key]
    properties[index] = record
    expansion["properties"] = properties
    state.set_value(EXPANSION_PATH, expansion)
    return true

static func set_resource_site(state, index: int, values: Dictionary) -> bool:
    var expansion := ensure(state)
    var sites: Array = expansion["resource_sites"]
    if index < 0 or index >= sites.size():
        return false
    if not (sites[index] is Dictionary):
        return false
    var record: Dictionary = sites[index]
    for key in values.keys():
        record[key] = values[key]
    sites[index] = record
    expansion["resource_sites"] = sites
    state.set_value(EXPANSION_PATH, expansion)
    return true

static func adjust_player(state, cash_delta: int, reputation_delta: int) -> void:
    var expansion := ensure(state)
    expansion["cash"] = int(expansion.get("cash", 0)) + cash_delta
    expansion["reputation"] = int(expansion.get("reputation", 0)) + reputation_delta
    state.set_value(EXPANSION_PATH, expansion)

static func advance_day(state, profit: int, population_delta: int = 0) -> Dictionary:
    var expansion := ensure(state)
    var day := int(expansion.get("day", 1)) + 1
    var cash := int(expansion.get("cash", 0)) + profit
    var population := int(expansion.get("population", 100)) + population_delta
    expansion["day"] = day
    expansion["cash"] = cash
    expansion["population"] = population
    state.set_value(EXPANSION_PATH, expansion)
    return {"day": day, "cash": cash, "population": population, "profit": profit}

static func record_purchase(state, index: int, cost: int, reputation_delta: int = 0) -> bool:
    var expansion := ensure(state)
    if int(expansion.get("cash", 0)) < cost:
        return false
    var properties: Array = expansion["properties"]
    if index < 0 or index >= properties.size() or not (properties[index] is Dictionary):
        return false
    var property: Dictionary = properties[index]
    if bool(property.get("owned", false)):
        return false
    property["owned"] = true
    property["active"] = true
    property["condition"] = 100
    properties[index] = property
    expansion["properties"] = properties
    expansion["cash"] = int(expansion.get("cash", 0)) - cost
    expansion["reputation"] = int(expansion.get("reputation", 0)) + reputation_delta
    expansion["restored_count"] = int(expansion.get("restored_count", 0)) + 1
    state.set_value(EXPANSION_PATH, expansion)
    return true

static func record_resource_purchase(state, index: int, cost: int, reputation_delta: int = 0) -> bool:
    var expansion := ensure(state)
    if int(expansion.get("cash", 0)) < cost:
        return false
    var sites: Array = expansion["resource_sites"]
    if index < 0 or index >= sites.size() or not (sites[index] is Dictionary):
        return false
    var site: Dictionary = sites[index]
    if bool(site.get("owned", false)):
        return false
    site["owned"] = true
    sites[index] = site
    expansion["resource_sites"] = sites
    expansion["cash"] = int(expansion.get("cash", 0)) - cost
    expansion["reputation"] = int(expansion.get("reputation", 0)) + reputation_delta
    state.set_value(EXPANSION_PATH, expansion)
    return true

static func record_property_upgrade(state, index: int, cost: int, income_delta: int = 500, value_delta: int = 5000) -> bool:
    var expansion := ensure(state)
    if int(expansion.get("cash", 0)) < cost:
        return false
    var properties: Array = expansion["properties"]
    if index < 0 or index >= properties.size() or not (properties[index] is Dictionary):
        return false
    var property: Dictionary = properties[index]
    if not bool(property.get("owned", false)):
        return false
    property["level"] = int(property.get("level", 1)) + 1
    property["income"] = int(property.get("income", 0)) + income_delta
    property["value"] = int(property.get("value", 0)) + value_delta
    properties[index] = property
    expansion["properties"] = properties
    expansion["cash"] = int(expansion.get("cash", 0)) - cost
    expansion["management_level"] = max(int(expansion.get("management_level", 0)), int(properties.size() / 2))
    state.set_value(EXPANSION_PATH, expansion)
    return true

static func record_resource_upgrade(state, index: int, cost: int, output_delta: int = 2, risk_delta: int = -1) -> bool:
    var expansion := ensure(state)
    if int(expansion.get("cash", 0)) < cost:
        return false
    var sites: Array = expansion["resource_sites"]
    if index < 0 or index >= sites.size() or not (sites[index] is Dictionary):
        return false
    var site: Dictionary = sites[index]
    if not bool(site.get("owned", false)):
        return false
    site["level"] = int(site.get("level", 1)) + 1
    site["output"] = int(site.get("output", 0)) + output_delta
    site["risk"] = max(3, int(site.get("risk", 0)) + risk_delta)
    sites[index] = site
    expansion["resource_sites"] = sites
    expansion["cash"] = int(expansion.get("cash", 0)) - cost
    state.set_value(EXPANSION_PATH, expansion)
    return true
