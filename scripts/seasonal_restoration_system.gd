extends Node

## Phase 27 — one seasonal LiveOps restoration event.
## The special property is intentionally separate from the permanent property
## catalog so the seasonal asset cannot be mistaken for a normal acquisition.
const EVENT_ID := "heritage_restoration_festival"
const PROPERTY_ID := "heritage_museum_house"
const PROPERTY := {"id":PROPERTY_ID,"name":"Heritage Museum House","type":"Heritage Property","description":"A historic building opened temporarily for the Heritage Restoration Festival.","value":95000}
const REQUIREMENTS := {"cleaning":500,"repair":900,"painting":600,"furnishing":700}
const REWARD := {"decoration":"Heritage Festival Plaque","achievement":"heritage_restorer","museum_item":"Festival Restoration Blueprint"}

func _ready() -> void:
    var state=_state()
    if state!=null:
        var seasonal=state.get_value("events","seasonal",{})
        if not seasonal is Dictionary or seasonal.is_empty():
            _set_seasonal({"event_id":EVENT_ID,"active":true,"property":PROPERTY.duplicate(true),"progress":{"cleaning":0,"repair":0,"painting":0,"furnishing":0},"requirements":REQUIREMENTS.duplicate(true),"completed":false,"reward":REWARD.duplicate(true)})
            _log("LIVEOPS: Heritage Restoration Festival has opened the Heritage Museum House.")

func is_active()->bool:
    var s=_seasonal(); return bool(s.get("active",false)) and not bool(s.get("completed",false))

func get_event()->Dictionary:return _seasonal()
func get_property()->Dictionary:return PROPERTY.duplicate(true)
func get_requirements()->Dictionary:return REQUIREMENTS.duplicate(true)

func restore_step(step:String)->Dictionary:
    if not REQUIREMENTS.has(step):return {"ok":false,"reason":"invalid_step"}
    var state=_state();if state==null:return {"ok":false,"reason":"state_unavailable"}
    var seasonal=_seasonal()
    if not bool(seasonal.get("active",false)):return {"ok":false,"reason":"event_inactive"}
    if bool(seasonal.get("completed",false)):return {"ok":false,"reason":"already_complete"}
    var progress:Dictionary=seasonal.get("progress",{}).duplicate(true)
    var next=_next_step(progress)
    if next!=step:return {"ok":false,"reason":"step_locked","required_step":next}
    var cash=int(state.get_value("economy","cash",25000));var cost=int(REQUIREMENTS[step])
    if cash<cost:return {"ok":false,"reason":"insufficient_cash","cost":cost,"cash":cash}
    state.set_value("economy","cash",cash-cost)
    progress[step]=100
    seasonal["progress"]=progress
    if _all_complete(progress):_complete(state,seasonal)
    else:
        _set_seasonal(seasonal)
        _log("FESTIVAL: %s restored to 100%% (-$%d)." % [step.capitalize(),cost])
    return {"ok":true,"property":PROPERTY.duplicate(true),"progress":progress.duplicate(true),"completed":bool(seasonal.get("completed",false))}

func restore_next() -> Dictionary:
    var step = _next_step(_seasonal().get("progress", {}))
    if step.is_empty():
        return {"ok": false, "reason": "complete"}
    return restore_step(step)
func _complete(state,seasonal:Dictionary)->void:
    seasonal["completed"]=true;seasonal["active"]=false;seasonal["completed_day"]=int(state.get_value("player","day",1));seasonal["decoration"]=REWARD["decoration"];seasonal["achievement"]=REWARD["achievement"];seasonal["museum_item"]=REWARD["museum_item"]
    _set_seasonal(seasonal)
    var history=state.get_value("company","log_lines",[]);if not history is Array:history=[];history=history.duplicate(true);history.append("HISTORY: Heritage Restoration Festival completed at %s." % PROPERTY["name"]);history.append("MUSEUM: %s added." % REWARD["museum_item"]);if history.size()>100:history.pop_front();state.set_value("company","log_lines",history)
    state.set_value("player","reputation",int(state.get_value("player","reputation",0))+10)
    state.set_value("company","message","Heritage Restoration Festival complete! %s awarded; museum item added: %s." % [REWARD["decoration"],REWARD["museum_item"]])

func _next_step(progress)->String:
    for step in ["cleaning","repair","painting","furnishing"]:
        if int(progress.get(step,0))<100:return step
    return ""
func _all_complete(progress)->bool:return _next_step(progress).is_empty()
func _state() -> Node:
    return get_node_or_null("/root/RenewGameState")
func _seasonal()->Dictionary:
    var state = _state()
    if state == null:
        return {}
    var value = state.get_value("events", "seasonal", {})
    if value is Dictionary:
        return value.duplicate(true)
    return {}
func _set_seasonal(value:Dictionary)->void:
    var state=_state();if state!=null:state.set_value("events","seasonal",value)
func _log(text:String)->void:
    var state=_state();if state==null:return
    var logs=state.get_value("company","log_lines",[]);if not logs is Array:logs=[];logs=logs.duplicate(true);logs.append(text);if logs.size()>100:logs.pop_front();state.set_value("company","log_lines",logs)
