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
const REQUIRED_DOMAINS := ["player", "company", "properties", "economy", "businesses", "branches", "employees", "resources", "production", "supply_chain", "contracts", "competitors", "finance", "alliances", "diplomacy", "regions", "infrastructure", "technology", "events", "progression", "history", "news", "analytics", "acquisition", "ownership", "bankruptcy"]

static func save_game(_state: Dictionary) -> bool:
    var game_state = _game_state()
    var payload: Dictionary = game_state.capture() if game_state != null and _state.is_empty() else _state.duplicate(true)
    payload["schema_version"] = CURRENT_VERSION
    _capture_runtime_ownership(payload)
    _capture_runtime_services(payload)
    if payload.has("domains") and not validate_save(payload):
        return false

    payload = _sanitize_json_value(payload)
    var json := JSON.stringify(payload)
    var temp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null:
        return false
    temp.store_string(json)
    temp.flush()
    temp = null

    var had_primary := FileAccess.file_exists(SAVE_PATH)
    var save_absolute := ProjectSettings.globalize_path(SAVE_PATH)
    var temp_absolute := ProjectSettings.globalize_path(TEMP_PATH)
    var backup_absolute := ProjectSettings.globalize_path(BACKUP_PATH)
    var backup_temp_absolute := ProjectSettings.globalize_path(BACKUP_TEMP_PATH)

    # Keep a verified copy of the last committed save before replacing it.
    # The previous implementation deleted the primary before renaming the new
    # file, creating an avoidable no-primary window during a crash.
    if had_primary:
        if FileAccess.file_exists(BACKUP_TEMP_PATH):
            if DirAccess.remove_absolute(backup_temp_absolute) != OK:
                _cleanup_temp_files()
                return false
        if DirAccess.copy_absolute(save_absolute, backup_temp_absolute) != OK:
            _cleanup_temp_files()
            return false

    # Godot's rename overwrites an existing writable destination, so this is
    # the single replacement step. There is no explicit delete of SAVE_PATH.
    var rename_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
    if rename_error != OK:
        if had_primary and FileAccess.file_exists(BACKUP_TEMP_PATH):
            DirAccess.copy_absolute(backup_temp_absolute, save_absolute)
        _cleanup_temp_files()
        return false

    if had_primary:
        # Install the previous primary as the new backup only after the new
        # primary is safely in place. If rotation fails, the primary remains a
        # valid committed save; keep the backup temp for recovery instead of
        # reporting a false save failure.
        if FileAccess.file_exists(BACKUP_PATH):
            var remove_backup_error := DirAccess.remove_absolute(backup_absolute)
            if remove_backup_error != OK:
                _cleanup_temp_files(false)
                return true
        var install_backup_error := DirAccess.rename_absolute(backup_temp_absolute, backup_absolute)
        if install_backup_error != OK:
            _cleanup_temp_files(false)
            return true

    _cleanup_temp_files()
    return true

static func _cleanup_temp_files(remove_backup_temp: bool = true) -> void:
    if FileAccess.file_exists(TEMP_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
    if remove_backup_temp and FileAccess.file_exists(BACKUP_TEMP_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_TEMP_PATH))

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
                _restore_runtime_ownership(data)
                _restore_runtime_services(data)
                return game_state.capture()
        _restore_runtime_ownership(data)
        _restore_runtime_services(data)
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
    var result: Dictionary = data.duplicate(true)
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
    var domains: Dictionary = data["domains"]
    if domains.has("competitors") and domains["competitors"] is Dictionary and not domains["competitors"].has("reaction_system"):
        domains["competitors"]["reaction_system"] = {}
    data["domains"] = domains
    data["schema_version"] = 8
    return data

static func _capture_runtime_ownership(data: Dictionary) -> void:
    if not data.has("domains") or not (data["domains"] is Dictionary):
        return
    var ownership = _ownership_node()
    if ownership == null or not ownership.has_method("save_state"):
        return
    var domains: Dictionary = data["domains"]
    var ownership_domain: Dictionary = domains.get("ownership", {})
    if not ownership_domain is Dictionary:
        ownership_domain = {}
    ownership_domain["ledger"] = ownership.save_state()
    domains["ownership"] = ownership_domain
    data["domains"] = domains

static func _restore_runtime_ownership(data: Dictionary) -> void:
    if not data.has("domains") or not (data["domains"] is Dictionary):
        return
    var domains: Dictionary = data["domains"]
    var ownership_domain: Variant = domains.get("ownership", {})
    if not ownership_domain is Dictionary:
        return
    var ledger: Variant = ownership_domain.get("ledger", {})
    if not ledger is Dictionary or ledger.is_empty():
        return
    var ownership = _ownership_node()
    if ownership != null and ownership.has_method("load_state"):
        ownership.load_state(ledger)

## Service-owned systems live outside GameState. Persist their explicit snapshots
## inside the existing company domain so schema v8 remains backward-compatible.
static func _capture_runtime_services(data: Dictionary) -> void:
    if not data.has("domains") or not (data["domains"] is Dictionary):
        return
    var registry = _service_registry()
    if registry == null or not registry.has_method("capture_persistent_state"):
        return
    var snapshot = registry.capture_persistent_state()
    if not snapshot is Dictionary:
        return
    var domains: Dictionary = data["domains"]
    var company_domain = domains.get("company", {})
    if not company_domain is Dictionary:
        company_domain = {}
    company_domain["runtime_services"] = snapshot.duplicate(true)
    domains["company"] = company_domain
    data["domains"] = domains

static func _restore_runtime_services(data: Dictionary) -> void:
    if not data.has("domains") or not (data["domains"] is Dictionary):
        return
    var domains: Dictionary = data["domains"]
    var company_domain = domains.get("company", {})
    if not company_domain is Dictionary:
        return
    var snapshot = company_domain.get("runtime_services", {})
    if not snapshot is Dictionary or snapshot.is_empty():
        return
    var registry = _service_registry()
    if registry != null and registry.has_method("restore_persistent_state"):
        registry.restore_persistent_state(snapshot)

static func _service_registry():
    var tree = Engine.get_main_loop()
    if not tree:
        return null
    var root = tree.get_root()
    if not root:
        return null
    var registry = root.get_node_or_null("RenewServices")
    if registry != null:
        return registry
    var scene = tree.get_current_scene()
    if scene != null:
        registry = scene.get_node_or_null("RenewServices")
        if registry != null:
            return registry
    return null

static func _ownership_node():
    var tree = Engine.get_main_loop()
    if not tree:
        return null
    var root = tree.get_root()
    if not root:
        return null
    var node = root.get_node_or_null("Renew/Systems/OwnershipSystem")
    if node != null:
        return node
    node = root.get_node_or_null("RenewOwnershipSystem")
    if node != null:
        return node
    var scene = tree.get_current_scene()
    if scene:
        node = scene.get_node_or_null("Systems/OwnershipSystem")
        if node == null:
            node = scene.get_node_or_null("OwnershipSystem")
        return node
    return null

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
    if not tree:
        return null
    var root = tree.get_root()
    if not root:
        return null
    var node = root.get_node_or_null("RenewGameState")
    if node:
        return node
    var scene = tree.get_current_scene()
    if scene:
        return scene.get_node_or_null("RenewGameState")
    return null
