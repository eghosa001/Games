extends RefCounted
class_name RenewSaveSystem

const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"
const TEMP_PATH := "user://renew_save.tmp.json"
const SCHEMA_VERSION := 4

static func save_game(state: Dictionary) -> bool:
    var payload := state.duplicate(true)
    payload["schema_version"] = SCHEMA_VERSION
    payload["state_version"] = int(payload.get("state_version", 2))
    var employee_system = _employee_system()
    if employee_system != null:
        payload["employee_system"] = employee_system.capture_state()
    var history_system = _history_system()
    if history_system != null:
        _sync_history_from_game(history_system)
        payload["history_system"] = history_system.capture_state()

    var game_state = _game_state()
    if game_state != null:
        game_state.capture(payload)

    var json := JSON.stringify(payload)
    var temp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null: return false
    temp.store_string(json)
    temp.flush()
    temp = null
    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
        if DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH)) != OK:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH)); return false
    if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH)) != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH)); return false
    return true

static func load_game() -> Dictionary:
    var state := _read_dictionary(SAVE_PATH)
    if state.is_empty(): state = _read_dictionary(BACKUP_PATH)
    if state.is_empty(): return {}
    state = _migrate(state)
    if state.is_empty(): return {}

    var employee_system = _employee_system()
    if employee_system != null:
        if state.has("employee_system"): employee_system.restore_state(state["employee_system"])
        else: employee_system.migrate_legacy_count(int(state.get("employees", 3)), int(state.get("day", 1)))
        state["employees"] = employee_system.active_count()
    var history_system = _history_system()
    if history_system != null:
        if state.has("history_system"): history_system.restore_state(state["history_system"])
        else: history_system.ingest_activity_log(state.get("log_lines", []), int(state.get("day", 1)))
    var game_state = _game_state()
    if game_state != null: game_state.restore(state)
    return state

static func _sync_history_from_game(history_system) -> void:
    var tree = Engine.get_main_loop()
    if tree == null: return
    var root = tree.get_root()
    if root == null: return
    var main = root.get_node_or_null("Main")
    if main == null: main = tree.get_current_scene()
    if main == null: return
    var logs = main.get("log_lines")
    if logs is Array: history_system.ingest_activity_log(logs, int(main.get("day")))

static func _read_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

static func _migrate(state: Dictionary) -> Dictionary:
    var schema := int(state.get("schema_version", 0))
    if schema == SCHEMA_VERSION: return state
    if schema >= 0 and schema <= 3:
        var migrated := state.duplicate(true)
        migrated["schema_version"] = SCHEMA_VERSION
        migrated["state_version"] = 2
        return migrated
    return {}

static func _game_state():
    var tree = Engine.get_main_loop()
    if tree == null: return null
    var root = tree.get_root()
    if root == null: return null
    return root.get_node_or_null("RenewGameState")

static func _employee_system():
    var tree = Engine.get_main_loop()
    if tree == null: return null
    var root = tree.get_root()
    if root == null: return null
    return root.get_node_or_null("RenewEmployeeSystem")

static func _history_system():
    var tree = Engine.get_main_loop()
    if tree == null: return null
    var root = tree.get_root()
    if root == null: return null
    return root.get_node_or_null("RenewHistorySystem")
