extends Node
class_name RenewHistorySystem

## Permanent corporate memory. Gameplay systems call record_gameplay_event(); UI never writes history.
const SYSTEM_VERSION := 2
const MAX_EVENTS := 5000
const GAMEPLAY_EVENTS := ["FOUNDING","PROPERTY_ACQUIRED","PROPERTY_RESTORED","BUSINESS_OPENED","FIRST_PRODUCTION","FIRST_SALE","FIRST_PROFIT","EMPLOYEE_HIRED","EMPLOYEE_PROMOTED","CONTRACT_SIGNED","CONTRACT_FULFILLED","TECHNOLOGY_RESEARCHED","ALLIANCE_FORMED","PROJECT_COMPLETED","COMPETITOR_DEFEATED","MAJOR_EVENT"]
const TYPES := ["founding","restoration","first_sale","first_profit","employee_milestone","contract","property_acquisition","expansion","resource_acquisition","alliance","acquisition","merger","crisis","bankruptcy","technology","infrastructure","ranking","world_event","investment","corporate_war","milestone","general"]
var timeline:Array[Dictionary]=[]
var legacy:Dictionary={"founder":"","company_name":"RENEW","founded_day":1,"notable_events":0,"properties_acquired":0,"expansions":0,"alliances":0,"acquisitions":0,"contracts":0,"crises":0,"employees_milestones":0,"museum_unlocks":[]}
var _seen_signatures:Dictionary={}

func _ready()->void:
    if timeline.is_empty(): record_gameplay_event("FOUNDING",1,"RENEW was founded.",{"legacy":true},"company_founded")

func record_gameplay_event(event_name:String,day:int,title:String,details:Dictionary={},signature:String="")->Dictionary:
    if not GAMEPLAY_EVENTS.has(event_name): return {}
    var mapped:Dictionary={"FOUNDING":"founding","PROPERTY_ACQUIRED":"property_acquisition","PROPERTY_RESTORED":"restoration","BUSINESS_OPENED":"founding","FIRST_PRODUCTION":"milestone","FIRST_SALE":"first_sale","FIRST_PROFIT":"first_profit","EMPLOYEE_HIRED":"employee_milestone","EMPLOYEE_PROMOTED":"employee_milestone","CONTRACT_SIGNED":"contract","CONTRACT_FULFILLED":"contract","TECHNOLOGY_RESEARCHED":"technology","ALLIANCE_FORMED":"alliance","PROJECT_COMPLETED":"infrastructure","COMPETITOR_DEFEATED":"corporate_war","MAJOR_EVENT":"world_event"}
    var payload:=details.duplicate(true);payload["gameplay_event"]=event_name
    return record(mapped[event_name],day,title,payload,signature if not signature.is_empty() else "%s|%d|%s"%[event_name,day,title])

func record(event_type:String,day:int,title:String,details:Dictionary={},signature:String="")->Dictionary:
    var kind:=event_type if TYPES.has(event_type) else "general"
    var key:=signature if not signature.is_empty() else "%s|%s|%s"%[kind,day,title]
    if _seen_signatures.has(key): return _seen_signatures[key]
    var event:Dictionary={"id":"hist_%06d"%(timeline.size()+1),"day":max(1,day),"type":kind,"title":title,"details":details.duplicate(true),"importance":_importance(kind),"recorded_at":Time.get_datetime_string_from_system(true)}
    timeline.append(event)
    if timeline.size()>MAX_EVENTS: timeline.pop_front()
    _seen_signatures[key]=event;_update_legacy(kind);return event

func record_employee_milestone(day:int,employee_id:String,employee_name:String,milestone:String,details:Dictionary={})->Dictionary:
    var payload:=details.duplicate(true);payload["employee_id"]=employee_id;payload["employee_name"]=employee_name;payload["milestone"]=milestone
    return record_gameplay_event("EMPLOYEE_PROMOTED" if milestone.to_lower().contains("promot") else "EMPLOYEE_HIRED",day,"%s: %s"%[employee_name,milestone],payload,"employee|%s|%s|%s"%[employee_id,milestone,day])

func ingest_activity_log(lines:Array,day:int)->int:
    var added:=0
    for line in lines:
        var text:=str(line);var mapped:=_classify_log(text)
        if mapped.is_empty():continue
        var before:=timeline.size();record(str(mapped["type"]),day,str(mapped["title"]),{"source_log":text},str(mapped["signature"]))
        if timeline.size()>before:added+=1
    return added

func get_timeline(filter_type:String="",limit:int=100)->Array[Dictionary]:
    var result:Array[Dictionary]=[];var start:=max(0,timeline.size()-max(1,limit))
    for i in range(timeline.size()-1,start-1,-1):
        var event:=timeline[i]
        if filter_type.is_empty() or str(event.get("type",""))==filter_type:result.append(event.duplicate(true))
    return result
func get_chronological_timeline()->Array[Dictionary]:return timeline.duplicate(true)
func get_notable_events(limit:int=20)->Array[Dictionary]:
    var result:Array[Dictionary]=[]
    for i in range(timeline.size()-1,-1,-1):
        if int(timeline[i].get("importance",1))>=3:result.append(timeline[i].duplicate(true));if result.size()>=limit:break
    return result
