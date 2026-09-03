extends Node

## RENEW DAILY: personalized newspaper generated only from verified simulation events.
## Phase 30: HistorySystem emits gameplay_event_recorded and this system subscribes to it.
const SYSTEM_VERSION := 3
const MAX_ARCHIVE := 2000
const MAX_STORIES_PER_ISSUE := 12
const SECTIONS := ["Your Company", "People", "Market", "Rivals", "Supply Chain", "Contracts", "Opportunities", "Regions", "World", "Corporate History"]
var archive:Array[Dictionary]=[]
var current_issue:Dictionary={}
var _last_day:=-1
var _seen_sources:Dictionary={}
func _ready()->void:
    call_deferred("_initialize_from_game");call_deferred("_connect_history")
func _process(_delta:float)->void:_watch_day()
func _initialize_from_game()->void:
    var state=get_node_or_null("/root/RenewGameState");var main=_main();var day:=int(state.get_value("player","day",1)) if state!=null else (int(main.get("day")) if main!=null else 1);if _last_day<0:_last_day=day;if current_issue.is_empty():generate_daily(day)
func _connect_history()->void:
    var history=get_node_or_null("/root/RenewHistorySystem")
    if history!=null and history.has_signal("gameplay_event_recorded"):
        var callable:=Callable(self,"_on_history_event");if not history.gameplay_event_recorded.is_connected(callable):history.gameplay_event_recorded.connect(callable)
func _on_history_event(event:Dictionary)->void:
    var event_day:=int(event.get("day",_last_day if _last_day>0 else 1));if _last_day<0:_last_day=event_day
    if current_issue.is_empty() or int(current_issue.get("day",-1))!=event_day:generate_daily(event_day)
    var story:=_history_story(event,event_day,0);if story.is_empty():return
    story["story_id"]="news_%06d"%(archive.size()+1);var stories:Array=current_issue.get("stories",[]).duplicate(true);stories.append(story);stories.sort_custom(func(a,b):return int(a.get("score",0))>int(b.get("score",0)))
    var kept:Array[Dictionary]=[];var section_counts:Dictionary={}
    for candidate in stories:
        var section:=str(candidate.get("section","Your Company"));var count:int=int(section_counts.get(section,0));if count>=3:continue
        kept.append(candidate);section_counts[section]=count+1;if kept.size()>=MAX_STORIES_PER_ISSUE:break
    current_issue["stories"]=kept;_sync_archive_issue()
func _sync_archive_issue()->void:
    var day:=int(current_issue.get("day",-1))
    for i in range(archive.size()-1,-1,-1):
        if int(archive[i].get("day",-1))==day:archive[i]=current_issue.duplicate(true);return
    archive.append(current_issue.duplicate(true));if archive.size()>MAX_ARCHIVE:archive.pop_front()
func _watch_day()->void:
    var state=get_node_or_null("/root/RenewGameState");var main=_main();if state==null and main==null:return
    var day:=int(state.get_value("player","day",1)) if state!=null else int(main.get("day"));if _last_day<0:_last_day=day;return
    if day!=_last_day:_last_day=day;generate_daily(day)
func generate_daily(day:int)->Dictionary:
    _seen_sources.clear();var candidates:=_collect_events(day);candidates.sort_custom(func(a,b):return int(a.get("score",0))>int(b.get("score",0)));var stories:Array[Dictionary]=[];var used_sections:Dictionary={}
    for candidate in candidates:
        if stories.size()>=MAX_STORIES_PER_ISSUE:break
        var section:=str(candidate.get("section","Your Company"));var count:int=int(used_sections.get(section,0));if count>=3:continue
        var story:=candidate.duplicate(true);story.erase("score");story["day"]=day;story["story_id"]="news_%06d"%(archive.size()+stories.size()+1);stories.append(story);used_sections[section]=count+1
    current_issue={"system_version":SYSTEM_VERSION,"day":day,"date_label":"Day %d"%day,"stories":stories,"verified_only":true};_sync_archive_issue();return current_issue.duplicate(true)
func get_current_issue()->Dictionary:return current_issue.duplicate(true)
func get_archive(limit:int=30)->Array[Dictionary]:
    var result:Array[Dictionary]=[];var start:=max(0,archive.size()-max(1,limit));for i in range(archive.size()-1,start-1,-1):result.append(archive[i].duplicate(true));return result
