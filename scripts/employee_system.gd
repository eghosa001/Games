extends Node
class_name RenewEmployeeSystem

const SYSTEM_VERSION := 3
const JAMES_ID := "emp_james_001"
var employees: Array = []
var candidates: Array = []
var next_id: int = 1
var history: Array = []
var _day: Variant = 1
const FIRST_NAMES := ["David", "Sarah", "Michael", "Grace", "Daniel", "Amaka", "Victor", "Esther", "Samuel", "Ada"]
const ROLES := ["Technician", "Sales Associate", "Logistics Coordinator", "Craft Worker", "Operations Assistant"]
const SPECIALIZATIONS := ["restoration", "sales", "logistics", "manufacturing", "operations"]

func _ready() -> void:
    if employees.is_empty(): _create_initial_roster()
    else: _normalize_roster()
    refresh_candidates()

func _create_initial_roster() -> void:
    employees.clear()
    employees.append(_make_employee(JAMES_ID, "James", "Worker", "manufacturing", {"production":58,"logistics":35,"management":25}, 6, 450, 82, 78, 0.82, 76, 1, "factory_001", 1))
    employees.append(_make_employee("emp_0002", "David", "Craft Worker", "manufacturing", {"production":48,"logistics":40,"management":22}, 10, 420, 68, 72, 0.70, 55, 1, "factory_001", 1))
    employees.append(_make_employee("emp_0003", "Sarah", "Sales Associate", "sales", {"production":35,"logistics":45,"management":30}, 8, 400, 71, 74, 0.73, 66, 1, "retail_001", 1))
    next_id = 4
    _record(JAMES_ID, "hired", {"reason":"founding roster"})
    _record("emp_0002", "hired", {"reason":"founding roster"})
    _record("emp_0003", "hired", {"reason":"founding roster"})

func _make_employee(id:String,name:String,role:String,specialization:String,skills:Dictionary,experience:int,salary:int,loyalty:int,morale:int,productivity:float,ambition:int,level:int,assignment:String,hire_date:int)->Dictionary:
    return {"id":id,"name":name,"role":role,"level":level,"skills":skills.duplicate(true),"experience":experience,"salary":salary,"loyalty":loyalty,"morale":morale,"productivity":clamp(productivity,0.2,1.0),"specialization":specialization,"status":"active","assignment":assignment,"ambition":ambition,"personality":_personality_for(name),"hire_date":hire_date,"promotion_date":0,"relationships":{},"history":[]}

func _personality_for(name:String)->String:
    match name:
        "James": return "Loyal, ambitious, dependable"
        "David": return "Steady, practical, patient"
        "Sarah": return "Social, competitive, optimistic"
    return "Adaptable, hardworking, curious"

func refresh_candidates()->void:
    candidates.clear()
    for i in range(4):
        var n:String=FIRST_NAMES[(i+_day)%FIRST_NAMES.size()]
        var role:String=ROLES[(i+_day)%ROLES.size()]
        var spec:String=SPECIALIZATIONS[(i+_day)%SPECIALIZATIONS.size()]
        var base_skill:int=40+((i*9+_day*3)%31)
        candidates.append({"id":"candidate_%d_%d"%[_day,i],"name":n,"role":role,"level":1,"skills":{"production":base_skill,"logistics":max(20,base_skill-10),"management":max(10,base_skill-25)},"experience":3+i*4,"salary":360+i*55,"loyalty":50+i*4,"morale":70,"productivity":0.55+i*0.05,"ambition":50+i*7,"specialization":spec,"status":"candidate","assignment":"factory_001"})

func get_active_employee_count()->int:
    var count:=0
    for employee in employees:
        if employee.get("status","active")=="active": count+=1
    return count
func active_count()->int: return get_active_employee_count()
func total_salary()->int: return get_daily_wage_total()
func get_daily_wage_total()->int:
    var total:=0
    for employee in employees:
        if employee.get("status","active")=="active": total+=int(employee.get("salary",0))
    return total
func total_productivity()->float:
    var total:=0.0
    for employee in employees:
        if employee.get("status","active")=="active": total+=float(employee.get("productivity",0.0))
    return total

func get_morale_multiplier()->float:
    var active:=get_active_employee_count()
    if active<=0: return 0.75
    var total:=0.0
    for employee in employees:
        if employee.get("status","active")=="active": total+=float(employee.get("morale",70))
    var morale:=total/float(active)
    if morale>=90.0: return 1.10
    if morale>=70.0: return 1.00
    if morale>=50.0: return 0.90
    return 0.75

