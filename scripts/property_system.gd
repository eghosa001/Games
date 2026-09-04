extends Node
class_name RenewPropertySystem

## Phase 18: restoration is the emotional entry point; business is progression.
## Property facts live only in GameState.properties. This node owns behavior.

const DomainSystem = preload("res://scripts/domain_system.gd")
const PROPERTY_TYPES := ["Warehouse", "Workshop", "Commercial Building"]
const RESTORATION_STEPS := ["cleaning", "repair", "painting", "furnishing"]
const STEP_COSTS := {"cleaning": 500, "repair": 1500, "painting": 900, "furnishing": 1200}
const STEP_GAIN := {"cleaning": 100, "repair": 100, "painting": 100, "furnishing": 100}

const PROPERTY_CATALOG := [
    {"id":"warehouse_001","name":"Riverside Warehouse","type":"Warehouse","condition":35,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":65000,"capacity":80,"industry_compatibility":["Logistics","Manufacturing","Wholesale"]},
    {"id":"warehouse_002","name":"Old Market Warehouse","type":"Warehouse","condition":45,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":78000,"capacity":100,"industry_compatibility":["Logistics","Manufacturing","Retail"]},
    {"id":"warehouse_003","name":"Harbor Storage","type":"Warehouse","condition":55,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":95000,"capacity":130,"industry_compatibility":["Logistics","Wholesale","Manufacturing"]},
    {"id":"workshop_001","name":"Foundry Workshop","type":"Workshop","condition":30,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":72000,"capacity":35,"industry_compatibility":["Manufacturing","Metalwork","Furniture"]},
    {"id":"workshop_002","name":"Timber Workshop","type":"Workshop","condition":40,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":68000,"capacity":30,"industry_compatibility":["Furniture","Manufacturing","Construction"]},
    {"id":"workshop_003","name":"Industrial Workshop","type":"Workshop","condition":50,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":88000,"capacity":45,"industry_compatibility":["Manufacturing","Engineering","Furniture"]},
    {"id":"commercial_001","name":"Main Street Building","type":"Commercial Building","condition":38,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":110000,"capacity":18,"industry_compatibility":["Retail","Services","Wholesale"]},
    {"id":"commercial_002","name":"Market Square Building","type":"Commercial Building","condition":48,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":135000,"capacity":24,"industry_compatibility":["Retail","Services","Hospitality"]},
    {"id":"commercial_003","name":"Riverside Offices","type":"Commercial Building","condition":60,"cleaning":0,"repair":0,"painting":0,"furnishing":0,"value":160000,"capacity":32,"industry_compatibility":["Services","Finance","Retail"]}
]

var state_adapter: Variant = DomainSystem.new()

func _ready() -> void:
    add_child(state_adapter)
    _ensure_catalog()

func _ensure_catalog() -> void:
    var stored = state_adapter.get_value("properties", "catalog", [])
    if not stored is Array or stored.size() != PROPERTY_CATALOG.size():
        state_adapter.set_value("properties", "catalog", PROPERTY_CATALOG.duplicate(true))
    _sync_legacy_fields()

func list_properties() -> Array:
    return state_adapter.get_value("properties", "catalog", PROPERTY_CATALOG).duplicate(true)
func list_property_types() -> Array: return PROPERTY_TYPES.duplicate()
func get_property(property_id: String) -> Dictionary:
    for property in list_properties():
        if str(property.get("id", "")) == property_id: return property.duplicate(true)
    return {}
func select_property(property_id: String) -> Dictionary:
    var catalog: Variant = list_properties()
    for index in catalog.size():
        if str(catalog[index].get("id", "")) == property_id:
            state_adapter.set_value("properties", "selected_property", index); _sync_legacy_fields()
            return {"ok":true,"property":catalog[index].duplicate(true)}
    return {"ok":false,"reason":"property_not_found"}
func get_selected_property() -> Dictionary:
    var catalog: Variant = list_properties()
    if catalog.is_empty(): return {}
    var index: Variant = clampi(int(state_adapter.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    return catalog[index].duplicate(true)
func inspect_property() -> void:
    var property: Variant = get_selected_property()
    if property.is_empty(): return
    state_adapter.set_value("properties", "inspected", true)
    state_adapter.message("Inspection complete: %s is a %s with %d%% condition." % [property.get("name", "Property"), property.get("type", "Property"), int(property.get("condition", 0))])
    state_adapter.log_message("INSPECTION: %s — value $%d, capacity %d." % [property.get("name", "Property"), int(property.get("value", 0)), int(property.get("capacity", 0))])
func acquire_property() -> void:
    if not bool(state_adapter.get_value("properties", "inspected", false)): state_adapter.message("Inspect the property first."); return
    if bool(state_adapter.get_value("properties", "owned", false)): state_adapter.message("You already own a property."); return
    var property: Variant = get_selected_property(); var purchase_price := 5000
    var spend:=state_adapter.spend(purchase_price,"property acquisition")
    if not bool(spend.get("ok",false)): state_adapter.message(str(spend.get("message","Not enough cash."))); return
    state_adapter.set_value("properties", "owned", true)
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    _sync_legacy_fields(); state_adapter.message("Acquired %s. Now restore it into an asset." % property.get("name", "property")); state_adapter.log_message("ACQUIRED: %s for $%d." % [property.get("name", "property"), purchase_price])
func restore_step(step: String, property_id: String = "") -> Dictionary:
    if not RESTORATION_STEPS.has(step): return {"ok":false,"reason":"invalid_restoration_step"}
    if not bool(state_adapter.get_value("properties", "owned", false)): return {"ok":false,"reason":"property_not_owned"}
    var id: Variant = property_id if not property_id.is_empty() else str(get_selected_property().get("id", "")); var catalog: Variant = list_properties(); var index: Variant = _index_for_id(catalog, id)
    if index < 0: return {"ok":false,"reason":"property_not_found"}
    var property: Dictionary = catalog[index]; var required_step: Variant = _next_restoration_step(property)
    if required_step.is_empty(): return {"ok":false,"reason":"restoration_complete","property":property}
    if step != required_step: return {"ok":false,"reason":"step_locked","required_step":required_step,"property":property}
    var progress: Variant = int(property.get(step, 0)); if progress >= 100: return {"ok":false,"reason":"step_complete","property":property}
    var cost: Variant = int(STEP_COSTS[step]); var spend:=state_adapter.spend(cost,"property restoration: %s" % step)
    if not bool(spend.get("ok",false)): return {"ok":false,"reason":"insufficient_cash","cost":cost,"cash":int(state_adapter.get_value("economy","cash",0))}
    progress = mini(100, progress + int(STEP_GAIN[step])); property[step] = progress; property["condition"] = mini(100, int(property.get("condition", 0)) + (5 if step == "repair" else 2)); catalog[index] = property
    state_adapter.set_value("properties", "catalog", catalog); state_adapter.set_value("properties", "selected_property", index); _sync_legacy_fields()
    state_adapter.log_message("RESTORATION: %s — %s +%d%% (-$%d)." % [property.get("name", id), step.capitalize(), int(STEP_GAIN[step]), cost])
    if is_operational(property):
        state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 8); state_adapter.message("RESTORATION COMPLETE. Your neglected property is now productive capital.")
    else: state_adapter.message("%s %d%% complete: the property is visibly changing." % [step.capitalize(), progress])
    return {"ok":true,"property":property.duplicate(true),"step":step,"cost":cost}
func restore_property() -> void:
    if not bool(state_adapter.get_value("properties", "owned", false)): state_adapter.message("Acquire the property first."); return
    var property: Variant = get_selected_property(); var step: Variant = _next_restoration_step(property)
    if step.is_empty(): state_adapter.message("Restoration is complete. The property is Operational."); return
    restore_step(step)
func is_operational(property: Dictionary) -> bool:
    for step in RESTORATION_STEPS:
        if int(property.get(step, 0)) < 100: return false
    return true
func _next_restoration_step(property: Dictionary) -> String:
    for step in RESTORATION_STEPS:
        if int(property.get(step, 0)) < 100: return step
    return ""
func _visual_stage(property: Dictionary, owned: bool) -> String:
    if not owned: return "Neglected"
    if int(property.get("cleaning", 0)) < 100: return "Neglected"
    if int(property.get("repair", 0)) < 100: return "Cleaned"
    if int(property.get("painting", 0)) < 100: return "Repaired"
    if int(property.get("furnishing", 0)) < 50: return "Painted"
    if int(property.get("furnishing", 0)) < 100: return "Furnished"
    return "Operational"
func _index_for_id(catalog: Array, property_id: String) -> int:
    for index in catalog.size():
        if str(catalog[index].get("id", "")) == property_id: return index
    return -1
func _sync_legacy_fields() -> void:
    var property: Variant = get_selected_property()
    if property.is_empty(): return
    var average: Variant = 0
    for step in RESTORATION_STEPS: average += int(property.get(step, 0))
    average = int(round(float(average) / float(RESTORATION_STEPS.size())))
    var owned: Variant = bool(state_adapter.get_value("properties", "owned", false)); var operational: Variant = is_operational(property)
    state_adapter.set_value("properties", "restoration", average); state_adapter.set_value("properties", "stage", _visual_stage(property, owned) if not operational else "Operational")