func get_issue(day:int)->Dictionary:
    if int(current_issue.get("day",-1))==day:return current_issue.duplicate(true)
    for issue in archive:
        if int(issue.get("day",-1))==day:return issue.duplicate(true)
    return {}
func capture_state()->Dictionary:return {"system_version":SYSTEM_VERSION,"archive":archive.duplicate(true),"current_issue":current_issue.duplicate(true),"last_day":_last_day}
func restore_state(snapshot:Dictionary)->void:
    archive=snapshot.get("archive",[]).duplicate(true);current_issue=snapshot.get("current_issue",{}).duplicate(true);_last_day=int(snapshot.get("last_day",-1));_seen_sources.clear()
    for issue in archive:
        for story in issue.get("stories",[]):
            var source:=str(story.get("source_key",""));if not source.is_empty():_seen_sources[source]=true
    if current_issue.is_empty() and not archive.is_empty():current_issue=archive.back().duplicate(true)
func _collect_events(day:int)->Array[Dictionary]:
    var result:Array[Dictionary]=[];var main=_main();var history=get_node_or_null("/root/RenewHistorySystem");var employees=get_node_or_null("/root/RenewEmployeeSystem")
    if history!=null:
        for event in history.get_timeline("",120):
            var event_day:=int(event.get("day",1));if event_day>day or day-event_day>7:continue
            var story:=_history_story(event,day,day-event_day);if not story.is_empty():result.append(story)
    if employees!=null:
        var employee_history=employees.get("history")
        if employee_history is Array:
            for event in employee_history:
                var event_day:=int(event.get("day",1));if event_day>day or day-event_day>3:continue
                var story:=_employee_story(event,day);if not story.is_empty():result.append(story)
    if main!=null:
        var logs=main.get("log_lines")
        if logs is Array:
            for i in range(max(0,logs.size()-25),logs.size()):
                var story:=_log_story(str(logs[i]),day);if not story.is_empty():result.append(story)
    return result
func _history_story(event:Dictionary,day:int,age:int)->Dictionary:
    var kind:=str(event.get("type","general"));var gameplay_event:=str(event.get("details",{}).get("gameplay_event",""));var title:=str(event.get("title","Historic event"));var details:Dictionary=event.get("details",{});var section:="Corporate History";var score:=int(event.get("importance",1))*15+(25 if age==0 else 10)
    if not gameplay_event.is_empty():
        match gameplay_event:
            "FOUNDING","PROPERTY_RESTORED","BUSINESS_OPENED","FIRST_PRODUCTION","FIRST_SALE","FIRST_PROFIT":section="Your Company"
            "PROPERTY_ACQUIRED":section="Regions"
            "EMPLOYEE_HIRED","EMPLOYEE_PROMOTED":section="People"
            "CONTRACT_SIGNED","CONTRACT_FULFILLED":section="Contracts"
            "TECHNOLOGY_RESEARCHED":section="Market"
            "ALLIANCE_FORMED","COMPETITOR_DEFEATED":section="Rivals"
            "PROJECT_COMPLETED":section="Regions"
            "MAJOR_EVENT":section="World"
    else:
        match kind:
            "employee_milestone":section="People"
            "contract":section="Contracts"
            "resource_acquisition":section="Supply Chain"
            "alliance","acquisition","merger","corporate_war":section="Rivals"
            "world_event":section="World"
            "ranking","technology":section="Market"
            "expansion","property_acquisition":section="Regions"
            "investment","infrastructure","first_sale","first_profit","restoration","founding","crisis","bankruptcy","milestone":section="Your Company"
    var body:=title
    if gameplay_event=="EMPLOYEE_PROMOTED":
        var name:=str(details.get("employee_name",details.get("name","Employee")));var role:=str(details.get("new_role",details.get("role",details.get("milestone","Factory Manager"))));body="%s has been promoted to %s."%[name,role]
    elif gameplay_event=="EMPLOYEE_HIRED":
        var name:=str(details.get("employee_name",details.get("name","Employee")));body="%s has joined RENEW."%name
    return _make_story(section,_kicker(gameplay_event,kind),title,body,score,"history|%s"%str(event.get("id",title)))
