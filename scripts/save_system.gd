extends RefCounted
class_name RenewSaveSystem

const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"
const TEMP_PATH := "user://renew_save.tmp.json"
const SCHEMA_VERSION := 2

static func save_game(state: Dictionary) -> bool:
    var payload := state.duplicate(true)
    payload["schema_version"] = SCHEMA_VERSION
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
    var state := _read_dictionary(SAVE_PATH)
    if not state.is_empty():
        return _migrate(state)
    state = _read_dictionary(BACKUP_PATH)
    if not state.is_empty():
        return _migrate(state)
    return {}

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
    var schema := int(state.get("schema_version", 0))
    if schema == SCHEMA_VERSION:
        return state
    # V1 saves used a flat runtime snapshot. Preserve every known field and
    # upgrade them into the new state boundary rather than discarding progress.
    if schema == 1:
        var migrated := state.duplicate(true)
        migrated["schema_version"] = SCHEMA_VERSION
        migrated["state_version"] = 2
        return migrated
    return {}
