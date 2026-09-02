extends Node
class_name RenewGameState

# Canonical persistent state for the RENEW simulation.
# Runtime systems may cache derived values, but persistent truth belongs here.
const STATE_VERSION := 3

var data: Dictionary = {}
var dirty := false

func new_game() -> Dictionary:
    data = {
        "schema_version": STATE_VERSION,
        "state_version": STATE_VERSION,
        "meta": {"created_at": Time.get_datetime_string_from_system(true), "last_saved_at": ""},
        "clock": {"day": 1},
        "player": {"cash": 25000, "reputation": 0},
        "company": {"id": "renew_goods", "name": "RENEW Goods", "founded_day": 1},
        "properties": {},
        "businesses": {},
        "branches": {},
        "employees": {"next_id": 1, "records": {}},
        "economy": {},
        "resources": {},
        "production": {},
        "supply_chain": {},
        "contracts": {},
        "competitors": {},
        "ownership": {},
        "finance": {},
        "alliances": {},
        "diplomacy": {},
        "regions": {},
        "infrastructure": {},
        "technology": {},
        "events": {},
        "progression": {},
        "history": [],
        "news": {"editions": []},
        "analytics": {}
    }
    dirty = true
    return data.duplicate(true)

func capture(core: Dictionary) -> Dictionary:
    var snapshot := data.duplicate(true) if not data.is_empty() else new_game()
    _merge_legacy_core(snapshot, core)
    snapshot["schema_version"] = STATE_VERSION
    snapshot["state_version"] = STATE_VERSION
    snapshot["meta"]["last_saved_at"] = Time.get_datetime_string_from_system(true)
    data = snapshot
    dirty = false
    return data.duplicate(true)

func restore(snapshot: Dictionary) -> Dictionary:
    var migrated := _migrate(snapshot)
    if migrated.is_empty():
        return {}
    data = migrated
    dirty = false
    return data.duplicate(true)

func mark_dirty() -> void:
    dirty = true

func has_state() -> bool:
    return not data.is_empty()

func get_value(path: Array, fallback = null):
    var cursor = data
    for key in path:
        if not (cursor is Dictionary) or not cursor.has(key):
            return fallback
        cursor = cursor[key]
    return cursor

func set_value(path: Array, value) -> void:
    if path.is_empty():
        return
    if data.is_empty():
        new_game()
    var cursor: Dictionary = data
    for i in range(path.size() - 1):
        var key = path[i]
        if not cursor.has(key) or not (cursor[key] is Dictionary):
            cursor[key] = {}
        cursor = cursor[key]
    cursor[path[path.size() - 1]] = value
    dirty = true

func clear() -> void:
    data.clear()
    dirty = false

func _merge_legacy_core(snapshot: Dictionary, core: Dictionary) -> void:
    for key in core.keys():
        snapshot[key] = core[key]
    if not snapshot.has("clock") or not (snapshot["clock"] is Dictionary):
        snapshot["clock"] = {}
    if not snapshot.has("player") or not (snapshot["player"] is Dictionary):
        snapshot["player"] = {}
    snapshot["clock"]["day"] = int(core.get("day", snapshot["clock"].get("day", 1)))
    snapshot["player"]["cash"] = int(core.get("cash", snapshot["player"].get("cash", 0)))
    snapshot["player"]["reputation"] = int(core.get("reputation", snapshot["player"].get("reputation", 0)))
    snapshot["finance"] = {
        "debt": int(core.get("debt", 0)),
        "loan_payment": int(core.get("loan_payment", 0))
    }
    if not snapshot.has("businesses") or not (snapshot["businesses"] is Dictionary):
        snapshot["businesses"] = {}
    snapshot["businesses"]["renew_goods"] = {
        "open": bool(core.get("business_open", false)),
        "capacity_level": int(core.get("capacity_level", 1)),
        "marketing_level": int(core.get("marketing_level", 0)),
        "price": int(core.get("player_price", 110)),
        "finished_goods": int(core.get("finished_goods", 0))
    }

func _migrate(snapshot: Dictionary) -> Dictionary:
    if not (snapshot is Dictionary) or snapshot.is_empty():
        return {}
    var version := int(snapshot.get("schema_version", snapshot.get("state_version", 1)))
    if version > STATE_VERSION:
        return {}
    var migrated := snapshot.duplicate(true)
    if version < 3:
        var base := new_game()
        for key in base.keys():
            if not migrated.has(key):
                migrated[key] = base[key]
    migrated["schema_version"] = STATE_VERSION
    migrated["state_version"] = STATE_VERSION
    if not migrated.has("meta") or not (migrated["meta"] is Dictionary):
        migrated["meta"] = {"created_at": "", "last_saved_at": ""}
    if not migrated.has("history") or not (migrated["history"] is Array):
        migrated["history"] = []
    if not migrated.has("news") or not (migrated["news"] is Dictionary):
        migrated["news"] = {"editions": []}
    return migrated
