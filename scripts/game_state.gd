extends Node
class_name RenewGameState

# Single authoritative persistent state for the RENEW simulation.
const STATE_VERSION := 3
const BUSINESS_ID := "renew_goods"
var data: Dictionary = {}
var dirty := false

func new_game() -> Dictionary:
    data = {"schema_version": STATE_VERSION, "state_version": STATE_VERSION, "meta": {"created_at": Time.get_datetime_string_from_system(true), "last_saved_at": ""}, "clock": {"day": 1}, "player": {"cash": 25000, "reputation": 0}, "company": {"id": BUSINESS_ID, "name": "RENEW Goods", "founded_day": 1}, "properties": {}, "businesses": {}, "branches": {}, "employees": {"next_id": 1, "records": {}}, "economy": {}, "resources": {}, "production": {}, "supply_chain": {}, "contracts": {}, "competitors": {}, "ownership": {}, "finance": {}, "alliances": {}, "diplomacy": {}, "regions": {}, "infrastructure": {}, "technology": {}, "events": {}, "progression": {}, "history": [], "news": {"editions": []}, "analytics": {}, "legacy": {"employee_count": 3}}
    _ensure_business_record()
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

# Business persistence boundary. main.gd may temporarily expose scalar fields for
# UI compatibility, but the durable business record lives here. All persistence
# code should enter through this boundary rather than maintaining a second save.
func get_business(business_id: String = BUSINESS_ID) -> Dictionary:
    _ensure_business_record(business_id)
    return data["businesses"][business_id].duplicate(true)

func set_business_value(key: String, value, business_id: String = BUSINESS_ID) -> void:
    _ensure_business_record(business_id)
    data["businesses"][business_id][key] = value
    dirty = true

func sync_business_runtime(core: Dictionary, business_id: String = BUSINESS_ID) -> void:
    _ensure_business_record(business_id)
    var record: Dictionary = data["businesses"][business_id]
    var defaults := {"open": false, "capacity_level": 1, "marketing_level": 0, "price": 110, "finished_goods": 0, "last_sales": 0, "last_profit": 0, "total_profit": 0, "contract_days": 0, "contract_bonus": 0}
    var mapping := {"open": "business_open", "capacity_level": "capacity_level", "marketing_level": "marketing_level", "price": "player_price", "finished_goods": "finished_goods", "last_sales": "last_sales", "last_profit": "last_profit", "total_profit": "total_profit", "contract_days": "contract_days", "contract_bonus": "contract_bonus"}
    for key in defaults.keys():
        var source_key: String = mapping[key]
        if core.has(source_key):
            record[key] = core[source_key]
        elif not record.has(key):
            record[key] = defaults[key]
    data["businesses"][business_id] = record
    dirty = true

func restore_business_runtime(core: Dictionary, business_id: String = BUSINESS_ID) -> void:
    var record := get_business(business_id)
    core["business_open"] = bool(record.get("open", false))
    core["capacity_level"] = int(record.get("capacity_level", 1))
    core["marketing_level"] = int(record.get("marketing_level", 0))
    core["player_price"] = int(record.get("price", 110))
    core["finished_goods"] = int(record.get("finished_goods", 0))
    core["last_sales"] = int(record.get("last_sales", 0))
    core["total_profit"] = int(record.get("total_profit", 0))
    core["last_profit"] = int(record.get("last_profit", 0))
    core["contract_days"] = int(record.get("contract_days", 0))
    core["contract_bonus"] = int(record.get("contract_bonus", 0))

func mark_dirty() -> void:
    dirty = true

func has_state() -> bool:
    return not data.is_empty()

func get_value(path: Array, fallback = null):
    var cursor = data
    for key in path:
        if not (cursor is Dictionary) or not cursor.has(key): return fallback
        cursor = cursor[key]
    return cursor

func set_value(path: Array, value) -> void:
    if path.is_empty(): return
    if data.is_empty(): new_game()
    var cursor: Dictionary = data
    for i in range(path.size() - 1):
        var key = path[i]
        if not cursor.has(key) or not (cursor[key] is Dictionary): cursor[key] = {}
        cursor = cursor[key]
    cursor[path[path.size() - 1]] = value
    dirty = true

func clear() -> void:
    data.clear()
    dirty = false

func _ensure_business_record(business_id: String = BUSINESS_ID) -> void:
    if data.is_empty(): return
    if not data.has("businesses") or not (data["businesses"] is Dictionary): data["businesses"] = {}
    if not data["businesses"].has(business_id) or not (data["businesses"][business_id] is Dictionary):
        data["businesses"][business_id] = {"id": business_id, "open": false, "capacity_level": 1, "marketing_level": 0, "price": 110, "finished_goods": 0, "last_sales": 0, "last_profit": 0, "total_profit": 0, "contract_days": 0, "contract_bonus": 0}

