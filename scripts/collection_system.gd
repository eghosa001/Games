extends Node
class_name RenewCollectionSystem

## Corporate collections are permanent, gameplay-relevant assets rather than badges.
const TYPES := ["historic_properties", "rare_machinery", "landmark_businesses", "unique_technologies", "special_contracts", "famous_employees", "world_event_artifacts"]
const MAX_ITEMS := 300

var collections: Dictionary = {}
var seen: Dictionary = {}
var active_bonuses: Dictionary = {}
var events: Array[Dictionary] = []
var last_day: Variant = -1

const TYPE_BONUSES := {
    "historic_properties": {"reputation": 2, "property_income": 0.04, "regional_presence": 1},
    "rare_machinery": {"production": 0.06, "maintenance": -0.03, "technology": 1},
    "landmark_businesses": {"revenue": 0.05, "reputation": 3, "market_share": 1},
    "unique_technologies": {"technology": 3, "research": 0.08, "production": 0.03},
    "special_contracts": {"contract_income": 0.06, "reputation": 2, "trust": 2},
    "famous_employees": {"training": 0.08, "reputation": 3, "productivity": 0.04},
    "world_event_artifacts": {"reputation": 4, "resilience": 0.06, "world_power": 1}
}

func _ready() -> void:
    for type in TYPES:
        collections[type] = []
    _recalculate_bonuses()

func _process(_delta: float) -> void:
    var day: Variant = _day()
    if day != last_day:
        last_day = day
        _scan_sources(day)
        _recalculate_bonuses()

func collect(type: String, title: String, details: Dictionary = {}, reward: Dictionary = {}, day: int = -1, signature: String = "") -> Dictionary:
    if not TYPES.has(type): return {"ok": false, "reason": "Unknown collection type."}
    var actual_day: Variant = _day() if day < 0 else day
    var key: Variant = signature if not signature.is_empty() else "%s|%s" % [type, title]
    if seen.has(key): return {"ok": true, "item": seen[key], "already_collected": true}
    var item: Variant = {"id": "collection_%06d" % (_total_count() + 1), "type": type, "title": title, "day": actual_day, "details": details.duplicate(true), "reward": reward.duplicate(true)}
    collections[type].append(item)
    if collections[type].size() > MAX_ITEMS: collections[type].pop_front()
    seen[key] = item
    events.append({"day": actual_day, "type": "collection_acquired", "title": title, "collection_type": type})
    _recalculate_bonuses()
    return {"ok": true, "item": item, "already_collected": false}

func list_collection(type: String) -> Array:
    return collections.get(type, []).duplicate(true)

func get_all() -> Array:
    var result: Array = []
    for type in TYPES:
        for item in collections.get(type, []): result.append(item.duplicate(true))
    result.sort_custom(func(a, b): return int(a.get("day", 0)) < int(b.get("day", 0)))
    return result

func get_bonuses() -> Dictionary:
    return active_bonuses.duplicate(true)

func get_collection_value() -> int:
    var value: Variant = 0
    for item in get_all():
        var reward: Dictionary = item.get("reward", {})
        value += int(reward.get("value", 1000))
    return value

func get_status() -> Dictionary:
    var counts: Variant = {}
    for type in TYPES: counts[type] = collections[type].size()
    return {"total": _total_count(), "counts": counts, "value": get_collection_value(), "bonuses": active_bonuses.duplicate(true)}

