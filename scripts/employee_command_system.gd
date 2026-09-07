extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const EmployeeSystem = preload("res://scripts/employee_system.gd")

var state_adapter = DomainSystem.new()
var employee_system = EmployeeSystem.new()

func _ready() -> void:
    add_child(state_adapter); add_child(employee_system); sync_roster()
func _culture(): return get_node_or_null("/root/RenewCompanyCultureSystem")
func _culture_effect(name:String, default_value:float=1.0)->float:
    var culture = _culture()
    if culture != null and culture.has_method("get_effects"):
        return float(culture.get_effects().get(name, default_value))
    return default_value
func get_active_employee_count()->int: return employee_system.get_active_employee_count()
func get_roster()->Array[Dictionary]:
    var roster: Array[Dictionary] = []
    for employee in employee_system.employees:
        if employee is Dictionary: roster.append(employee.duplicate(true))
    return roster
func get_daily_wage_total()->int: return employee_system.get_daily_wage_total()
func get_morale_multiplier()->float: return employee_system.get_morale_multiplier()
func get_productivity_multiplier(assignment:String="factory_001")->float: return employee_system.get_productivity_multiplier(assignment)
func hire_employee()->Dictionary:
    if not bool(state_adapter.get_value("businesses","business_open",false)):
        state_adapter.message("Open the business first.")
        return {"ok":false,"message":"Open the business first."}
    var day:=int(state_adapter.get_value("player","day",1)); var current_count:=employee_system.get_active_employee_count()
    var candidates:=employee_system.get_candidates()
    if candidates.is_empty(): employee_system.refresh_candidates(); candidates=employee_system.get_candidates()
    if candidates.is_empty():
        state_adapter.message("No candidates are available right now.")
        return {"ok":false,"message":"No candidates are available right now."}
    var candidate:Dictionary=candidates[0]
    var recruitment_factor:float=(1.0+float(max(0,80-int(candidate.get("loyalty",50))))/200.0) / _culture_effect("recruitment_multiplier")
    var preview_cost:=int(round((1200+current_count*250)*recruitment_factor*state_adapter.executive_bonus("hiring")))
    var cash:=int(state_adapter.get_value("economy","cash",25000))
    if cash<preview_cost:
        state_adapter.message("Hiring requires $%s."%state_adapter.money(preview_cost))
        return {"ok":false,"message":"Hiring requires $%s."%state_adapter.money(preview_cost),"cost":preview_cost}
    var result=employee_system.hire_candidate(str(candidate.get("id","")),day)
    if not bool(result.get("ok",false)):
        state_adapter.message(str(result.get("message","Unable to hire employee.")))
        return {"ok":false,"message":str(result.get("message","Unable to hire employee."))}
    var actual_cost:=preview_cost
    if actual_cost != preview_cost:
        employee_system.fire_employee(str(result["employee"]["id"]),day); state_adapter.message("Hiring cost changed; the candidate was not hired."); sync_roster()
        return {"ok":false,"message":"Hiring cost changed; the candidate was not hired."}
    var spend: Dictionary = state_adapter.spend(actual_cost,"employee hiring")
    if not bool(spend.get("ok",false)):
        employee_system.fire_employee(str(result["employee"]["id"]),day); state_adapter.message("Hiring cost changed and available cash is insufficient."); sync_roster()
        return {"ok":false,"message":"Hiring cost changed and available cash is insufficient."}
    sync_roster(); state_adapter.set_value("player","reputation",int(state_adapter.get_value("player","reputation",0))+1); state_adapter.log_message("HIRING: employee %d joined (-$%s)."%[employee_system.get_active_employee_count(),state_adapter.money(actual_cost)]); state_adapter.message("Employee hired. More capacity, higher daily wages."); var _rs=get_node_or_null("/root/RenewReputationSystem");if _rs!=null and _rs.has_method("adjust"):_rs.adjust("employee",2)
    return {"ok":true,"employee":result.get("employee",{}),"cost":actual_cost}
