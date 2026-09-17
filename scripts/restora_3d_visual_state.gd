extends RefCounted
class_name Restora3DVisualState

static func stage_from_values(owned: bool, stage: String, cleaning: int, repair: int, painting: int, furnishing: int) -> String:
    if not owned:
        return "neglected"
    if furnishing >= 100:
        return "operational"
    if furnishing >= 50:
        return "furnished"
    if painting >= 100:
        return "painted"
    if repair >= 100:
        return "repaired"
    if cleaning >= 100:
        return "cleaned"
    var normalized := stage.strip_edges().to_lower()
    if normalized in ["operational", "open"]:
        return "operational"
    if normalized == "furnished":
        return "furnished"
    if normalized == "painted":
        return "painted"
    if normalized == "repaired":
        return "repaired"
    if normalized in ["cleaned", "clean"]:
        return "cleaned"
    return "neglected"

static func archetype_from_property(property: Dictionary) -> String:
    var kind := str(property.get("type", property.get("kind", property.get("category", "warehouse")))).to_lower()
    var name := str(property.get("name", "")).to_lower()
    var descriptor := "%s %s" % [kind, name]
    if descriptor.contains("factory") or descriptor.contains("industrial") or descriptor.contains("manufactur") or descriptor.contains("workshop"):
        return "factory"
    if descriptor.contains("office") or descriptor.contains("headquarter") or kind == "hq":
        return "office"
    if kind.contains("commercial"):
        return "retail"
    if descriptor.contains("retail") or descriptor.contains("shop") or descriptor.contains("store") or descriptor.contains("market"):
        return "retail"
    if descriptor.contains("resource") or descriptor.contains("mine") or descriptor.contains("farm") or descriptor.contains("fuel"):
        return "resource"
    return "warehouse"

static func snapshot_from_values(property: Dictionary, owned: bool, stage: String, cleaning: int, repair: int, painting: int, furnishing: int, business_open: bool, selected_property: int) -> Dictionary:
    return {
        "selected_property": selected_property,
        "owned": owned,
        "archetype": archetype_from_property(property),
        "stage": stage_from_values(owned, stage, cleaning, repair, painting, furnishing),
        "business_open": business_open,
        "property_name": str(property.get("name", "Restora Property")),
    }

static func snapshot_from_game_state(state: Node) -> Dictionary:
    if state == null or not state.has_method("get_value"):
        return snapshot_from_values({}, false, "Neglected", 0, 0, 0, 0, false, 0)

    var catalog = state.get_value("properties", "catalog", [])
    var selected := maxi(0, int(state.get_value("properties", "selected_property", 0)))
    var property: Dictionary = {}
    if catalog is Array and not catalog.is_empty():
        selected = mini(selected, catalog.size() - 1)
        var value = catalog[selected]
        if value is Dictionary:
            property = value

    var has_selected_property := not property.is_empty()
    var owned := bool(property.get("owned", false)) if has_selected_property else bool(state.get_value("properties", "owned", false))
    var stage := str(property.get("stage", "Neglected")) if has_selected_property else str(state.get_value("properties", "stage", "Neglected"))
    var cleaning := int(property.get("cleaning", 0)) if has_selected_property else int(state.get_value("properties", "cleaning", 0))
    var repair := int(property.get("repair", 0)) if has_selected_property else int(state.get_value("properties", "repair", 0))
    var painting := int(property.get("painting", 0)) if has_selected_property else int(state.get_value("properties", "painting", 0))
    var furnishing := int(property.get("furnishing", 0)) if has_selected_property else int(state.get_value("properties", "furnishing", 0))

    var business_open := false
    if has_selected_property and bool(state.get_value("businesses", "business_open", false)):
        var origin_property_id := str(state.get_value("businesses", "origin_property_id", ""))
        var selected_property_id := str(property.get("id", ""))
        business_open = owned and selected_property_id != "" and selected_property_id == origin_property_id

    return snapshot_from_values(
        property,
        owned,
        stage,
        cleaning,
        repair,
        painting,
        furnishing,
        business_open,
        selected
    )
