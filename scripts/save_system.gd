# ===============================================
# File: scripts/save_system.gd
# ===============================================
extends RefCounted
class_name RenewSaveSystem

const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"
const TEMP_PATH := "user://renew_save.tmp.json"
const CURRENT_VERSION := 8

static func save_game(_state: Dictionary) -> bool:
    var game_state = _game_state()
    var payload = game_state.capture() if game_state and _state.has("domains") else _state.duplicate(true)
    payload["schema_version"] = CURRENT_VERSION
    var json = JSON.stringify(payload)
    var temp = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null:
        return false
    temp.store_string(json)
    temp.flush()
    temp = null
    # Backup existing save
    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
        DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
    # Replace with new save
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
    return true

static func load_game() -> Dictionary:
    var data = _read_dictionary(SAVE_PATH)
    if data.is_empty():
        data = _read_dictionary(BACKUP_PATH)
    if data.is_empty():
        return {}
    var version = int(data.get("schema_version", 1))
    if version < 1 or version > CURRENT_VERSION:
        return {}
    # Migrate if needed
    while version < CURRENT_VERSION:
        data = migrate(data, version)
        if data.is_empty():
            return {}
        version = int(data.get("schema_version", version + 1))
    if not data.has("domains"):
        return data
    # Validate
    if not validate_save(data):
        return {}
    var game_state = _game_state()
    if game_state:
        if not game_state.restore(data):
            return {}
        return game_state.capture()
    return data

static func validate_save(data: Dictionary) -> bool:
    if not data.has("schema_version") or int(data["schema_version"]) != CURRENT_VERSION:
        return false
    if not data.has("domains") or not (data["domains"] is Dictionary):
        return false
    return true

static func migrate(data: Dictionary, version: int) -> Dictionary:
    # Copy existing migrations from your original file
    # I'll include the V1->V8 chain as in your original but simplified.
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
    return result

static func _migrate_v7_to_v8(data: Dictionary) -> Dictionary:
    # Ensure all domains exist
    var domains = data.get("domains", {})
    for domain in ["player","company","properties","businesses","branches","employees","economy","resources","production","supply_chain","contracts","competitors","alliances","regions","technology","events","progression","history","news","analytics","acquisition","bankruptcy","infrastructure","diplomacy"]:
        if not domains.has(domain):
            domains[domain] = {}
    data["domains"] = domains
    data["schema_version"] = 8
    return data

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
