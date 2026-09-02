extends RefCounted
class_name RenewSaveSystem

const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"
const TEMP_PATH := "user://renew_save.tmp.json"
const SCHEMA_VERSION := 4

static func save_game(state) -> Dictionary:
    var payload := _runtime_snapshot(state)
    if payload.is_empty(): return {"ok":false,"message":"No runtime state was supplied."}
    var game_state = _game_state()
    if game_state != null:
        game_state.sync_property_runtime(payload)
        game_state.sync_business_runtime(payload)
        var expansion = _expansion()
        if expansion != null: game_state.sync_expansion_runtime(expansion)
        payload = game_state.capture(payload)
    payload["schema_version"] = SCHEMA_VERSION; payload["state_version"] = SCHEMA_VERSION
    payload["save_metadata"] = {"saved_at":Time.get_datetime_string_from_system(true),"day":int(payload.get("day",payload.get("clock",{}).get("day",1)))}
    if not _validate(payload): return {"ok":false,"message":"Save validation failed."}
    var json := JSON.stringify(payload); var temp := FileAccess.open(TEMP_PATH,FileAccess.WRITE)
    if temp == null: return {"ok":false,"message":"Unable to create temporary save."}
    temp.store_string(json); temp.flush(); temp=null
    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
        if DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),ProjectSettings.globalize_path(BACKUP_PATH)) != OK:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH)); return {"ok":false,"message":"Unable to create save backup."}
    if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH),ProjectSettings.globalize_path(SAVE_PATH)) != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH)); return {"ok":false,"message":"Unable to activate save file."}
    return {"ok":true,"message":"Save written successfully.","day":int(payload.get("day",1))}

static func load_game() -> Dictionary:
    var state := _migrate(_read_dictionary(SAVE_PATH)); var source := "active"
    if state.is_empty(): state=_migrate(_read_dictionary(BACKUP_PATH)); source="backup"
    if state.is_empty() or not _validate(state): return {"ok":false,"message":"No valid save was found."}
    if source=="backup": state["recovery"]={"source":"backup","recovered_at":Time.get_datetime_string_from_system(true)}
    var game_state=_game_state()
    if game_state != null:
        game_state.restore(state)
        game_state.restore_property_runtime(state)
        game_state.restore_business_runtime(state)
        var expansion = _expansion()
        if expansion != null: game_state.restore_expansion_runtime(expansion)
    _restore_branch_controller(game_state)
    _restore_main_projection(state)
    var employee_count := 0
    if state.get("employees") is Dictionary:
        var employee_state:Dictionary=state["employees"]; var records=employee_state.get("records",{})
        employee_count=int(records.size()) if records is Dictionary else int(state.get("legacy",{}).get("employee_count",0))
    return {"ok":true,"message":"Save loaded from %s."%source,"employees":employee_count}

static func _runtime_snapshot(state)->Dictionary:
    if state is Dictionary: return state.duplicate(true)
    if not (state is Object): return {}
    var keys=["cash","reputation","day","debt","loan_payment","owned","inspected","restoration","stage","business_open","employees","capacity_level","marketing_level","player_price","finished_goods","last_sales","last_profit","total_profit","relationship","selected_rival","selected_expansion","supplier_choice","contract_days","contract_bonus","acquisition_count","transport_level","transport_capacity","selected_district","message","log_lines"]
    var snapshot:={}
    for key in keys:
        var value=state.get(key)
        if value != null: snapshot[key]=value
    return snapshot

