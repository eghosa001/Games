extends RefCounted
class_name RenewSaveSystem

## File format: one schema version plus one authoritative domain map.
## Older flat saves are migrated only when loading; they are never written back.
const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"
const TEMP_PATH := "user://renew_save.tmp.json"
const SCHEMA_VERSION := 8

static func save_game(state: Dictionary) -> bool:
    var game_state = _game_state()
    var payload:Dictionary = game_state.capture() if game_state != null else _canonicalize_input(state)
    payload["schema_version"] = SCHEMA_VERSION
    payload.erase("state_version")
    payload.erase("legacy")
    var json := JSON.stringify(payload)
    var temp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null: return false
    temp.store_string(json);temp.flush();temp=null
    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
        if DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),ProjectSettings.globalize_path(BACKUP_PATH))!=OK:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH));return false
    if FileAccess.file_exists(SAVE_PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH),ProjectSettings.globalize_path(SAVE_PATH))!=OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH));return false
    return true

static func load_game() -> Dictionary:
    var state:=_read_dictionary(SAVE_PATH)
    if state.is_empty():state=_read_dictionary(BACKUP_PATH)
    if state.is_empty():return {}
    var schema:=int(state.get("schema_version",0))
    var game_state=_game_state()
    if game_state!=null:
        if schema==SCHEMA_VERSION and state.get("domains",null) is Dictionary:
            game_state.restore(state)
        elif schema>=0 and schema<SCHEMA_VERSION:
            game_state.restore(_migrate_legacy(state))
        else:return {}
    elif schema!=SCHEMA_VERSION:return {}
    if game_state!=null:
        return game_state.capture()
    return state

static func _migrate_legacy(state:Dictionary)->Dictionary:
    ## Migration-only adapter. Its output is immediately converted to the
    ## canonical domain schema and is not persisted alongside the new save.
    var migrated:=state.duplicate(true)
    if migrated.has("game_state") and migrated["game_state"] is Dictionary:
        var nested=migrated["game_state"]
        if nested.has("domains") and nested["domains"] is Dictionary:
            return {"schema_version":SCHEMA_VERSION,"domains":nested["domains"]}
    migrated["schema_version"]=SCHEMA_VERSION
    return migrated

static func _canonicalize_input(state:Dictionary)->Dictionary:
    if state.has("domains") and state["domains"] is Dictionary:return {"schema_version":SCHEMA_VERSION,"domains":state["domains"].duplicate(true)}
    var domains:Dictionary={}
    var known=["player","company","properties","businesses","branches","employees","economy","resources","production","supply_chain","contracts","competitors","alliances","regions","technology","events","progression","history","news","analytics"]
    for domain in known:domains[domain]={}
    for key in state.keys():
        for domain in known:
            if key in ["day","reputation"] and domain=="player":domains[domain][key]=state[key]
            elif key in ["message","log_lines"] and domain=="company":domains[domain][key]=state[key]
            elif key in ["cash","last_sales","last_profit","total_profit"] and domain=="economy":domains[domain][key]=state[key]
            elif key=="resources" and domain=="resources":domains[domain][key]=state[key]
            elif key=="finished_goods" and domain=="production":domains[domain][key]=state[key]
            elif key in ["history_system"] and domain=="history":domains[domain][key]=state[key]
            elif key in ["news_system"] and domain=="news":domains[domain][key]=state[key]
    return {"schema_version":SCHEMA_VERSION,"domains":domains}

static func _read_dictionary(path:String)->Dictionary:
    if not FileAccess.file_exists(path):return {}
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null:return {}
    var parsed=JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
static func _root_node(name:String):
    var tree=Engine.get_main_loop()
    if tree==null:return null
    var root=tree.get_root()
    if root==null:return null
    var node=root.get_node_or_null(name)
    if node!=null:return node
    var scene=tree.get_current_scene()
    return scene.get_node_or_null(name) if scene!=null else null
static func _game_state():return _root_node("RenewGameState")
