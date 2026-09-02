extends RefCounted
class_name RenewSaveSystem

# Versioned, recoverable persistence. A temporary write plus a rolling backup
# protects long mobile sessions from interrupted file writes or malformed saves.
const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"
const TEMP_PATH := "user://renew_save.tmp.json"
const SCHEMA_VERSION := 1

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
        if FileAccess.copy(SAVE_PATH, BACKUP_PATH) != OK:
            return false

    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH)) != OK:
        return false
    return true

static func load_game() -> Dictionary:
    var state := _read_dictionary(SAVE_PATH)
    if not state.is_empty():
        return state
    # Recover automatically if the primary save was interrupted or corrupted.
    var backup := _read_dictionary(BACKUP_PATH)
    return backup

static func _read_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