func _assignment_skill(employee:Dictionary,assignment:String)->float:
    var skills:Dictionary=employee.get("skills",{})
    var key:="production"
    var normalized:=assignment.to_lower()
    if normalized.find("logistics")>=0 or normalized.find("fleet")>=0: key="logistics"
    elif normalized.find("hq")>=0 or normalized.find("management")>=0 or normalized.find("executive")>=0: key="management"
    elif normalized.find("retail")>=0 or normalized.find("sales")>=0: key="production"
    return float(skills.get(key,0))/100.0

func get_productivity_multiplier(assignment:String="factory_001")->float:
    var active:=get_active_employee_count()
    if active<=0: return 0.55
    var total:=0.0
    for employee in employees:
        if employee.get("status","active")!="active": continue
        var employee_assignment:=str(employee.get("assignment",""))
        var assigned_match:=employee_assignment.is_empty() or employee_assignment==assignment
        if not assigned_match: continue
        var skill_factor:=_assignment_skill(employee,assignment)
        var loyalty_factor:=0.85+float(employee.get("loyalty",50))/100.0*0.15
        total+=float(employee.get("productivity",0.75))*(0.65+skill_factor*0.35)*loyalty_factor
    if total<=0.0:
        for employee in employees:
            if employee.get("status","active")=="active": total+=float(employee.get("productivity",0.75))*0.65
    return clamp(total/max(1.0,float(active)),0.35,1.50)

func get_employee(employee_id:String)->Dictionary:
    for employee in employees:
        if employee.get("id","")==employee_id: return employee
    return {}
func get_roster()->Array[Dictionary]: return employees.duplicate(true)
func get_candidates()->Array[Dictionary]: return candidates.duplicate(true)

func hire_candidate(candidate_id:String,day:int)->Dictionary:
    for candidate in candidates:
        if candidate.get("id","")!=candidate_id: continue
        var id:="emp_%04d"%next_id; next_id+=1
        var employee:=_make_employee(id,str(candidate["name"]),str(candidate["role"]),str(candidate["specialization"]),candidate.get("skills",{}),int(candidate["experience"]),int(candidate["salary"]),int(candidate["loyalty"]),int(candidate["morale"]),float(candidate["productivity"]),int(candidate["ambition"]),1,"factory_001",day)
        employees.append(employee); _record(id,"hired",{"candidate_id":candidate_id}); refresh_candidates()
        var recruitment_factor:=1.0+float(max(0,80-int(employee["loyalty"]))) / 200.0
        return {"ok":true,"employee":employee.duplicate(true),"cost":int(round((1200+(get_active_employee_count()-1)*250)*recruitment_factor))}
    return {"ok":false,"message":"Candidate is no longer available."}
func hire_default(day:int)->Dictionary:
    if candidates.is_empty(): refresh_candidates()
    return hire_candidate(str(candidates[0]["id"]),day)

func fire_employee(employee_id:String,day:int)->Dictionary:
    var employee:=get_employee(employee_id)
    if employee.is_empty(): return {"ok":false,"message":"Employee not found."}
    if employee_id==JAMES_ID: return {"ok":false,"message":"James is a core story character and cannot be casually dismissed."}
    if employee.get("status","active")!="active": return {"ok":false,"message":"Employee is not active."}
    employee["status"]="fired"; employee["morale"]=max(0,int(employee["morale"])-20); employee["loyalty"]=max(0,int(employee["loyalty"])-30)
    _record(employee_id,"fired",{"day":day}); return {"ok":true,"message":"%s was dismissed. Remaining staff morale took a hit."%employee["name"]}

func train_employee(employee_id:String,day:int,cost:int=900)->Dictionary:
    var employee:=get_employee(employee_id)
    if employee.is_empty() or employee.get("status","active")!="active": return {"ok":false,"message":"Employee is not active."}
    var skills:Dictionary=employee.get("skills",{}).duplicate(true)
    var primary:=str(employee.get("specialization","manufacturing"))
    var skill_key:="production" if primary=="manufacturing" or primary=="production" else ("logistics" if primary=="logistics" else ("management" if primary=="operations" else "production"))
    skills[skill_key]=min(100,int(skills.get(skill_key,0))+6); employee["skills"]=skills
    employee["experience"]=int(employee["experience"])+2; employee["productivity"]=min(1.0,float(employee["productivity"])+0.05)
    employee["morale"]=min(100,int(employee["morale"])+5); employee["loyalty"]=min(100,int(employee["loyalty"])+4)
    _record(employee_id,"trained",{"day":day,"cost":cost,"skill":skill_key}); return {"ok":true,"cost":cost,"employee":employee.duplicate(true)}

