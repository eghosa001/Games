extends Node
class_name RenewGameState

const STATE_VERSION := 3
const BUSINESS_ID := "renew_goods"
const CORE_PROPERTY_ID := "old_warehouse"
var data: Dictionary = {}
var dirty := false

func new_game() -> Dictionary:
    data = {"schema_version":STATE_VERSION,"state_version":STATE_VERSION,"meta":{"created_at":Time.get_datetime_string_from_system(true),"last_saved_at":""},"clock":{"day":1},"player":{"cash":25000,"reputation":0},"company":{"id":BUSINESS_ID,"name":"RENEW Goods","founded_day":1},"properties":{},"businesses":{},"branches":{},"employees":{"next_id":1,"records":{}},"economy":{},"resources":{},"production":{},"supply_chain":{},"contracts":{},"competitors":{},"ownership":{},"finance":{},"alliances":{},"diplomacy":{},"regions":{},"infrastructure":{},"technology":{},"events":{},"progression":{},"history":[],"news":{"editions":[]},"analytics":{},"legacy":{"employee_count":3}}
    _ensure_business_record(); _ensure_property_record(CORE_PROPERTY_ID); dirty=true
    return data.duplicate(true)

func capture(core: Dictionary) -> Dictionary:
    var snapshot := data.duplicate(true) if not data.is_empty() else new_game()
    _merge_legacy_core(snapshot,core)
    snapshot["schema_version"]=STATE_VERSION; snapshot["state_version"]=STATE_VERSION; snapshot["meta"]["last_saved_at"]=Time.get_datetime_string_from_system(true)
    data=snapshot; dirty=false
    return data.duplicate(true)

func restore(snapshot: Dictionary) -> Dictionary:
    var migrated := _migrate(snapshot)
    if migrated.is_empty(): return {}
    data=migrated.duplicate(true); dirty=false
    return data.duplicate(true)

func get_business(business_id:String=BUSINESS_ID)->Dictionary:
    _ensure_business_record(business_id); return data["businesses"][business_id].duplicate(true)
func set_business_value(key:String,value,business_id:String=BUSINESS_ID)->void:
    _ensure_business_record(business_id); data["businesses"][business_id][key]=value; dirty=true
func set_business_values(values:Dictionary,business_id:String=BUSINESS_ID)->void:
    _ensure_business_record(business_id)
    for key in values.keys(): data["businesses"][business_id][key]=values[key]
    dirty=true

func get_property(property_id:String)->Dictionary:
    _ensure_property_record(property_id); return data["properties"][property_id].duplicate(true)
func set_property_value(property_id:String,key:String,value)->void:
    _ensure_property_record(property_id); data["properties"][property_id][key]=value; dirty=true
func set_property_values(property_id:String,values:Dictionary)->void:
    _ensure_property_record(property_id)
    for key in values.keys(): data["properties"][property_id][key]=values[key]
    dirty=true
func sync_property_runtime(core:Dictionary,property_id:String=CORE_PROPERTY_ID)->void:
    _ensure_property_record(property_id)
    var record:Dictionary=data["properties"][property_id]
    for key in ["owned","inspected","restoration","stage"]:
        if core.has(key): record[key]=core[key]
    record["active"]=bool(core.get("business_open",record.get("active",false)))
    data["properties"][property_id]=record; dirty=true
func restore_property_runtime(core:Dictionary,property_id:String=CORE_PROPERTY_ID)->void:
    var record:=get_property(property_id)
    core["owned"]=bool(record.get("owned",false)); core["inspected"]=bool(record.get("inspected",false)); core["restoration"]=int(record.get("restoration",0)); core["stage"]=str(record.get("stage","Neglected"))

func sync_business_runtime(core:Dictionary,business_id:String=BUSINESS_ID)->void:
    _ensure_business_record(business_id)
    var record:Dictionary=data["businesses"][business_id]
    var defaults:={"open":false,"capacity_level":1,"marketing_level":0,"price":110,"finished_goods":0,"last_sales":0,"last_profit":0,"total_profit":0,"contract_days":0,"contract_bonus":0}
    var mapping:={"open":"business_open","capacity_level":"capacity_level","marketing_level":"marketing_level","price":"player_price","finished_goods":"finished_goods","last_sales":"last_sales","last_profit":"last_profit","total_profit":"total_profit","contract_days":"contract_days","contract_bonus":"contract_bonus"}
    for key in defaults.keys():
        var source_key:String=mapping[key]
        if core.has(source_key): record[key]=core[source_key]
        elif not record.has(key): record[key]=defaults[key]
    data["businesses"][business_id]=record; dirty=true
