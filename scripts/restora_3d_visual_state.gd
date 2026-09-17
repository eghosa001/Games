class_name Restora3DVisualState
extends RefCounted

static func stage_from_values(owned: bool, stage: String, cleaning: int, repair: int, painting: int, furnishing: int) -> String:
    if not owned:
        return "neglected"
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
    if furnishing >= 100:
        return "operational"
    if furnishing > 0:
        return "furnished"
    if painting >= 100:
        return "painted"
    if repair >= 100:
        return "repaired"
    if cleaning >= 100:
        return "cleaned"
    return "neglected"

static func archetype_from_property(property: Dictionary) -> String:
    var kind := str(property.get("type", property.get("kind", property.get("category", "warehouse")))).to_lower()
    if kind.contains("factory") or kind.contains("industrial") or kind.contains("manufactur"):
        return "factory"
    if kind.contains("office") or kind.contains("headquarter") or kind == "hq":
        return "office"
    if kind.contains("retail") or kind.contains("shop") or kind.contains("store"):
        return "retail"
    if kind.contains("resource") or kind.contains("mine") or kind.contains("farm") or kind.contains("fuel"):
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
    return snapshot_from_values(
        property,
        bool(state.get_value("properties", "owned", false)),
        str(state.get_value("properties", "stage", "Neglected")),
        int(property.get("cleaning", state.get_value("properties", "cleaning", 0))),
        int(property.get("repair", state.get_value("properties", "repair", 0))),
        int(property.get("painting", state.get_value("properties", "painting", 0))),
        int(property.get("furnishing", state.get_value("properties", "furnishing", 0))),
        bool(state.get_value("businesses", "business_open", false)),
        selected
    )
