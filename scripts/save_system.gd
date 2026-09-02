extends RefCounted
class_name RenewSaveSystem

const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"
const TEMP_PATH := "user://renew_save.tmp.json"
const SCHEMA_VERSION := 8

static func save_game(state: Dictionary) -> bool:
    var payload := state.duplicate(true)
    payload["schema_version"] = SCHEMA_VERSION
    payload["state_version"] = 4
    var employee_system = _employee_system()
    if employee_system != null: payload["employee_system"] = employee_system.capture_state()
    var history_system = _history_system()
    if history_system != null:
        _sync_history_from_game(history_system)
        payload["history_system"] = history_system.capture_state()
    var news_system = _news_system()
    if news_system != null: payload["news_system"] = news_system.capture_state()
    var finance_system = _finance_system()
    if finance_system != null: payload["finance_system"] = finance_system.capture_state()
    var production_system = _production_system()
    if production_system != null: payload["production_system"] = production_system.capture_state()
    var simulation_system = _simulation_system()
    if simulation_system != null: payload["simulation_system"] = simulation_system.capture_state()
    var contract_system = _contract_system()
    if contract_system != null: payload["contract_system"] = contract_system.capture_state()
    var alliance_system = _alliance_system()
    if alliance_system != null: payload["alliance_system"] = alliance_system.capture_state()
    var diplomacy_system = _diplomacy_system()
    if diplomacy_system != null: payload["diplomacy_system"] = diplomacy_system.capture_state()
    var game_state = _game_state()
    if game_state != null: payload["game_state"] = game_state.capture(payload)
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
    var state := _read_dictionary(SAVE_PATH)
    if state.is_empty(): state = _read_dictionary(BACKUP_PATH)
    if state.is_empty(): return {}
    state = _migrate(state)
    if state.is_empty(): return {}
    var game_state = _game_state()
    if game_state != null and state.has("game_state") and state["game_state"] is Dictionary:
        var canonical_flat: Dictionary = game_state.restore(state["game_state"])
        for key in canonical_flat.keys():
            if key != "state_version": state[key] = canonical_flat[key]
    var employee_system = _employee_system()
    if employee_system != null:
        if state.has("employee_system"): employee_system.restore_state(state["employee_system"])
        else: employee_system.migrate_legacy_count(int(state.get("employees", 3)), int(state.get("day", 1)))
        state["employees"] = employee_system.active_count()
    var history_system = _history_system()
    if history_system != null:
        if state.has("history_system"): history_system.restore_state(state["history_system"])
        else: history_system.ingest_activity_log(state.get("log_lines", []), int(state.get("day", 1)))
    var news_system = _news_system()
    if news_system != null and state.has("news_system"): news_system.restore_state(state["news_system"])
    var finance_system = _finance_system()
    if finance_system != null and state.has("finance_system"): finance_system.restore_state(state["finance_system"])
    var production_system = _production_system()
    if production_system != null and state.has("production_system"): production_system.restore_state(state["production_system"])
    var simulation_system = _simulation_system()
    if simulation_system != null and state.has("simulation_system"): simulation_system.restore_state(state["simulation_system"])
    var contract_system = _contract_system()
    if contract_system != null and state.has("contract_system"): contract_system.restore_state(state["contract_system"])
    var alliance_system = _alliance_system()
    if alliance_system != null and state.has("alliance_system"): alliance_system.restore_state(state["alliance_system"])
    var diplomacy_system = _diplomacy_system()
    if diplomacy_system != null and state.has("diplomacy_system"): diplomacy_system.restore_state(state["diplomacy_system"])
    if game_state != null: game_state.capture(state)
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
    if schema >= 0 and schema <= 7:
        var migrated := state.duplicate(true)
        migrated["schema_version"] = SCHEMA_VERSION
        migrated["state_version"] = 4
        return migrated
    return {}

static func _root_node(name: String):
    var tree = Engine.get_main_loop()
    if tree == null: return null
    var root = tree.get_root()
    return root.get_node_or_null(name) if root != null else null

static func _game_state(): return _root_node("RenewGameState")
static func _employee_system(): return _root_node("RenewEmployeeSystem")
static func _history_system(): return _root_node("RenewHistorySystem")
static func _news_system(): return _root_node("RenewNewsSystem")
static func _finance_system(): return _root_node("RenewFinanceSystem")
static func _production_system(): return _root_node("RenewProductionSystem")
static func _simulation_system(): return _root_node("RenewSimulationSystem")
static func _contract_system(): return _root_node("RenewContractSystem")
static func _alliance_system(): return _root_node("RenewAllianceSystem")
static func _diplomacy_system(): return _root_node("RenewDiplomacySystem")