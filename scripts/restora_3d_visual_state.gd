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

static func _activity_context(state: Node, business_open: bool) -> Dictionary:
    if state == null or not state.has_method("get_value"):
        return {
            "day": 1,
            "reputation": 0,
            "finished_goods": 0,
            "last_sales": 0,
            "total_profit": 0,
            "capacity_level": 1,
            "marketing_level": 0,
            "employee_count": 0,
            "activity_tier": 0,
            "traffic_level": 0,
            "worker_visual_count": 0,
            "is_profitable": false,
            "prosperity_tier": 0,
            "economy_phase": "expansion",
            "active_event_count": 0,
            "active_event_category": "",
            "rival_name": "",
            "rival_market_share": 0.0,
            "rival_presence": 0,
        }

    var roster: Variant = state.get_value("employees", "roster", [])
    var employees: int = (roster as Array).size() if roster is Array else 0
    var finished_goods := maxi(0, int(state.get_value("production", "finished_goods", 0)))
    var last_sales := maxi(0, int(state.get_value("economy", "last_sales", 0)))
    var total_profit := int(state.get_value("economy", "total_profit", 0))
    var capacity := maxi(1, int(state.get_value("businesses", "capacity_level", 1)))
    var marketing := maxi(0, int(state.get_value("businesses", "marketing_level", 0)))
    var reputation := maxi(0, int(state.get_value("player", "reputation", 0)))
    var seasonal: Variant = state.get_value("events", "seasonal", {})
    var economy_phase := "expansion"
    if seasonal is Dictionary and (seasonal as Dictionary).get("economy_cycle") is Dictionary:
        economy_phase = str(((seasonal as Dictionary)["economy_cycle"] as Dictionary).get("phase", "expansion"))

    var active_events: Variant = state.get_value("events", "active", {})
    var active_event_count := 0
    var active_event_category := ""
    if active_events is Dictionary:
        active_event_count = (active_events as Dictionary).size()
        for value in (active_events as Dictionary).values():
            if value is Dictionary:
                active_event_category = str((value as Dictionary).get("category", ""))
                break

    var rival_name := ""
    var rival_market_share := 0.0
    var rival_presence := 0
    var rivals: Variant = state.get_value("competitors", "rivals", [])
    if rivals is Array and not (rivals as Array).is_empty():
        var selected_rival := clampi(int(state.get_value("competitors", "selected_rival", 0)), 0, (rivals as Array).size() - 1)
        var rival: Variant = (rivals as Array)[selected_rival]
        if rival is Dictionary and not bool((rival as Dictionary).get("eliminated", false)):
            rival_name = str((rival as Dictionary).get("name", ""))
            rival_market_share = clampf(float((rival as Dictionary).get("market_share", 0.0)), 0.0, 1.0)
            rival_presence = maxi(0, int((rival as Dictionary).get("presence", 0)))

    var activity_score: int = 0
    if business_open:
        activity_score += 2
    if finished_goods > 0:
        activity_score += 1
    if last_sales > 0:
        activity_score += 1
    if capacity >= 2:
        activity_score += 1
    if marketing >= 1:
        activity_score += 1
    if employees >= 4:
        activity_score += 1
    if total_profit > 0:
        activity_score += 1

    var activity_tier: int = 0
    if business_open:
        activity_tier = 1
        if activity_score >= 4:
            activity_tier = 2
        if activity_score >= 7:
            activity_tier = 3
    var traffic_level: int = clampi(activity_tier + (1 if marketing >= 2 or last_sales >= 5 else 0), 0, 3)
    var worker_visual_count: int = 0 if not business_open else clampi(maxi(2, employees), 2, 6)
    var prosperity_score := 0
    if total_profit > 0:
        prosperity_score += 1
    if total_profit >= 25000:
        prosperity_score += 1
    if reputation >= 50:
        prosperity_score += 1
    if capacity >= 3:
        prosperity_score += 1
    var prosperity_tier := clampi(prosperity_score, 0, 3)

    return {
        "day": maxi(1, int(state.get_value("player", "day", 1))),
        "reputation": reputation,
        "finished_goods": finished_goods,
        "last_sales": last_sales,
        "total_profit": total_profit,
        "capacity_level": capacity,
        "marketing_level": marketing,
        "employee_count": employees,
        "activity_tier": activity_tier,
        "traffic_level": traffic_level,
        "worker_visual_count": worker_visual_count,
        "is_profitable": total_profit > 0,
        "prosperity_tier": prosperity_tier,
        "economy_phase": economy_phase,
        "active_event_count": active_event_count,
        "active_event_category": active_event_category,
        "rival_name": rival_name,
        "rival_market_share": rival_market_share,
        "rival_presence": rival_presence,
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

    var snapshot := snapshot_from_values(
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
    snapshot.merge(_activity_context(state, business_open), true)
    return snapshot