func _employee_story(event:Dictionary,_day:int)->Dictionary:
    var employee_id:=str(event.get("employee_id",""));var employee=_employee_by_id(employee_id);var name:=str(event.get("employee_name",employee.get("name","Employee")));var action:=str(event.get("action",event.get("type","milestone")));var role:=str(employee.get("role","team member"));var title:="%s — %s"%[name,action.replace("_"," ").capitalize()];var body:="%s, RENEW %s, had a verified personnel event: %s."%[name,role,_details(event)];var score:=52 if action!="promoted" else 90;return _make_story("People","People desk",title,body,score,"employee|%s|%s|%s"%[employee_id,action,str(event.get("day",1))])
func _log_story(text:String,day:int)->Dictionary:
    var upper:=text.to_upper();var section:="";var kicker:="";var score:=0
    if upper.begins_with("CONTRACT:"):section="Contracts";kicker="Contracts desk";score=70
    elif upper.begins_with("SUPPLY ORDER:"):section="Supply Chain";kicker="Supply desk";score=60
    elif upper.begins_with("ALLIANCE:") or upper.begins_with("RELATIONSHIP:"):section="Rivals";kicker="Corporate desk";score=58
    elif upper.begins_with("ACQUISITION:") or upper.begins_with("CORPORATE WAR:"):section="Rivals";kicker="Competitive desk";score=88
    elif upper.begins_with("EVENT:"):section="World";kicker="World desk";score=64
    elif upper.begins_with("TAKEOVER ATTEMPT:"):section="Rivals";kicker="Breaking";score=96
    elif upper.begins_with("TECHNOLOGY:") or upper.begins_with("UPGRADE:"):section="Market";kicker="Industry desk";score=55
    elif upper.begins_with("TRANSPORT:"):section="Supply Chain";kicker="Logistics desk";score=55
    elif upper.begins_with("MARKETING:"):section="Market";kicker="Market desk";score=45
    else:return {}
    return _make_story(section,kicker,text,"Reported from the live RENEW simulation log.",score,"log|%d|%s"%[day,text])
func _make_story(section:String,kicker:String,headline:String,body:String,score:int,source_key:String)->Dictionary:
    if section.is_empty() or headline.is_empty() or source_key.is_empty() or _seen_sources.has(source_key):return {}
    _seen_sources[source_key]=true;return {"section":section,"kicker":kicker,"headline":headline,"body":body,"source_key":source_key,"score":score}
func _kicker(gameplay_event:String,kind:String)->String:
    if not gameplay_event.is_empty():
        match gameplay_event:
            "FOUNDING":return "Company desk"
            "PROPERTY_ACQUIRED","PROPERTY_RESTORED":return "Property desk"
            "BUSINESS_OPENED","FIRST_PRODUCTION","FIRST_SALE","FIRST_PROFIT":return "Business desk"
            "EMPLOYEE_HIRED","EMPLOYEE_PROMOTED":return "People desk"
            "CONTRACT_SIGNED","CONTRACT_FULFILLED":return "Contracts desk"
            "TECHNOLOGY_RESEARCHED":return "Industry desk"
            "ALLIANCE_FORMED","COMPETITOR_DEFEATED":return "Competitive desk"
            "PROJECT_COMPLETED":return "Regional desk"
            "MAJOR_EVENT":return "World desk"
    match kind:
        "founding":return "Company desk"
        "restoration":return "Restoration desk"
        "first_sale","first_profit":return "Business desk"
        "employee_milestone":return "People desk"
        "contract":return "Contracts desk"
        "resource_acquisition":return "Supply desk"
        "alliance","acquisition","merger","corporate_war":return "Competitive desk"
        "crisis","bankruptcy":return "Breaking"
        "technology","infrastructure":return "Industry desk"
        "ranking":return "Markets desk"
        "world_event":return "World desk"
    return "Corporate desk"
func _details(details:Dictionary)->String:
    if details.is_empty():return "Verified gameplay event."
    var parts:Array[String]=[]
    for key in details.keys():
        if str(key) in ["source_log","employee_id","employee_name","gameplay_event"]:continue
        parts.append("%s: %s"%[str(key).replace("_"," ").capitalize(),str(details[key])])
    return "; ".join(parts) if not parts.is_empty() else "Verified gameplay event."
func _employee_by_id(employee_id:String)->Dictionary:
    var employees=get_node_or_null("/root/RenewEmployeeSystem");if employees==null or not employees.has_method("get_employee"):return {};return employees.get_employee(employee_id)
func _main() -> Node:
    var tree:=get_tree();if tree==null:return null
    return tree.current_scene