func _merge_legacy_core(snapshot: Dictionary, core: Dictionary) -> void:
    # Keep legacy runtime fields for compatibility, but never replace canonical
    # branch/employee records with transient scalar projections.
    for key in core.keys():
        if key != "employees" and key != "branches" and key not in ["business_open", "capacity_level", "marketing_level", "player_price", "finished_goods", "last_sales", "last_profit", "total_profit", "contract_days", "contract_bonus"]: snapshot[key] = core[key]
    if not snapshot.has("clock") or not (snapshot["clock"] is Dictionary): snapshot["clock"] = {}
    if not snapshot.has("player") or not (snapshot["player"] is Dictionary): snapshot["player"] = {}
    if not snapshot.has("legacy") or not (snapshot["legacy"] is Dictionary): snapshot["legacy"] = {}
    snapshot["clock"]["day"] = int(core.get("day", snapshot["clock"].get("day", 1)))
    snapshot["player"]["cash"] = int(core.get("cash", snapshot["player"].get("cash", 0)))
    snapshot["player"]["reputation"] = int(core.get("reputation", snapshot["player"].get("reputation", 0)))
    snapshot["legacy"]["employee_count"] = int(core.get("employees", snapshot["legacy"].get("employee_count", 0)))
    snapshot["finance"] = {"debt": int(core.get("debt", 0)), "loan_payment": int(core.get("loan_payment", 0))}
    _ensure_business_record_in_snapshot(snapshot)
    # Runtime is the source for the current save operation. Synchronize it into
    # the canonical business record here, but never use this direction during
    # load/restore. That prevents stale canonical data from being overwritten by
    # defaults while still eliminating the previous "canonical data never updates"
    # bug during normal saves.
    var business: Dictionary = snapshot["businesses"][BUSINESS_ID]
    var legacy_business_keys := {"open": "business_open", "capacity_level": "capacity_level", "marketing_level": "marketing_level", "price": "player_price", "finished_goods": "finished_goods", "last_sales": "last_sales", "last_profit": "last_profit", "total_profit": "total_profit", "contract_days": "contract_days", "contract_bonus": "contract_bonus"}
    for key in legacy_business_keys.keys():
        if core.has(legacy_business_keys[key]):
            business[key] = core[legacy_business_keys[key]]
        elif not business.has(key):
            business[key] = _business_default(key)
    snapshot["businesses"][BUSINESS_ID] = business
    if not snapshot.has("branches") or not (snapshot["branches"] is Dictionary): snapshot["branches"] = {}
    if not snapshot.has("employees") or not (snapshot["employees"] is Dictionary): snapshot["employees"] = {"next_id": 1, "records": {}}

func _business_default(key: String):
    match key:
        "open": return false
        "capacity_level": return 1
        "marketing_level": return 0
        "price": return 110
        "finished_goods": return 0
        "last_sales": return 0
        "last_profit": return 0
        "total_profit": return 0
        "contract_days": return 0
        "contract_bonus": return 0
        _: return 0

func _ensure_business_record_in_snapshot(snapshot: Dictionary) -> void:
    if not snapshot.has("businesses") or not (snapshot["businesses"] is Dictionary): snapshot["businesses"] = {}
    if not snapshot["businesses"].has(BUSINESS_ID) or not (snapshot["businesses"][BUSINESS_ID] is Dictionary):
        snapshot["businesses"][BUSINESS_ID] = {"id": BUSINESS_ID, "open": false, "capacity_level": 1, "marketing_level": 0, "price": 110, "finished_goods": 0, "last_sales": 0, "last_profit": 0, "total_profit": 0, "contract_days": 0, "contract_bonus": 0}

func _migrate(snapshot: Dictionary) -> Dictionary:
    if not (snapshot is Dictionary) or snapshot.is_empty(): return {}
    var version := int(snapshot.get("schema_version", snapshot.get("state_version", 1)))
    if version > STATE_VERSION: return {}
    var migrated := snapshot.duplicate(true)
    if version < 3:
        var base := new_game()
        for key in base.keys():
            if not migrated.has(key): migrated[key] = base[key]
    if not migrated.has("employees") or not (migrated["employees"] is Dictionary): migrated["employees"] = {"next_id": 1, "records": {}}
    if migrated["employees"].has("employees") and not migrated["employees"].has("records"):
        migrated["employees"]["records"] = migrated["employees"]["employees"]
        migrated["employees"].erase("employees")
    if migrated.has("branches") and migrated["branches"] is Array:
        var branch_records:={}
        for index in range(migrated["branches"].size()):
            if migrated["branches"][index] is Dictionary:
                branch_records["branch_%d" % index]=migrated["branches"][index].duplicate(true)
        migrated["branches"]={"selected":0,"records":branch_records}
    elif not migrated.has("branches") or not (migrated["branches"] is Dictionary):
        migrated["branches"]={}
    _ensure_business_record_in_snapshot(migrated)
    var business: Dictionary = migrated["businesses"][BUSINESS_ID]
    var legacy_business_keys := {"open": "business_open", "capacity_level": "capacity_level", "marketing_level": "marketing_level", "price": "player_price", "finished_goods": "finished_goods", "last_sales": "last_sales", "last_profit": "last_profit", "total_profit": "total_profit", "contract_days": "contract_days", "contract_bonus": "contract_bonus"}
    for key in legacy_business_keys.keys():
        if not business.has(key) and migrated.has(legacy_business_keys[key]): business[key] = migrated[legacy_business_keys[key]]
    migrated["businesses"][BUSINESS_ID] = business
    if not migrated.has("history") or not (migrated["history"] is Array): migrated["history"] = []
    if not migrated.has("news") or not (migrated["news"] is Dictionary): migrated["news"] = {"editions": []}
    migrated["schema_version"] = STATE_VERSION
    migrated["state_version"] = STATE_VERSION
    return migrated