func get_museum_collection()->Array[Dictionary]:
    var result:Array[Dictionary]=[]
    for event in timeline:
        if int(event.get("importance",1))>=3:result.append({"id":event.get("id",""),"day":event.get("day",1),"era":_era(int(event.get("day",1))),"title":event.get("title",""),"type":event.get("type","general"),"details":event.get("details",{}).duplicate(true)})
    return result
func get_legacy_summary()->Dictionary:
    var result:=legacy.duplicate(true);result["timeline_length"]=timeline.size();result["museum_items"]=get_museum_collection().size();result["years_recorded"]=max(1,int(ceil(float(_latest_day())/365.0)));return result
func has_event(event_type:String,title_contains:String="")->bool:
    for event in timeline:
        if str(event.get("details",{}).get("gameplay_event",event.get("type","")))!=event_type:continue
        if title_contains.is_empty() or str(event.get("title","")).to_lower().contains(title_contains.to_lower()):return true
    return false
func capture_state()->Dictionary:return {"system_version":SYSTEM_VERSION,"timeline":timeline.duplicate(true),"legacy":legacy.duplicate(true)}
func restore_state(snapshot:Dictionary)->void:
    if snapshot.is_empty():timeline.clear();legacy["notable_events"]=0;_seen_signatures.clear();_ready();return
    timeline=snapshot.get("timeline",[]).duplicate(true);legacy=snapshot.get("legacy",legacy).duplicate(true);_seen_signatures.clear()
    for event in timeline:_seen_signatures["%s|%s|%s"%[event.get("type","general"),event.get("day",1),event.get("title","")]]=event

func _classify_log(text:String)->Dictionary:
    var upper:=text.to_upper()
    if upper.begins_with("ACQUIRED:"):return {"type":"property_acquisition","title":text,"signature":"log|"+text}
    if upper.begins_with("RESTORATION:") or upper.contains("RESTORATION COMPLETE"):return {"type":"restoration","title":text,"signature":"log|"+text}
    if upper.begins_with("PRODUCTION:"):return {"type":"milestone","title":text,"signature":"log|"+text}
    if upper.begins_with("SUPPLY ORDER:"):return {"type":"resource_acquisition","title":text,"signature":"log|"+text}
    if upper.begins_with("CONTRACT:"):return {"type":"contract","title":text,"signature":"log|"+text}
    if upper.begins_with("ALLIANCE:") or upper.begins_with("RELATIONSHIP:"):return {"type":"alliance","title":text,"signature":"log|"+text}
    if upper.begins_with("ACQUISITION:"):return {"type":"acquisition","title":text,"signature":"log|"+text}
    if upper.begins_with("EVENT:"):return {"type":"world_event","title":text,"signature":"log|"+text}
    if upper.begins_with("CORPORATE WAR:"):return {"type":"corporate_war","title":text,"signature":"log|"+text}
    if upper.begins_with("TAKEOVER ATTEMPT:"):return {"type":"crisis","title":text,"signature":"log|"+text}
    if upper.begins_with("INVESTMENT:"):return {"type":"investment","title":text,"signature":"log|"+text}
    if upper.begins_with("UPGRADE:") or upper.begins_with("TRANSPORT:"):return {"type":"infrastructure","title":text,"signature":"log|"+text}
    if upper.begins_with("MARKETING:") or upper.begins_with("TECHNOLOGY:"):return {"type":"technology","title":text,"signature":"log|"+text}
    if upper.begins_with("MILESTONE:"):return {"type":"milestone","title":text,"signature":"log|"+text}
    return {}
func _importance(kind:String)->int:
    match kind:
        "founding","first_sale","first_profit","bankruptcy","merger","acquisition","corporate_war":return 5
        "restoration","property_acquisition","employee_milestone","expansion","alliance","crisis","ranking","world_event","milestone":return 4
        "contract","resource_acquisition","technology","infrastructure","investment":return 3
    return 1
func _update_legacy(kind:String)->void:
    legacy["notable_events"]=int(legacy.get("notable_events",0))+1
    match kind:
        "property_acquisition":legacy["properties_acquired"]=int(legacy.get("properties_acquired",0))+1
        "expansion":legacy["expansions"]=int(legacy.get("expansions",0))+1
        "alliance":legacy["alliances"]=int(legacy.get("alliances",0))+1
        "acquisition","merger":legacy["acquisitions"]=int(legacy.get("acquisitions",0))+1
        "contract":legacy["contracts"]=int(legacy.get("contracts",0))+1
        "crisis","bankruptcy":legacy["crises"]=int(legacy.get("crises",0))+1
        "employee_milestone":legacy["employees_milestones"]=int(legacy.get("employees_milestones",0))+1
func _latest_day()->int:return 1 if timeline.is_empty() else int(timeline.back().get("day",1))
func _era(day:int)->String:return "Year %d"%(int(floor(float(max(1,day)-1)/365.0))+1)
