extends RefCounted
class_name RenewSaveSystem

const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"
const TEMP_PATH := "user://renew_save.tmp.json"
const SCHEMA_VERSION := 3

static func save_game(state: Dictionary) -> bool:
    if state.is_empty():
        return false
    var game_state = _game_state()
    var payload := state.duplicate(true)
    if game_state != null:
        payload = game_state.capture(payload)
    payload["schema_version"] = SCHEMA_VERSION
    payload["state_version"] = SCHEMA_VERSION
    payload["save_metadata"] = {
        "saved_at": Time.get_datetime_string_from_system(true),
        "day": int(payload.get("day", payload.get("clock", {}).get("day", 1)))
    }
    if not _validate(payload):
        return false

    var json := JSON.stringify(payload)
    var temp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null:
        return false
    temp.store_string(json)
    temp.flush()
    temp = null

    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
        if DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH)) != OK:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
            return false

    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH)) != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
        return false
    return true

static func load_game() -> Dictionary:
    var active := _read_dictionary(SAVE_PATH)
    var state := _migrate(active)
    var source := "active"
    if state.is_empty():
        state = _migrate(_read_dictionary(BACKUP_PATH))
        source = "backup"
    if state.is_empty():
        return {}
    if source == "backup":
        state["recovery"] = {"source": "backup", "recovered_at": Time.get_datetime_string_from_system(true)}
    if not _validate(state):
        return {}

    var game_state = _game_state()
    if game_state != null:
        game_state.restore(state)
    return state

static func _read_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return {}
    return parsed

static func _migrate(state: Dictionary) -> Dictionary:
    if state.is_empty():
        return {}
    var schema := int(state.get("schema_version", state.get("state_version", 1)))
    if schema > SCHEMA_VERSION:
        return {}
    if schema == SCHEMA_VERSION:
        return state
    if schema == 1 or schema == 2:
        var game_state = _game_state()
        if game_state != null:
            return game_state.restore(state)
        var migrated := state.duplicate(true)
        migrated["schema_version"] = SCHEMA_VERSION
        migrated["state_version"] = SCHEMA_VERSION
        return migrated
    return {}

static func _validate(state: Dictionary) -> bool:
    if int(state.get("schema_version", 0)) != SCHEMA_VERSION:
        return false
    if not state.has("clock") or not (state["clock"] is Dictionary):
        return false
    if not state.has("player") or not (state["player"] is Dictionary):
        return false
    var day := int(state.get("day", state["clock"].get("day", 0)))
    var cash := int(state.get("cash", state["player"].get("cash", 0)))
    return day >= 1 and cash > -1000000000

static func _game_state():
    var tree = Engine.get_main_loop()
    if tree == null:
        return null
    var root = tree.get_root()
    if root == null:
        return null
    return root.get_node_or_null("RenewGameState")