func restore_business_runtime(core:Dictionary,business_id:String=BUSINESS_ID)->void:
    var record:=get_business(business_id)
    core["business_open"]=bool(record.get("open",false)); core["capacity_level"]=int(record.get("capacity_level",1)); core["marketing_level"]=int(record.get("marketing_level",0)); core["player_price"]=int(record.get("price",110)); core["finished_goods"]=int(record.get("finished_goods",0)); core["last_sales"]=int(record.get("last_sales",0)); core["total_profit"]=int(record.get("total_profit",0)); core["last_profit"]=int(record.get("last_profit",0)); core["contract_days"]=int(record.get("contract_days",0)); core["contract_bonus"]=int(record.get("contract_bonus",0))

func mark_dirty()->void: dirty=true
func has_state()->bool: return not data.is_empty()
func get_value(path:Array,fallback=null):
    var cursor=data
    for key in path:
        if not (cursor is Dictionary) or not cursor.has(key): return fallback
        cursor=cursor[key]
    return cursor
func set_value(path:Array,value)->void:
    if path.is_empty(): return
    if data.is_empty(): new_game()
    var cursor:Dictionary=data
    for i in range(path.size()-1):
        var key=path[i]
        if not cursor.has(key) or not (cursor[key] is Dictionary): cursor[key]={}
        cursor=cursor[key]
    cursor[path[path.size()-1]]=value; dirty=true
func clear()->void: data.clear(); dirty=false

func _ensure_business_record(business_id:String=BUSINESS_ID)->void:
    if data.is_empty(): return
    if not data.has("businesses") or not (data["businesses"] is Dictionary): data["businesses"]={}
    if not data["businesses"].has(business_id) or not (data["businesses"][business_id] is Dictionary): data["businesses"][business_id]={"id":business_id,"open":false,"capacity_level":1,"marketing_level":0,"price":110,"finished_goods":0,"last_sales":0,"last_profit":0,"total_profit":0,"contract_days":0,"contract_bonus":0}
func _ensure_property_record(property_id:String)->void:
    if data.is_empty(): return
    if not data.has("properties") or not (data["properties"] is Dictionary): data["properties"]={}
    if not data["properties"].has(property_id) or not (data["properties"][property_id] is Dictionary): data["properties"][property_id]={"id":property_id,"owned":false,"inspected":false,"restoration":0,"stage":"Neglected","active":false}

func _merge_legacy_core(snapshot:Dictionary,core:Dictionary)->void:
    for key in core.keys():
        if key != "employees" and key != "branches" and key not in ["business_open","capacity_level","marketing_level","player_price","finished_goods","last_sales","last_profit","total_profit","contract_days","contract_bonus","owned","inspected","restoration","stage"]: snapshot[key]=core[key]
    if not snapshot.has("clock") or not (snapshot["clock"] is Dictionary): snapshot["clock"]={}
    if not snapshot.has("player") or not (snapshot["player"] is Dictionary): snapshot["player"]={}
    if not snapshot.has("legacy") or not (snapshot["legacy"] is Dictionary): snapshot["legacy"]={}
    snapshot["clock"]["day"]=int(core.get("day",snapshot["clock"].get("day",1))); snapshot["player"]["cash"]=int(core.get("cash",snapshot["player"].get("cash",0))); snapshot["player"]["reputation"]=int(core.get("reputation",snapshot["player"].get("reputation",0))); snapshot["legacy"]["employee_count"]=int(core.get("employees",snapshot["legacy"].get("employee_count",0))); snapshot["finance"]={"debt":int(core.get("debt",0)),"loan_payment":int(core.get("loan_payment",0))}
    _ensure_business_record_in_snapshot(snapshot); _ensure_property_record_in_snapshot(snapshot,CORE_PROPERTY_ID)
    var business:Dictionary=snapshot["businesses"][BUSINESS_ID]
    var business_map:={"open":"business_open","capacity_level":"capacity_level","marketing_level":"marketing_level","price":"player_price","finished_goods":"finished_goods","last_sales":"last_sales","last_profit":"last_profit","total_profit":"total_profit","contract_days":"contract_days","contract_bonus":"contract_bonus"}
    for key in business_map.keys():
        if core.has(business_map[key]): business[key]=core[business_map[key]]
        elif not business.has(key): business[key]=_business_default(key)
    snapshot["businesses"][BUSINESS_ID]=business
    var property:Dictionary=snapshot["properties"][CORE_PROPERTY_ID]
    for key in ["owned","inspected","restoration","stage"]:
        if core.has(key): property[key]=core[key]
    snapshot["properties"][CORE_PROPERTY_ID]=property
    if not snapshot.has("branches") or not (snapshot["branches"] is Dictionary): snapshot["branches"]={}
    if not snapshot.has("employees") or not (snapshot["employees"] is Dictionary): snapshot["employees"]={"next_id":1,"records":{}}