static func _restore_main_projection(state:Dictionary)->void:
    var tree=Engine.get_main_loop()
    if tree==null:return
    var root=tree.get_root()
    if root==null:return
    var main=root.get_node_or_null("Main")
    if main==null:return
    var values={"cash":int(state.get("player",{}).get("cash",state.get("cash",main.cash))),"reputation":int(state.get("player",{}).get("reputation",state.get("reputation",main.reputation))),"day":int(state.get("clock",{}).get("day",state.get("day",main.day))),"debt":int(state.get("finance",{}).get("debt",state.get("debt",main.debt))),"loan_payment":int(state.get("finance",{}).get("loan_payment",state.get("loan_payment",main.loan_payment))),"relationship":int(state.get("relationship",main.relationship)),"selected_rival":int(state.get("selected_rival",main.selected_rival)),"selected_expansion":int(state.get("selected_expansion",main.selected_expansion)),"supplier_choice":int(state.get("supplier_choice",main.supplier_choice)),"acquisition_count":int(state.get("acquisition_count",main.acquisition_count)),"transport_level":int(state.get("transport_level",main.transport_level)),"transport_capacity":int(state.get("transport_capacity",main.transport_capacity)),"selected_district":int(state.get("selected_district",main.selected_district)),"message":str(state.get("message",main.message)),"log_lines":state.get("log_lines",main.log_lines)}
    for key in ["cash","reputation","day","debt","loan_payment","relationship","selected_rival","selected_expansion","supplier_choice","acquisition_count","transport_level","transport_capacity","selected_district","message","log_lines"]:
        main.set(key,values[key])
    main.set("employees",_employee_count(state))
    main.set("owned",bool(state.get("properties",{}).get("old_warehouse",{}).get("owned",main.owned)))
    main.set("inspected",bool(state.get("properties",{}).get("old_warehouse",{}).get("inspected",main.inspected)))
    main.set("restoration",int(state.get("properties",{}).get("old_warehouse",{}).get("restoration",main.restoration)))
    main.set("stage",str(state.get("properties",{}).get("old_warehouse",{}).get("stage",main.stage)))
    var business=state.get("businesses",{}).get("renew_goods",{})
    if business is Dictionary:
        main.set("business_open",bool(business.get("open",main.business_open))); main.set("capacity_level",int(business.get("capacity_level",main.capacity_level))); main.set("marketing_level",int(business.get("marketing_level",main.marketing_level))); main.set("player_price",int(business.get("price",main.player_price))); main.set("finished_goods",int(business.get("finished_goods",main.finished_goods))); main.set("last_sales",int(business.get("last_sales",main.last_sales))); main.set("last_profit",int(business.get("last_profit",main.last_profit))); main.set("total_profit",int(business.get("total_profit",main.total_profit))); main.set("contract_days",int(business.get("contract_days",main.contract_days))); main.set("contract_bonus",int(business.get("contract_bonus",main.contract_bonus)))

static func _employee_count(state:Dictionary)->int:
    var employees=state.get("employees",{})
    if employees is Dictionary:
        var records=employees.get("records",{})
        if records is Dictionary:return records.size()
    return int(state.get("legacy",{}).get("employee_count",0))

static func _restore_branch_controller(game_state)->void:
    var tree=Engine.get_main_loop()
    if tree==null:return
    var root=tree.get_root()
    if root==null:return
    var controller=root.get_node_or_null("Main/BranchController")
    if controller==null:return
    if game_state!=null and game_state.has_state():
        var saved=game_state.get_value(["branches"],{})
        if saved is Dictionary and not saved.is_empty(): controller.branches.restore_from_game_state(game_state)

static func _read_dictionary(path:String)->Dictionary:
    if not FileAccess.file_exists(path):return {}
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null:return {}
    var parsed=JSON.parse_string(file.get_as_text()); return parsed if parsed is Dictionary else {}
static func _migrate(state:Dictionary)->Dictionary:
    if state.is_empty():return {}
    var schema:=int(state.get("schema_version",state.get("state_version",1)))
    if schema>SCHEMA_VERSION:return {}
    var migrated:=state.duplicate(true)
    var game_state=_game_state()
    if game_state!=null:
        migrated=game_state.restore(migrated)
        if migrated.is_empty():return {}
    migrated["schema_version"]=SCHEMA_VERSION; migrated["state_version"]=SCHEMA_VERSION; return migrated
static func _validate(state:Dictionary)->bool:
    if int(state.get("schema_version",0))!=SCHEMA_VERSION:return false
    if not state.has("clock") or not (state["clock"] is Dictionary):return false
    if not state.has("player") or not (state["player"] is Dictionary):return false
    var day:=int(state.get("day",state["clock"].get("day",0))); var cash:=int(state.get("cash",state["player"].get("cash",0)))
    return day>=1 and cash>-1000000000
static func _game_state():
    var tree=Engine.get_main_loop()
    if tree==null:return null
    var root=tree.get_root()
    if root==null:return null
    return root.get_node_or_null("RenewGameState")
static func _expansion():
    var tree=Engine.get_main_loop()
    if tree==null:return null
    var root=tree.get_root()
    if root==null:return null
    var main=root.get_node_or_null("Main")
    if main==null:return null
    return main.get("expansion")
