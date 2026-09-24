extends Node
class_name RenewPropertySystem

## Restoration is the emotional entry point; business is progression.
## Property facts live in GameState.properties. Ownership, inspection and
## restoration are tracked per catalog entry while legacy selected-property
## fields remain synchronized for older systems and saves.

const DomainSystem = preload("res://scripts/domain_system.gd")
const PROPERTY_TYPES := ["Warehouse", "Workshop", "Commercial Building"]
const RESTORATION_STEPS := ["cleaning", "repair", "painting", "furnishing"]
const STEP_COSTS := {"cleaning": 500, "repair": 1500, "painting": 900, "furnishing": 1200}
const STEP_GAIN := {"cleaning": 100, "repair": 100, "painting": 100, "furnishing": 100}
const ACQUISITION_MIN_COST := 5000
const ACQUISITION_BASE_RATE := 0.08
const ACQUISITION_CONDITION_RATE := 0.04
const RESTORATION_REFERENCE_VALUE := 65000.0

const PROPERTY_CATALOG := [
    {"id":"warehouse_001","name":"Riverside Warehouse","type":"Warehouse","condition":35,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":65000,"capacity":80,"industry_compatibility":["Logistics","Manufacturing","Wholesale"],"owned":false,"inspected":false},
    {"id":"warehouse_002","name":"Old Market Warehouse","type":"Warehouse","condition":45,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":78000,"capacity":100,"industry_compatibility":["Logistics","Manufacturing","Retail"],"owned":false,"inspected":false},
    {"id":"warehouse_003","name":"Harbor Storage","type":"Warehouse","condition":55,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":95000,"capacity":130,"industry_compatibility":["Logistics","Wholesale","Manufacturing"],"owned":false,"inspected":false},
    {"id":"workshop_001","name":"Foundry Workshop","type":"Workshop","condition":30,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":72000,"capacity":35,"industry_compatibility":["Manufacturing","Metalwork","Furniture"],"owned":false,"inspected":false},
    {"id":"workshop_002","name":"Timber Workshop","type":"Workshop","condition":40,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":68000,"capacity":30,"industry_compatibility":["Furniture","Manufacturing","Construction"],"owned":false,"inspected":false},
    {"id":"workshop_003","name":"Industrial Workshop","type":"Workshop","condition":50,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":88000,"capacity":45,"industry_compatibility":["Manufacturing","Engineering","Furniture"],"owned":false,"inspected":false},
    {"id":"commercial_001","name":"Main Street Building","type":"Commercial Building","condition":38,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":110000,"capacity":18,"industry_compatibility":["Retail","Services","Wholesale"],"owned":false,"inspected":false},
    {"id":"commercial_002","name":"Market Square Building","type":"Commercial Building","condition":48,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":135000,"capacity":24,"industry_compatibility":["Retail","Services","Hospitality"],"owned":false,"inspected":false},
    {"id":"commercial_003","name":"Riverside Offices","type":"Commercial Building","condition":60,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":160000,"capacity":32,"industry_compatibility":["Services","Finance","Retail"],"owned":false,"inspected":false}
]

var state_adapter: Variant = DomainSystem.new()

func _ready() -> void:
    add_child(state_adapter)
    _ensure_catalog()

func _service(service_name: String):
    var registry = get_node_or_null("/root/RenewServices")
    if registry != null and registry.has_method("get_service"):
        var node = registry.get_service(service_name)
        if node != null:
            return node
    return get_node_or_null("/root/" + service_name)

func _ensure_catalog() -> void:
    var stored = state_adapter.get_value("properties", "catalog", [])
    var legacy_selected := int(state_adapter.get_value("properties", "selected_property", 0))
    var legacy_owned := bool(state_adapter.get_value("properties", "owned", false))
    var legacy_inspected := bool(state_adapter.get_value("properties", "inspected", false))
    var by_id: Dictionary = {}
    if stored is Array:
        for entry in stored:
            if entry is Dictionary:
                by_id[str(entry.get("id", ""))] = entry.duplicate(true)
    var merged: Array = []
    for default_entry in PROPERTY_CATALOG:
        var item: Dictionary = default_entry.duplicate(true)
        var saved = by_id.get(str(item["id"]), {})
        if saved is Dictionary:
            for key in saved.keys():
                item[key] = saved[key]
        if not item.has("owned"):
            item["owned"] = false
        if not item.has("inspected"):
            item["inspected"] = false
        merged.append(item)
    if legacy_selected >= 0 and legacy_selected < merged.size():
        if legacy_owned and not _any_owned(merged):
            merged[legacy_selected]["owned"] = true
        if legacy_inspected and not _any_inspected(merged):
            merged[legacy_selected]["inspected"] = true
    state_adapter.set_value("properties", "catalog", merged)
    state_adapter.set_value("properties", "selected_property", clampi(legacy_selected, 0, maxi(0, merged.size() - 1)))
    _sync_legacy_fields()

func _any_owned(catalog: Array) -> bool:
    for property in catalog:
        if property is Dictionary and bool(property.get("owned", false)):
            return true
    return false

func _any_inspected(catalog: Array) -> bool:
    for property in catalog:
        if property is Dictionary and bool(property.get("inspected", false)):
            return true
    return false

func list_properties() -> Array:
    return state_adapter.get_value("properties", "catalog", PROPERTY_CATALOG).duplicate(true)

func list_property_types() -> Array:
    return PROPERTY_TYPES.duplicate()

func get_property(property_id: String) -> Dictionary:
    for property in list_properties():
        if str(property.get("id", "")) == property_id:
            return property.duplicate(true)
    return {}

func select_property(property_id: String) -> Dictionary:
    var catalog: Array = list_properties()
    for index in range(catalog.size()):
        if str(catalog[index].get("id", "")) == property_id:
            state_adapter.set_value("properties", "selected_property", index)
            _sync_legacy_fields()
            return {"ok": true, "property": catalog[index].duplicate(true)}
    return {"ok": false, "reason": "property_not_found"}

func get_selected_property() -> Dictionary:
    var catalog: Array = list_properties()
    if catalog.is_empty():
        return {}
    var index := clampi(int(state_adapter.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    return catalog[index].duplicate(true)

func acquisition_cost(property: Dictionary = {}) -> int:
    var item := property if not property.is_empty() else get_selected_property()
    if item.is_empty():
        return 0
    var market_value := maxi(0, int(item.get("value", 0)))
    var condition_ratio := clampf(float(item.get("condition", 50)) / 100.0, 0.0, 1.0)
    var rate := ACQUISITION_BASE_RATE + ACQUISITION_CONDITION_RATE * condition_ratio
    return maxi(ACQUISITION_MIN_COST, int(round(float(market_value) * rate)))

func restoration_step_cost(step: String, property: Dictionary = {}) -> int:
    if not STEP_COSTS.has(step):
        return 0
    var item := property if not property.is_empty() else get_selected_property()
    if item.is_empty():
        return int(STEP_COSTS[step])
    var market_value := maxi(1, int(item.get("value", 0)))
    var condition_ratio := clampf(float(item.get("condition", 50)) / 100.0, 0.0, 1.0)
    var value_factor := clampf(float(market_value) / RESTORATION_REFERENCE_VALUE, 1.0, 2.25)
    var condition_factor := clampf(1.18 - condition_ratio * 0.30, 0.95, 1.18)
    var type_factor := 1.0
    match str(item.get("type", "Warehouse")):
        "Workshop":
            type_factor = 1.08
        "Commercial Building":
            type_factor = 1.15
    return maxi(1, int(round(float(STEP_COSTS[step]) * value_factor * condition_factor * type_factor)))

func next_restoration_cost(property: Dictionary = {}) -> int:
    var item := property if not property.is_empty() else get_selected_property()
    if item.is_empty():
        return 0
    var step := _next_restoration_step(item)
    return restoration_step_cost(step, item) if not step.is_empty() else 0

func restoration_progress(property: Dictionary = {}) -> int:
    var item := property if not property.is_empty() else get_selected_property()
    if item.is_empty():
        return 0
    var total := 0
    for step in RESTORATION_STEPS:
        total += clampi(int(item.get(step, 0)), 0, 100)
    return int(round(float(total) / float(RESTORATION_STEPS.size())))

func owned_property_count() -> int:
    var total := 0
    for property in list_properties():
        if bool(property.get("owned", false)):
            total += 1
    return total

func restored_property_count() -> int:
    var total := 0
    for property in list_properties():
        if bool(property.get("owned", false)) and is_operational(property):
            total += 1
    return total

func restoration_portfolio_status() -> Dictionary:
    var catalog := list_properties()
    var inspected_count := 0
    var owned_count := 0
    var restored_count := 0
    var total_progress := 0
    for property in catalog:
        if bool(property.get("inspected", false)):
            inspected_count += 1
        if bool(property.get("owned", false)):
            owned_count += 1
        if bool(property.get("owned", false)) and is_operational(property):
            restored_count += 1
        var progress := 0
        for step in RESTORATION_STEPS:
            progress += int(property.get(step, 0))
        total_progress += int(round(float(progress) / float(RESTORATION_STEPS.size())))
    var average := 0 if catalog.is_empty() else int(round(float(total_progress) / float(catalog.size())))
    return {"total": catalog.size(), "inspected": inspected_count, "owned": owned_count, "restored": restored_count, "average_restoration": average}

func inspect_property() -> void:
    var catalog: Array = list_properties()
    if catalog.is_empty():
        return
    var index := clampi(int(state_adapter.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    var property: Dictionary = catalog[index]
    property["inspected"] = true
    catalog[index] = property
    state_adapter.set_value("properties", "catalog", catalog)
    _sync_legacy_fields()
    state_adapter.message("Inspection complete: %s is a %s with %d%% condition." % [property.get("name", "Property"), property.get("type", "Property"), int(property.get("condition", 0))])
    state_adapter.log_message("INSPECTION: %s — value $%d, capacity %d." % [property.get("name", "Property"), int(property.get("value", 0)), int(property.get("capacity", 0))])

func acquire_property() -> void:
    var catalog: Array = list_properties()
    if catalog.is_empty():
        return
    var index := clampi(int(state_adapter.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    var property: Dictionary = catalog[index]
    if not bool(property.get("inspected", false)):
        state_adapter.message("Inspect this property first.")
        return
    if bool(property.get("owned", false)):
        state_adapter.message("You already own %s." % property.get("name", "this property"))
        return
    var purchase_price := acquisition_cost(property)
    var spend: Dictionary = state_adapter.spend(purchase_price, "property acquisition")
    if not bool(spend.get("ok", false)):
        state_adapter.message(str(spend.get("message", "Not enough cash.")))
        return
    property["owned"] = true
    catalog[index] = property
    state_adapter.set_value("properties", "catalog", catalog)
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    _sync_legacy_fields()
    state_adapter.message("Acquired %s. Restore it into a productive asset." % property.get("name", "property"))
    state_adapter.log_message("ACQUIRED: %s for $%d. Portfolio: %d/%d owned." % [property.get("name", "property"), purchase_price, owned_property_count(), catalog.size()])

func restore_step(step: String, property_id: String = "") -> Dictionary:
    if not RESTORATION_STEPS.has(step):
        return {"ok": false, "reason": "invalid_restoration_step"}
    var catalog: Array = list_properties()
    var id := property_id if not property_id.is_empty() else str(get_selected_property().get("id", ""))
    var index := _index_for_id(catalog, id)
    if index < 0:
        return {"ok": false, "reason": "property_not_found"}
    var property: Dictionary = catalog[index]
    if not bool(property.get("owned", false)):
        return {"ok": false, "reason": "property_not_owned"}
    var required_step := _next_restoration_step(property)
    if required_step.is_empty():
        return {"ok": false, "reason": "restoration_complete", "property": property}
    if step != required_step:
        return {"ok": false, "reason": "step_locked", "required_step": required_step, "property": property}
    var progress := int(property.get(step, 0))
    if progress >= 100:
        return {"ok": false, "reason": "step_complete", "property": property}
    var cost := restoration_step_cost(step, property)
    var spend: Dictionary = state_adapter.spend(cost, "property restoration: %s" % step)
    if not bool(spend.get("ok", false)):
        return {"ok": false, "reason": "insufficient_cash", "cost": cost, "cash": int(state_adapter.get_value("economy", "cash", 0))}
    progress = mini(100, progress + int(STEP_GAIN[step]))
    property[step] = progress
    property["condition"] = mini(100, int(property.get("condition", 0)) + (5 if step == "repair" else 2))
    catalog[index] = property
    state_adapter.set_value("properties", "catalog", catalog)
    state_adapter.set_value("properties", "selected_property", index)
    _sync_legacy_fields()
    state_adapter.log_message("RESTORATION: %s — %s +%d%% (-$%d)." % [property.get("name", id), step.capitalize(), int(STEP_GAIN[step]), cost])
    if is_operational(property):
        state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 8)
        state_adapter.message("RESTORATION COMPLETE: %s is productive capital. Portfolio restored: %d/%d." % [property.get("name", "Property"), restored_property_count(), catalog.size()])
    else:
        state_adapter.message("%s %d%% complete: %s is visibly changing." % [step.capitalize(), progress, property.get("name", "the property")])
    var reputation = _service("RenewReputationSystem")
    if step == "cleaning" and reputation != null and reputation.has_method("adjust"):
        reputation.adjust("environmental", 2)
    return {"ok": true, "property": property.duplicate(true), "step": step, "cost": cost}

func restore_property() -> void:
    var property := get_selected_property()
    if property.is_empty():
        return
    if not bool(property.get("owned", false)):
        state_adapter.message("Acquire this property first.")
        return
    if int(property.get("lease_until", 0)) > int(state_adapter.get_value("player", "day", 1)):
        state_adapter.message("Tenants occupy the property until day %d." % int(property.get("lease_until", 0)))
        return
    var step := _next_restoration_step(property)
    if step.is_empty():
        state_adapter.message("%s is fully restored and Operational." % property.get("name", "Property"))
        return
    restore_step(step)

func is_operational(property: Dictionary) -> bool:
    for step in RESTORATION_STEPS:
        if int(property.get(step, 0)) < 100:
            return false
    return true

func _next_restoration_step(property: Dictionary) -> String:
    for step in RESTORATION_STEPS:
        if int(property.get(step, 0)) < 100:
            return step
    return ""

func _visual_stage(property: Dictionary, owned: bool) -> String:
    if not owned:
        return "Neglected"
    if int(property.get("cleaning", 0)) < 100:
        return "Neglected"
    if int(property.get("repair", 0)) < 100:
        return "Cleaned"
    if int(property.get("painting", 0)) < 100:
        return "Repaired"
    if int(property.get("furnishing", 0)) < 50:
        return "Painted"
    if int(property.get("furnishing", 0)) < 100:
        return "Furnished"
    return "Operational"

func _index_for_id(catalog: Array, property_id: String) -> int:
    for index in range(catalog.size()):
        if str(catalog[index].get("id", "")) == property_id:
            return index
    return -1

func _sync_legacy_fields() -> void:
    var catalog: Array = state_adapter.get_value("properties", "catalog", PROPERTY_CATALOG)
    if catalog.is_empty():
        return
    var index := clampi(int(state_adapter.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    var property: Dictionary = catalog[index]
    var average := 0
    for step in RESTORATION_STEPS:
        average += int(property.get(step, 0))
    average = int(round(float(average) / float(RESTORATION_STEPS.size())))
    var owned := bool(property.get("owned", false))
    var operational := is_operational(property)
    state_adapter.set_value("properties", "owned", owned)
    state_adapter.set_value("properties", "inspected", bool(property.get("inspected", false)))
    state_adapter.set_value("properties", "cleaning", int(property.get("cleaning", 0)))
    state_adapter.set_value("properties", "repair", int(property.get("repair", 0)))
    state_adapter.set_value("properties", "painting", int(property.get("painting", 0)))
    state_adapter.set_value("properties", "furnishing", int(property.get("furnishing", 0)))
    state_adapter.set_value("properties", "restoration", average)
    state_adapter.set_value("properties", "stage", _visual_stage(property, owned) if not operational else "Operational")

func sale_value(property: Dictionary) -> int:
    # "value" is the restored market value, not a free arbitrage price for an
    # untouched distressed asset. A neglected resale carries a transaction loss;
    # restoration progressively converts that distressed basis into market value.
    var market_value := maxi(1000, int(property.get("value", 0)))
    var basis := acquisition_cost(property)
    var progress_ratio := clampf(float(restoration_progress(property)) / 100.0, 0.0, 1.0)
    var value_realization := progress_ratio * progress_ratio
    var distressed_resale := float(basis) * 0.90
    return maxi(1000, int(round(lerpf(distressed_resale, float(market_value), value_realization))))

func lease_terms(property: Dictionary) -> Dictionary:
    var rent := maxi(500, int(round(float(sale_value(property)) * 0.05)))
    return {"rent": rent, "days": 7}

func sell_property() -> void:
    var catalog: Array = list_properties()
    if catalog.is_empty():
        return
    var index := clampi(int(state_adapter.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    var property: Dictionary = catalog[index]
    if not bool(property.get("owned", false)):
        state_adapter.message("You do not own this property.")
        return
    var active_origin := str(state_adapter.get_value("businesses", "origin_property_id", ""))
    if bool(state_adapter.get_value("businesses", "business_open", false)) and active_origin == str(property.get("id", "")):
        state_adapter.message("Close the operating business before selling its home.")
        return
    if int(property.get("lease_until", 0)) > int(state_adapter.get_value("player", "day", 1)):
        state_adapter.message("The lease runs until day %d; selling must wait." % int(property.get("lease_until", 0)))
        return
    var price := sale_value(property)
    var proceeds: Dictionary = state_adapter.receive(price, "property sale: %s" % str(property.get("name", "property")))
    if not bool(proceeds.get("ok", false)):
        state_adapter.message(str(proceeds.get("message", "Sale could not complete.")))
        return
    property["owned"] = false
    property["inspected"] = true
    catalog[index] = property
    state_adapter.set_value("properties", "catalog", catalog)
    _sync_legacy_fields()
    state_adapter.message("Sold %s for $%s. Portfolio: %d properties remain." % [str(property.get("name", "property")), state_adapter.money(price), owned_property_count()])
    state_adapter.log_message("SOLD: %s for $%s." % [str(property.get("name", "property")), state_adapter.money(price)])

func lease_property() -> void:
    var catalog: Array = list_properties()
    if catalog.is_empty():
        return
    var index := clampi(int(state_adapter.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    var property: Dictionary = catalog[index]
    if not bool(property.get("owned", false)):
        state_adapter.message("You do not own this property.")
        return
    var active_origin := str(state_adapter.get_value("businesses", "origin_property_id", ""))
    if bool(state_adapter.get_value("businesses", "business_open", false)) and active_origin == str(property.get("id", "")):
        state_adapter.message("An active operating business occupies this property.")
        return
    var day := int(state_adapter.get_value("player", "day", 1))
    if int(property.get("lease_until", 0)) > day:
        state_adapter.message("Already leased until day %d." % int(property.get("lease_until", 0)))
        return
    var terms := lease_terms(property)
    var rent: Dictionary = state_adapter.receive(int(terms["rent"]), "property lease: %s" % str(property.get("name", "property")))
    if not bool(rent.get("ok", false)):
        state_adapter.message(str(rent.get("message", "Lease could not complete.")))
        return
    property["lease_until"] = day + int(terms["days"])
    catalog[index] = property
    state_adapter.set_value("properties", "catalog", catalog)
    _sync_legacy_fields()
    state_adapter.message("Leased %s for %d days (+$%s upfront)." % [str(property.get("name", "property")), int(terms["days"]), state_adapter.money(int(terms["rent"]))])
    state_adapter.log_message("LEASED: %s until day %d (+$%s)." % [str(property.get("name", "property")), day + int(terms["days"]), state_adapter.money(int(terms["rent"]))])