func _business_default(key:String):
    match key:
        "open": return false
        "capacity_level": return 1
        "marketing_level": return 0
        "price": return 110
        "finished_goods": return 0
        "last_sales": return 0
        "last_profit": return 0
        "total_profit": return 0
        "contract_days": return 0
        "contract_bonus": return 0
        _: return 0
func _ensure_business_record_in_snapshot(snapshot:Dictionary)->void:
    if not snapshot.has("businesses") or not (snapshot["businesses"] is Dictionary): snapshot["businesses"]={}
    if not snapshot["businesses"].has(BUSINESS_ID) or not (snapshot["businesses"][BUSINESS_ID] is Dictionary): snapshot["businesses"][BUSINESS_ID]={"id":BUSINESS_ID,"open":false,"capacity_level":1,"marketing_level":0,"price":110,"finished_goods":0,"last_sales":0,"last_profit":0,"total_profit":0,"contract_days":0,"contract_bonus":0}
func _ensure_property_record_in_snapshot(snapshot:Dictionary,property_id:String)->void:
    if not snapshot.has("properties") or not (snapshot["properties"] is Dictionary): snapshot["properties"]={}
    if not snapshot["properties"].has(property_id) or not (snapshot["properties"][property_id] is Dictionary): snapshot["properties"][property_id]={"id":property_id,"owned":false,"inspected":false,"restoration":0,"stage":"Neglected","active":false}

func _migrate(snapshot:Dictionary)->Dictionary:
    if not (snapshot is Dictionary) or snapshot.is_empty(): return {}
    var version:=int(snapshot.get("schema_version",snapshot.get("state_version",1)))
    if version>STATE_VERSION: return {}
    var migrated:=snapshot.duplicate(true)
    if version<3:
        var base:=new_game()
        for key in base.keys():
            if not migrated.has(key): migrated[key]=base[key]
    if not migrated.has("employees") or not (migrated["employees"] is Dictionary): migrated["employees"]={"next_id":1,"records":{}}
    if migrated["employees"].has("employees") and not migrated["employees"].has("records"): migrated["employees"]["records"]=migrated["employees"]["employees"]; migrated["employees"].erase("employees")
    if migrated.has("branches") and migrated["branches"] is Array:
        var branch_records:={}
        for index in range(migrated["branches"].size()):
            if migrated["branches"][index] is Dictionary: branch_records["branch_%d"%index]=migrated["branches"][index].duplicate(true)
        migrated["branches"]={"selected":0,"records":branch_records}
    elif not migrated.has("branches") or not (migrated["branches"] is Dictionary): migrated["branches"]={}
    _ensure_business_record_in_snapshot(migrated); _ensure_property_record_in_snapshot(migrated,CORE_PROPERTY_ID)
    var business:Dictionary=migrated["businesses"][BUSINESS_ID]
    var business_map:={"open":"business_open","capacity_level":"capacity_level","marketing_level":"marketing_level","price":"player_price","finished_goods":"finished_goods","last_sales":"last_sales","last_profit":"last_profit","total_profit":"total_profit","contract_days":"contract_days","contract_bonus":"contract_bonus"}
    for key in business_map.keys():
        if not business.has(key) and migrated.has(business_map[key]): business[key]=migrated[business_map[key]]
    migrated["businesses"][BUSINESS_ID]=business
    var property:Dictionary=migrated["properties"][CORE_PROPERTY_ID]
    for key in ["owned","inspected","restoration","stage"]:
        if not property.has(key) and migrated.has(key): property[key]=migrated[key]
    migrated["properties"][CORE_PROPERTY_ID]=property
    if not migrated.has("history") or not (migrated["history"] is Array): migrated["history"]=[]
    if not migrated.has("news") or not (migrated["news"] is Dictionary): migrated["news"]={"editions":[]}
    migrated["schema_version"]=STATE_VERSION; migrated["state_version"]=STATE_VERSION
    return migrated
