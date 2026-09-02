extends Node2D

const SAVE_PATH := "user://renew_empire_state.json"
const BACKUP_PATH := "user://renew_empire_state.backup.json"
var parent
var last_day := 0

func _ready() -> void:
    parent = get_parent()
    if parent != null:
        last_day = int(parent.day)

func _process(_delta: float) -> void:
    if parent == null:
        return
    if int(parent.day) != last_day:
        _save_extended_state(false)
        last_day = int(parent.day)

func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_F5:
            _save_extended_state(true)
        KEY_F9:
            _load_extended_state()

func _state() -> Dictionary:
    var state := {"version": 2, "day": int(parent.day)}
    var supply = parent.get_node_or_null("SupplyChainController")
    if supply != null:
        state["supply"] = supply.supply.snapshot()
        state["contracts"] = supply.contracts.snapshot()
    var branch = parent.get_node_or_null("BranchController")
    if branch != null:
        state["branches"] = {"selected": int(branch.branches.selected), "branches": branch.branches.branches.duplicate(true)}
    var region = parent.get_node_or_null("RegionController")
    if region != null:
        state["regions"] = {"selected": int(region.regions.selected), "regions": region.regions.regions.duplicate(true), "market_levels": region.regions.market_levels.duplicate(true), "player_presence": region.regions.player_presence.duplicate(true), "rival_presence": region.regions.rival_presence.duplicate(true), "infrastructure": region.regions.infrastructure.duplicate(true)}
    return state

func _save_extended_state(log_result: bool) -> void:
    if parent == null:
        return
    var json := JSON.stringify(_state())
    var temp_path := "user://renew_empire_state.tmp.json"
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(json)
    file.flush()
    file = null
    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
        if DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH)) != OK:
            return
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(SAVE_PATH)) != OK:
        return
    if log_result:
        parent._log("SAVE: extended empire state synchronized.")

func _load_extended_state() -> void:
    if parent == null:
        return
    var state = _read_state(SAVE_PATH)
    if state.is_empty():
        state = _read_state(BACKUP_PATH)
    if state.is_empty():
        return
    var supply = parent.get_node_or_null("SupplyChainController")
    if supply != null:
        var supply_state = state.get("supply", {})
        if supply_state is Dictionary:
            supply.supply.load_snapshot(supply_state)
        var contract_state = state.get("contracts", {})
        if contract_state is Dictionary:
            supply.contracts.load_snapshot(contract_state)
    var branch = parent.get_node_or_null("BranchController")
    var branch_state = state.get("branches", {})
    if branch != null and branch_state is Dictionary:
        branch.branches.branches = branch_state.get("branches", branch.branches.branches).duplicate(true)
        branch.branches.selected = int(branch_state.get("selected", 0))
        branch.branches._normalize()
    var region = parent.get_node_or_null("RegionController")
    var region_state = state.get("regions", {})
    if region != null and region_state is Dictionary:
        region.regions.regions = region_state.get("regions", region.regions.regions).duplicate(true)
        region.regions.selected = int(region_state.get("selected", 0))
        region.regions.market_levels = region_state.get("market_levels", region.regions.market_levels).duplicate(true)
        region.regions.player_presence = region_state.get("player_presence", region.regions.player_presence).duplicate(true)
        region.regions.rival_presence = region_state.get("rival_presence", region.regions.rival_presence).duplicate(true)
        region.regions.infrastructure = region_state.get("infrastructure", region.regions.infrastructure).duplicate(true)
        region.regions._normalize()
        parent.selected_district = int(region.regions.selected)
    parent._log("LOAD: extended empire state restored.")
    last_day = int(parent.day)

func _read_state(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
