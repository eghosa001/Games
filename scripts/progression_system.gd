extends Node
class_name RenewProgressionSystem

## Phase 22: company progression is earned from meaningful gameplay outcomes.
## XP and level live in GameState.progression; this node owns progression rules.

const LEVEL_THRESHOLDS := [0, 100, 250, 500, 900, 1400, 2000, 2800, 3800, 5000]
const XP_REWARDS := {"restoration_step":10,"property_operational":50,"profit_per_100":1,"contract_signed":25,"contract_completed":40,"employee_hired":15,"production_run":12,"expansion_purchased":35,"expansion_upgraded":20}
var state_adapter = null

func _ready() -> void:
    state_adapter = get_node_or_null("/root/RenewGameState")
    _ensure_state()
func _state():
    if state_adapter == null: state_adapter = get_node_or_null("/root/RenewGameState")
    return state_adapter
func _ensure_state() -> void:
    var state=_state(); if state==null:return
    if state.get_value("progression","xp",null)==null:state.set_value("progression","xp",0)
    if state.get_value("progression","level",null)==null:state.set_value("progression","level",1)
    if state.get_value("progression","milestones",null)==null:state.set_value("progression","milestones",[])
    if state.get_value("progression","unlocks",null)==null:state.set_value("progression","unlocks",[])
func get_xp()->int:return int(_state().get_value("progression","xp",0)) if _state()!=null else 0
func get_level()->int:return int(_state().get_value("progression","level",1)) if _state()!=null else 1
func get_next_level_xp()->int:
    var level:=get_level();return LEVEL_THRESHOLDS[level] if level<LEVEL_THRESHOLDS.size() else -1
func get_progress()->Dictionary:
    var level:=get_level();var current_threshold:=LEVEL_THRESHOLDS[level-1] if level>0 and level-1<LEVEL_THRESHOLDS.size() else 0;var next_threshold:=LEVEL_THRESHOLDS[level] if level<LEVEL_THRESHOLDS.size() else -1
    return {"xp":get_xp(),"level":level,"current_threshold":current_threshold,"next_threshold":next_threshold,"max_level":LEVEL_THRESHOLDS.size()}
func award_xp(amount:int,reason:String)->Dictionary:
    if amount<=0:return {"ok":false,"xp":get_xp(),"level":get_level()}
    var state=_state();if state==null:return {"ok":false,"reason":"game_state_unavailable"}
    var before_level:=get_level();var xp:=get_xp()+amount;state.set_value("progression","xp",xp);var new_level:=_level_for_xp(xp);state.set_value("progression","level",new_level)
    if new_level>before_level:
        _record_unlocks(before_level,new_level);state.log_message("PROGRESSION: Company reached Level %d (+%d XP from %s)."%[new_level,amount,reason]);state.message("Company Level %d reached. Your empire is growing."%new_level)
    return {"ok":true,"xp":xp,"level":new_level,"level_up":new_level>before_level,"reason":reason}
func award_action(action:String,multiplier:float=1.0)->Dictionary:
    var amount:=int(round(float(XP_REWARDS.get(action,0))*max(0.0,multiplier)));return award_xp(amount,action)
func award_profit(profit:int)->Dictionary:
    if profit<=0:return {"ok":false,"xp":get_xp(),"level":get_level()}
    return award_xp(max(1,int(floor(float(profit)/100.0))),"profit of $%d"%profit)
func has_unlock(unlock_id:String)->bool:
    var state=_state();if state==null:return false
    var unlocks=state.get_value("progression","unlocks",[]);return unlocks is Array and unlock_id in unlocks
func _level_for_xp(xp:int)->int:
    var result:=1
    for index in LEVEL_THRESHOLDS.size():
        if xp>=LEVEL_THRESHOLDS[index]:result=index+1
    return min(result,LEVEL_THRESHOLDS.size())
func _record_unlocks(old_level:int,new_level:int)->void:
    var state=_state();if state==null:return
    var unlocks=state.get_value("progression","unlocks",[]);if not unlocks is Array:unlocks=[];unlocks=unlocks.duplicate(true)
    for level in range(old_level+1,new_level+1):
        var unlock_id:="company_level_%d"%level
        if unlock_id not in unlocks:unlocks.append(unlock_id)
    state.set_value("progression","unlocks",unlocks)