func promote_employee(employee_id:String,day:int)->Dictionary:
    var employee:=get_employee(employee_id)
    if employee.is_empty() or employee.get("status","active")!="active": return {"ok":false,"message":"Employee is not active."}
    var level:=int(employee.get("level",1))
    if level>=4: return {"ok":false,"message":"%s is already at the highest career level."%employee["name"]}
    if int(employee["experience"])<level*10 and employee_id!=JAMES_ID: return {"ok":false,"message":"More experience is needed before promotion."}
    level+=1; employee["level"]=level; employee["promotion_date"]=day; employee["salary"]=int(employee["salary"])+140+level*30
    employee["morale"]=min(100,int(employee["morale"])+12); employee["loyalty"]=min(100,int(employee["loyalty"])+8)
    if employee_id==JAMES_ID and level>=4:
        employee["role"]="COO"; employee["specialization"]="executive_operations"; employee["assignment"]="hq_001"
    elif level==2: employee["role"]="Senior "+str(employee["role"])
    elif level==3: employee["role"]="Supervisor"
    _record(employee_id,"promoted",{"day":day,"level":level}); return {"ok":true,"employee":employee.duplicate(true),"message":"%s promoted to %s."%[employee["name"],employee["role"]]}

func assign_employee(employee_id:String,assignment:String,day:int)->Dictionary:
    var employee:=get_employee(employee_id)
    if employee.is_empty() or employee.get("status","active")!="active": return {"ok":false,"message":"Employee is not active."}
    employee["assignment"]=assignment; _record(employee_id,"assigned",{"day":day,"assignment":assignment}); return {"ok":true,"employee":employee.duplicate(true)}

func change_relationship(employee_a:String,employee_b:String,amount:int,day:int)->void:
    var a:=get_employee(employee_a); var b:=get_employee(employee_b)
    if a.is_empty() or b.is_empty(): return
    var relationships:Dictionary=a.get("relationships",{}); relationships[employee_b]=clamp(int(relationships.get(employee_b,50))+amount,0,100); a["relationships"]=relationships
    _record(employee_a,"relationship_changed",{"day":day,"other":employee_b,"amount":amount})

func daily_update(day:int,company_performance:int=0)->Dictionary:
    _day=day; var warnings:Array[String]=[]; var resignations:Array[String]=[]
    for employee in employees:
        if employee.get("status","active")!="active": continue
        employee["experience"]=int(employee["experience"])+1
        var morale_delta:=1 if company_performance>=0 else -2
        employee["morale"]=clamp(int(employee["morale"])+morale_delta,0,100)
        if int(employee["morale"])<35: employee["loyalty"]=max(0,int(employee["loyalty"])-2); warnings.append("%s is becoming unhappy."%employee["name"])
        var skills:Dictionary=employee.get("skills",{}); var production_skill:=int(skills.get("production",0)); var logistics_skill:=int(skills.get("logistics",0)); var management_skill:=int(skills.get("management",0))
        var primary_skill:=production_skill
        if str(employee.get("specialization",""))=="logistics": primary_skill=logistics_skill
        elif str(employee.get("specialization","")) in ["operations","executive_operations"]: primary_skill=management_skill
        var performance:=primary_skill+int(employee["morale"])/2+int(employee["loyalty"])/2
        var skill_bonus:=float(max(production_skill,max(logistics_skill,management_skill)))/100.0
        employee["productivity"]=clamp(float(performance)/200.0+skill_bonus*0.15,0.2,1.0)
        var loyalty:=int(employee["loyalty"]); var morale:=int(employee["morale"])
        if loyalty<30 and morale<40 and employee.get("id","")!=JAMES_ID and randi_range(1,100)<=12:
            employee["status"]="resigned"; resignations.append(str(employee["name"])); _record(str(employee["id"]),"resigned",{"day":day,"loyalty":loyalty,"morale":morale})
        elif loyalty<50 and randi_range(1,100)<=4: warnings.append("%s has a high resignation risk."%employee["name"])
        elif loyalty<=80 and randi_range(1,100)<=1: warnings.append("%s may consider outside offers."%employee["name"])
        if int(employee["ambition"])>=80 and int(employee.get("level",1))<4 and int(employee["experience"])%12==0: warnings.append("%s is ready for a career conversation."%employee["name"])
    refresh_candidates()
    sync_roster_to_state()
    return {"warnings":warnings,"resignations":resignations,"salary":get_daily_wage_total(),"productivity":total_productivity()}