func _scan_sources(day: int) -> void:
    var legacy = get_node_or_null("/root/RenewCorporateLegacy")
    if legacy != null:
        for item in legacy.list_category("founding"):
            var title: Variant = str(item.get("title", "Historic property"))
            collect("historic_properties", title, item.get("details", {}), {"value": 25000, "reputation": 2}, int(item.get("day", day)), "legacy_property|" + str(item.get("id", title)))
        for item in legacy.list_category("technologies"):
            var title: Variant = str(item.get("title", "Unique technology"))
            collect("unique_technologies", title, item.get("details", {}), {"value": 30000, "technology": 3}, int(item.get("day", day)), "legacy_technology|" + str(item.get("id", title)))
        for item in legacy.list_category("employees"):
            var details: Dictionary = item.get("details", {})
            if int(details.get("career_level", 0)) >= 4 or str(item.get("title", "")).to_lower().contains("executive"):
                collect("famous_employees", str(item.get("title", "Historic executive")), details, {"value": 20000, "reputation": 3}, int(item.get("day", day)), "legacy_employee|" + str(item.get("id", item.get("title", ""))))
        for item in legacy.list_category("contracts"):
            collect("special_contracts", str(item.get("title", "Historic contract")), item.get("details", {}), {"value": 18000, "reputation": 2}, int(item.get("day", day)), "legacy_contract|" + str(item.get("id", item.get("title", ""))))
        for item in legacy.list_category("acquisitions"):
            collect("landmark_businesses", str(item.get("title", "Landmark business")), item.get("details", {}), {"value": 40000, "reputation": 3}, int(item.get("day", day)), "legacy_business|" + str(item.get("id", item.get("title", ""))))
        for item in legacy.list_category("crisis_recoveries"):
            collect("world_event_artifacts", str(item.get("title", "World-event artifact")), item.get("details", {}), {"value": 35000, "reputation": 4}, int(item.get("day", day)), "legacy_event|" + str(item.get("id", item.get("title", ""))))

    var infrastructure = get_node_or_null("/root/RenewInfrastructureSystem")
    if infrastructure != null:
        for asset in infrastructure.list_assets():
            var type: Variant = str(asset.get("type", ""))
            if type in ["industrial_zone", "technology_park", "power_plant"] and int(asset.get("level", 1)) >= 3:
                collect("rare_machinery", "Rare machinery — %s" % asset.get("name", asset.get("id", "Machine")), {"asset_id":asset.get("id", ""), "region":asset.get("region", "")}, {"value":50000, "production":0.06}, day, "machinery|" + str(asset.get("id", "")))

    var world_events = get_node_or_null("/root/RenewWorldEventSystem")
    if world_events != null:
        for event in world_events.history_list():
            var category: Variant = str(event.get("category", ""))
            if category in ["energy", "supply", "financial"]:
                collect("world_event_artifacts", "World event artifact — %s" % event.get("title", event.get("id", "Event")), {"event_id":event.get("id", ""), "category":category}, {"value":35000, "resilience":0.06}, int(event.get("day", day)), "world_event|" + str(event.get("id", "")))

func _recalculate_bonuses() -> void:
    active_bonuses.clear()
    for type in TYPES:
        var count: Variant = collections[type].size()
        if count <= 0: continue
        var spec: Dictionary = TYPE_BONUSES[type]
        for key in spec.keys():
            var amount = spec[key]
            if key == "reputation" or key == "technology" or key == "regional_presence" or key == "market_share" or key == "trust" or key == "world_power":
                active_bonuses[key] = int(active_bonuses.get(key, 0)) + int(amount) * count
            else:
                active_bonuses[key] = float(active_bonuses.get(key, 0.0)) + float(amount) * count

func capture_state() -> Dictionary:
    return {"collections": collections.duplicate(true), "seen": seen.duplicate(true), "active_bonuses": active_bonuses.duplicate(true), "events": events.duplicate(true), "last_day": last_day}

func restore_state(state: Dictionary) -> void:
    for type in TYPES: collections[type] = []
    var saved = state.get("collections", {})
    if saved is Dictionary:
        for type in TYPES:
            if saved.get(type, []) is Array: collections[type] = saved[type].duplicate(true)
    seen = state.get("seen", {}).duplicate(true)
    active_bonuses = state.get("active_bonuses", {}).duplicate(true)
    events = state.get("events", []).duplicate(true)
    last_day = int(state.get("last_day", -1))

func _total_count() -> int:
    var total: Variant = 0
    for type in TYPES: total += collections[type].size()
    return total

func _day() -> int:
    var scene: Variant = get_tree().current_scene if get_tree() != null else null
    return int(scene.get("day")) if scene != null else 1
