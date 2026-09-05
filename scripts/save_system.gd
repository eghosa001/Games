# ===============================================
# File: scripts/save_system.gd
# ===============================================
extends RefCounted
class_name RenewSaveSystem

const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"
const TEMP_PATH := "user://renew_save.tmp.json"
const BACKUP_TEMP_PATH := "user://renew_save.backup.tmp.json"
const CURRENT_VERSION := 8
const REQUIRED_DOMAINS := ["player", "company", "properties", "economy", "businesses", "branches", "employees", "resources", "production", "supply_chain", "contracts", "competitors", "finance", "alliances", "diplomacy", "regions", "infrastructure", "technology", "events", "progression", "history", "news", "analytics", "acquisition", "bankruptcy"]

static func save_game(_state: Dictionary) -> bool:
    var game_state = _game_state()
    var payload = game_state.capture() if game_state and _state.has("domains") else _state.duplicate(true)
    payload["schema_version"] = CURRENT_VERSION
    if payload.has("domains") and not validate_save(payload):
        return false
    payload = _sanitize_json_value(payload)
    var json = JSON.stringify(payload)
    var temp = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null:
        return false
    temp.store_string(json)
    temp.flush()
    temp = null

    var had_primary := FileAccess.file_exists(SAVE_PATH)
    if had_primary:
        if FileAccess.file_exists(BACKUP_TEMP_PATH):
            var stale_backup_temp_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_TEMP_PATH))
            if stale_backup_temp_error != OK:
                return false
        var backup_temp_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_TEMP_PATH))
        if backup_temp_error != OK:
            return false

    if had_primary:
        var remove_save_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
        if remove_save_error != OK:
            return false
    var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
    if rename_error != OK:
        if had_primary and FileAccess.file_exists(BACKUP_TEMP_PATH):
            DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
        return false

    if had_primary:
        if FileAccess.file_exists(BACKUP_PATH):
            var remove_backup_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
            if remove_backup_error != OK:
                return false
        var install_backup_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(BACKUP_TEMP_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
        if install_backup_error != OK:
            return false
    return true

static func load_game() -> Dictionary:
    var candidates: Array[String] = [SAVE_PATH, BACKUP_PATH]
    for path in candidates:
        var data := _read_dictionary(path)
        if data.is_empty():
            continue
        var version := int(data.get("schema_version", 1))
        if version < 1 or version > CURRENT_VERSION:
            continue
        var valid := true
        while version < CURRENT_VERSION:
            data = migrate(data, version)
            if data.is_empty():
                valid = false
                break
            version = int(data.get("schema_version", version + 1))
        if not valid:
            continue
        if data.has("domains"):
            if not validate_save(data):
                continue
            var game_state = _game_state()
            if game_state:
                if not game_state.restore(data):
                    continue
                return game_state.capture()
        return data
    return {}

static func validate_save(data: Dictionary) -> bool:
    if not data.has("schema_version") or int(data["schema_version"]) != CURRENT_VERSION:
        return false
    if not data.has("domains") or not (data["domains"] is Dictionary):
        return false
    for domain in REQUIRED_DOMAINS:
        if not data["domains"].has(domain) or not (data["domains"][domain] is Dictionary):
            return false
    return true

static func migrate(data: Dictionary, version: int) -> Dictionary:
    var result = data.duplicate(true)
    match version:
        1: result["schema_version"] = 2
        2: result["schema_version"] = 3
        3: result["schema_version"] = 4
        4: result["schema_version"] = 5
        5: result["schema_version"] = 6
        6: result["schema_version"] = 7
        7: result = _migrate_v7_to_v8(result)
        _: return {}
    return _ensure_required_domains(result)

static func _ensure_required_domains(data: Dictionary) -> Dictionary:
    var domains = data.get("domains", {})
    if not domains is Dictionary:
        domains = {}
    for domain in REQUIRED_DOMAINS:
        if not domains.has(domain) or not (domains[domain] is Dictionary):
            domains[domain] = {}
    data["domains"] = domains
    return data

static func _migrate_v7_to_v8(data: Dictionary) -> Dictionary:
    data = _ensure_required_domains(data)
    var domains = data["domains"]
    if domains.has("competitors") and domains["competitors"] is Dictionary and not domains["competitors"].has("reaction_system"):
        domains["competitors"]["reaction_system"] = {}
    data["domains"] = domains
    data["schema_version"] = 8
    return data

static func _sanitize_json_value(value):
    if value is float:
        return value if is_finite(value) else 0.0
    if value is Dictionary:
        var result: Dictionary = {}
        for key in value.keys():
            result[key] = _sanitize_json_value(value[key])
        return result
    if value is Array:
        var result: Array = []
        for item in value:
            result.append(_sanitize_json_value(item))
        return result
    return value

static func _read_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

static func _game_state():
    var tree = Engine.get_main_loop()
    if not tree: return null
    var root = tree.get_root()
    if not root: return null
    var node = root.get_node_or_null("RenewGameState")
    if node: return node
    var scene = tree.get_current_scene()
    if scene:
        return scene.get_node_or_null("RenewGameState")
    return null