func appoint_executive(employee_id:String)->Dictionary:
    var day:=int(state_adapter.get_value("player","day",1))
    var seats:=state_adapter.executive_seats()
    var seat := ""
    for candidate_seat in ["CEO","COO","CFO","CTO"]:
        if not seats.has(candidate_seat):
            seat = candidate_seat
            break
    if seat.is_empty():
        state_adapter.message("Every C-suite seat is filled.")
        return {"ok":false,"message":"Every C-suite seat is filled."}
    var result=employee_system.appoint_executive(employee_id,seat,day)
    if not bool(result.get("ok",false)):
        state_adapter.message(str(result.get("message","Appointment failed.")))
        return result
    sync_roster()
    state_adapter.log_message("EXECUTIVE: %s." % str(result.get("message","Appointed.")))
    state_adapter.message(str(result.get("message","Appointed to the C-suite.")))
    return result
func train_employee(employee_id:String)->void:
    var day:=int(state_adapter.get_value("player","day",1)); var cost:=900
    var cash:=int(state_adapter.get_value("economy","cash",25000))
    if cash<cost: state_adapter.message("Training requires $%s."%state_adapter.money(cost)); return
    var spend: Dictionary = state_adapter.spend(cost,"employee training")
    if not bool(spend.get("ok",false)): state_adapter.message(str(spend.get("message","Training requires sufficient cash."))); return
    var result=employee_system.train_employee(employee_id,day,cost)
    if not bool(result.get("ok",false)): state_adapter.receive(cost,"employee training refund"); state_adapter.message(str(result.get("message","Training failed."))); return
    sync_roster(); state_adapter.message("Employee training completed.")
func promote_employee(employee_id:String)->void:
    var result=employee_system.promote_employee(employee_id,int(state_adapter.get_value("player","day",1)))
    if not bool(result.get("ok",false)): state_adapter.message(str(result.get("message","Promotion failed."))); return
    sync_roster(); state_adapter.message(str(result.get("message","Employee promoted.")))
func assign_employee(employee_id:String,assignment:String)->void:
    var result=employee_system.assign_employee(employee_id,assignment,int(state_adapter.get_value("player","day",1)))
    if not bool(result.get("ok",false)): state_adapter.message(str(result.get("message","Assignment failed."))); return
    sync_roster(); state_adapter.message("Employee assignment updated.")
func fire_employee(employee_id:String)->void:
    var result=employee_system.fire_employee(employee_id,int(state_adapter.get_value("player","day",1)))
    if not bool(result.get("ok",false)): state_adapter.message(str(result.get("message","Dismissal failed."))); return
    sync_roster(); state_adapter.message(str(result.get("message","Employee dismissed."))); var _rsf=get_node_or_null("/root/RenewReputationSystem");if _rsf!=null and _rsf.has_method("adjust"):_rsf.adjust("employee",-4)
func daily_update(company_performance:int=0)->Dictionary:
    var result:=employee_system.daily_update(int(state_adapter.get_value("player","day",1)),company_performance)
    var culture = _culture()
    if culture != null and culture.has_method("daily_update"): culture.daily_update(int(state_adapter.get_value("player","day",1)))
    sync_roster(); return result
func sync_roster()->void:
    var roster: Array[Dictionary] = []
    for employee in employee_system.employees:
        if employee is Dictionary: roster.append(employee.duplicate(true))
    state_adapter.set_value("employees","roster",roster)
func capture_state()->Dictionary:
    return {"employee_system":employee_system.capture_state() if employee_system.has_method("capture_state") else {}}
func restore_state(snapshot:Dictionary)->void:
    if snapshot.is_empty():return
    var saved=snapshot.get("employee_system",{})
    if saved is Dictionary and employee_system.has_method("restore_state"):employee_system.restore_state(saved)
    sync_roster()