func poach_candidate(employee_id:String,rival_name:String,day:int)->Dictionary:
    var employee:=get_employee(employee_id)
    if employee.is_empty() or employee.get("status","active")!="active": return {"ok":false}
    var loyalty:=int(employee.get("loyalty",50)); var risk:=int(employee.get("ambition",50))+(100-loyalty)
    if loyalty>80 or risk<100: return {"ok":false,"message":"%s resisted a poaching attempt by %s."%[employee["name"],rival_name]}
    employee["loyalty"]=max(0,loyalty-12); employee["morale"]=max(0,int(employee["morale"])-8)
    _record(employee_id,"poaching_attempt",{"day":day,"rival":rival_name,"loyalty":loyalty}); return {"ok":true,"message":"%s is considering an offer from %s."%[employee["name"],rival_name]}

func counter_offer(employee_id:String,day:int)->Dictionary:
    var employee:=get_employee(employee_id)
    if employee.is_empty() or employee.get("status","active")!="active": return {"ok":false}
    employee["salary"]=int(employee["salary"])+100; employee["loyalty"]=min(100,int(employee["loyalty"])+15); employee["morale"]=min(100,int(employee["morale"])+10)
    _record(employee_id,"counter_offer",{"day":day}); return {"ok":true,"salary":employee["salary"]}

func capture_state()->Dictionary:
    return {"system_version":SYSTEM_VERSION,"employees":employees.duplicate(true),"candidates":candidates.duplicate(true),"next_id":next_id,"history":history.duplicate(true),"day":_day}
func restore_state(snapshot:Dictionary)->void:
    if snapshot.is_empty(): _create_initial_roster(); refresh_candidates(); return
    employees.clear()
    for employee in snapshot.get("employees",[]):
        if employee is Dictionary: employees.append(employee.duplicate(true))
    candidates.clear()
    for candidate in snapshot.get("candidates",[]):
        if candidate is Dictionary: candidates.append(candidate.duplicate(true))
    next_id=int(snapshot.get("next_id",employees.size()+1))
    history.clear()
    for entry in snapshot.get("history",[]):
        if entry is Dictionary: history.append(entry.duplicate(true))
    _day=int(snapshot.get("day",1))
    if employees.is_empty(): _create_initial_roster()
    _normalize_roster(); _ensure_james(); refresh_candidates()
func migrate_legacy_count(count:int,day:int=1)->void:
    if employees.is_empty(): _create_initial_roster()
    while get_active_employee_count()<max(3,count):
        var result:=hire_default(day)
        if not result.get("ok",false): break
func _normalize_roster()->void:
    for employee in employees:
        if not employee.has("skills"):
            var old_skill:=int(employee.get("skill",50)); employee["skills"]={"production":old_skill,"logistics":max(0,old_skill-10),"management":max(0,old_skill-25)}
        employee.erase("skill")
        if not employee.has("level"): employee["level"]=int(employee.get("career_level",1))
        employee.erase("career_level")
        if not employee.has("productivity"): employee["productivity"]=0.75
        elif float(employee["productivity"])>1.0: employee["productivity"]=float(employee["productivity"])/100.0
        if not employee.has("status"): employee["status"]="active"
        if not employee.has("assignment"): employee["assignment"]="factory_001"
        if not employee.has("specialization"): employee["specialization"]="manufacturing"
        if not employee.has("relationships"): employee["relationships"]={}
        if not employee.has("history"): employee["history"]=[]
        if not employee.has("loyalty"): employee["loyalty"]=50
        if not employee.has("morale"): employee["morale"]=70
func _ensure_james()->void:
    if not get_employee(JAMES_ID).is_empty(): return
    employees.push_front(_make_employee(JAMES_ID,"James","Worker","manufacturing",{"production":58,"logistics":35,"management":25},6,450,82,78,0.82,76,1,"factory_001",1)); _record(JAMES_ID,"restored_identity",{})
func _record(employee_id:String,event_type:String,details:Dictionary)->void:
    var entry:Dictionary={"employee_id":employee_id,"type":event_type,"details":details}; history.append(entry)
    var employee:=get_employee(employee_id)
    if not employee.is_empty():
        var employee_history:Array=employee.get("history",[]); employee_history.append(entry.duplicate(true)); employee["history"]=employee_history

func sync_roster_to_state()->void:
    var state=get_node_or_null("/root/RenewGameState")
    if state:
        state.set_value("employees","roster",get_roster())
