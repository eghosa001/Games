extends RefCounted
class_name RenewSaveSystem

## Canonical save format: one schema version plus one domain map.
## Legacy data exists only inside explicit migration steps.
const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"
const TEMP_PATH := "user://renew_save.tmp.json"
const CURRENT_VERSION := 8
const SCHEMA_VERSION := CURRENT_VERSION

static func save_game(_state: Dictionary) -> bool:
    var game_state = _game_state()
    var payload:Dictionary = game_state.capture() if game_state != null else {}
    payload["schema_version"] = CURRENT_VERSION
    payload.erase("state_version")
    payload.erase("legacy")
    var json := JSON.stringify(payload)
    var temp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null: return false
    temp.store_string(json); temp.flush(); temp = null
    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
        if DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH)) != OK:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH)); return false
    if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH)) != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH)); return false
    return true

static func load_game() -> Dictionary:
    var data := _read_dictionary(SAVE_PATH)
    if data.is_empty(): data = _read_dictionary(BACKUP_PATH)
    if data.is_empty(): return {}
    var version := int(data.get("schema_version", 1))
    if version < 1 or version > CURRENT_VERSION: return {}
    while version < CURRENT_VERSION:
        data = migrate(data, version)
        if data.is_empty(): return {}
        version = int(data.get("schema_version", version + 1))
    var game_state = _game_state()
    if game_state != null:
        game_state.restore(data)
        return game_state.capture()
    return data

static func migrate(data: Dictionary, version: int) -> Dictionary:
    match version:
        1: return migrate_v1_to_v2(data)
        2: return migrate_v2_to_v3(data)
        3: return migrate_v3_to_v4(data)
        4: return migrate_v4_to_v5(data)
        5: return migrate_v5_to_v6(data)
        6: return migrate_v6_to_v7(data)
        7: return migrate_v7_to_v8(data)
    return {}

static func migrate_v1_to_v2(data: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    if not result.has("company"): result["company"] = {}
    if not result.has("properties"): result["properties"] = {}
    result["schema_version"] = 2
    return result

static func migrate_v2_to_v3(data: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    if not result.has("businesses"): result["businesses"] = {}
    if not result.has("branches"): result["branches"] = {}
    result["schema_version"] = 3
    return result

static func migrate_v3_to_v4(data: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    if not result.has("employees"): result["employees"] = {"roster": []}
    elif result["employees"] is Array: result["employees"] = {"roster": result["employees"]}
    result["schema_version"] = 4
    return result

static func migrate_v4_to_v5(data: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    for domain in ["economy", "resources", "production", "supply_chain", "contracts"]:
        if not result.has(domain): result[domain] = {}
    result["schema_version"] = 5
    return result

static func migrate_v5_to_v6(data: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    for domain in ["competitors", "alliances", "regions", "technology", "events"]:
        if not result.has(domain): result[domain] = {}
    result["schema_version"] = 6
    return result

static func migrate_v6_to_v7(data: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    for domain in ["progression", "history", "news"]:
        if not result.has(domain): result[domain] = {}
    result["schema_version"] = 7
    return result

static func migrate_v7_to_v8(data: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    for domain in ["player", "company", "properties", "businesses", "branches", "employees", "economy", "resources", "production", "supply_chain", "contracts", "competitors", "alliances", "regions", "technology", "events", "progression", "history", "news", "analytics"]:
        if not result.has(domain): result[domain] = {}
    result.erase("state_version")
    result.erase("legacy")
    result["schema_version"] = 8
    return {"schema_version": 8, "domains": _to_domains(result)}

static func _to_domains(data: Dictionary) -> Dictionary:
    if data.get("domains", null) is Dictionary:
        return data["domains"].duplicate(true)
    var domains:Dictionary = {}
    var known := ["player", "company", "properties", "businesses", "branches", "employees", "economy", "resources", "production", "supply_chain", "contracts", "competitors", "alliances", "regions", "technology", "events", "progression", "history", "news", "analytics"]
    for domain in known: domains[domain] = data.get(domain, {}).duplicate(true) if data.get(domain, {}) is Dictionary else {}
    return domains

static func _read_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

static func _root_node(name: String):
    var tree = Engine.get_main_loop()
    if tree == null: return null
    var root = tree.get_root()
    if root == null: return null
    var node = root.get_node_or_null(name)
    if node != null: return node
    var scene = tree.get_current_scene()
    return scene.get_node_or_null(name) if scene != null else null

static func _game_state(): return _root_node("RenewGameState")
