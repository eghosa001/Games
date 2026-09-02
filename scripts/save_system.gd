extends RefCounted
class_name RenewSaveSystem

const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"
const TEMP_PATH := "user://renew_save.tmp.json"
const SCHEMA_VERSION := 3

static func save_game(state: Dictionary) -> bool:
    if state.is_empty(): return false
    var game_state = _game_state()
    var payload := state.duplicate(true)
    if game_state != null:
        # Business state is persisted through the canonical GameState boundary.
        # Legacy scalar fields are accepted only as a runtime compatibility
        # projection and are not allowed to replace an existing canonical record.
        game_state.sync_business_runtime(payload)
        payload = game_state.capture(payload)
    payload["schema_version"] = SCHEMA_VERSION
    payload["state_version"] = SCHEMA_VERSION
    payload["save_metadata"] = {"saved_at": Time.get_datetime_string_from_system(true), "day": int(payload.get("day", payload.get("clock", {}).get("day", 1)))}
    if not _validate(payload): return false
    var json := JSON.stringify(payload)
    var temp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null: return false
    temp.store_string(json)
    temp.flush()
    temp = null
    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
        if DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH)) != OK:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
            return false
    if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH)) != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
        return false
    return true

static func load_game() -> Dictionary:
    var state := _migrate(_read_dictionary(SAVE_PATH))
    var source := "active"
    if state.is_empty():
        state = _migrate(_read_dictionary(BACKUP_PATH))
        source = "backup"
    if state.is_empty() or not _validate(state): return {}
    if source == "backup": state["recovery"] = {"source": "backup", "recovered_at": Time.get_datetime_string_from_system(true)}
    var game_state = _game_state()
    if game_state != null: game_state.restore(state)

    _restore_branch_controller(game_state)

    # Rehydrate main.gd's remaining compatibility business fields from the
    # canonical GameState record. GameState remains the durable source of truth.
    if game_state != null:
        game_state.restore_business_runtime(state)
    else:
        _restore_legacy_business_projection(state)

    # The canonical save stores employees as a roster dictionary. main.gd is
    # still a transitional typed-int consumer, so expose only the legacy count
    # in the returned compatibility payload while keeping GameState canonical.
    if state.get("employees") is Dictionary:
        var employee_state: Dictionary = state["employees"]
        var records = employee_state.get("records", {})
        state["employees"] = int(records.size()) if records is Dictionary else int(state.get("legacy", {}).get("employee_count", 0))
    return state

static func _restore_branch_controller(game_state) -> void:
    var tree = Engine.get_main_loop()
    if tree == null: return
    var root = tree.get_root()
    if root == null: return
    var controller = root.get_node_or_null("Main/BranchController")
    if controller == null: return
    if game_state != null and game_state.has_state():
        var saved = game_state.get_value(["branches"], {})
        if saved is Dictionary and not saved.is_empty():
            controller.branches.restore_from_game_state(game_state)

static func _restore_legacy_business_projection(state: Dictionary) -> void:
    var businesses = state.get("businesses", {})
    if not (businesses is Dictionary): return
    var business = businesses.get("renew_goods", {})
    if not (business is Dictionary): return
    state["business_open"] = bool(business.get("open", false))
    state["capacity_level"] = int(business.get("capacity_level", 1))
    state["marketing_level"] = int(business.get("marketing_level", 0))
    state["player_price"] = int(business.get("price", 110))
    state["finished_goods"] = int(business.get("finished_goods", 0))
    state["last_sales"] = int(business.get("last_sales", 0))
    state["last_profit"] = int(business.get("last_profit", 0))
    state["total_profit"] = int(business.get("total_profit", 0))
    state["contract_days"] = int(business.get("contract_days", 0))
    state["contract_bonus"] = int(business.get("contract_bonus", 0))

static func _read_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

static func _migrate(state: Dictionary) -> Dictionary:
    if state.is_empty(): return {}
    var schema := int(state.get("schema_version", state.get("state_version", 1)))
    if schema > SCHEMA_VERSION: return {}
    var migrated := state.duplicate(true)
    if schema < SCHEMA_VERSION:
        var game_state = _game_state()
        if game_state != null:
            migrated = game_state.restore(migrated)
        if migrated.is_empty(): return {}
    migrated["schema_version"] = SCHEMA_VERSION
    migrated["state_version"] = SCHEMA_VERSION
    return migrated

static func _validate(state: Dictionary) -> bool:
    if int(state.get("schema_version", 0)) != SCHEMA_VERSION: return false
    if not state.has("clock") or not (state["clock"] is Dictionary): return false
    if not state.has("player") or not (state["player"] is Dictionary): return false
    var day := int(state.get("day", state["clock"].get("day", 0)))
    var cash := int(state.get("cash", state["player"].get("cash", 0)))
    return day >= 1 and cash > -1000000000

static func _game_state():
    var tree = Engine.get_main_loop()
    if tree == null: return null
    var root = tree.get_root()
    if root == null: return null
    return root.get_node_or_null("RenewGameState")
