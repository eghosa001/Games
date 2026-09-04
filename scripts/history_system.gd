extends Node

## Permanent corporate memory. Gameplay systems call record_gameplay_event(); UI never writes history.
signal gameplay_event_recorded(event: Dictionary)
const SYSTEM_VERSION := 3
const MAX_EVENTS := 5000
const GAMEPLAY_EVENTS := ["FOUNDING","PROPERTY_ACQUIRED","PROPERTY_RESTORED","BUSINESS_OPENED","FIRST_PRODUCTION","FIRST_SALE","FIRST_PROFIT","EMPLOYEE_HIRED","EMPLOYEE_PROMOTED","CONTRACT_SIGNED","CONTRACT_FULFILLED","TECHNOLOGY_RESEARCHED","ALLIANCE_FORMED","PROJECT_COMPLETED","COMPETITOR_DEFEATED","MAJOR_EVENT"]
const EVENT_ALIASES := {"employee_milestone":"EMPLOYEE_PROMOTED","employee_promotion":"EMPLOYEE_PROMOTED","employee_hired":"EMPLOYEE_HIRED","property_acquired":"PROPERTY_ACQUIRED","property_restored":"PROPERTY_RESTORED","business_opened":"BUSINESS_OPENED","first_production":"FIRST_PRODUCTION","first_sale":"FIRST_SALE","first_profit":"FIRST_PROFIT","contract_signed":"CONTRACT_SIGNED","contract_fulfilled":"CONTRACT_FULFILLED","technology_researched":"TECHNOLOGY_RESEARCHED","alliance_formed":"ALLIANCE_FORMED","project_completed":"PROJECT_COMPLETED","competitor_defeated":"COMPETITOR_DEFEATED","major_event":"MAJOR_EVENT","founding":"FOUNDING"}
const TYPES := ["founding","restoration","first_sale","first_profit","employee_milestone","contract","property_acquisition","expansion","resource_acquisition","alliance","acquisition","merger","crisis","bankruptcy","technology","infrastructure","ranking","world_event","investment","corporate_war","milestone","general"]
var timeline:Array[Dictionary]=[]
var legacy:Dictionary={"founder":"","company_name":"RENEW","founded_day":1,"notable_events":0,"properties_acquired":0,"expansions":0,"alliances":0,"acquisitions":0,"contracts":0,"crises":0,"employees_milestones":0,"museum_unlocks":[]}
var _seen_signatures:Dictionary={}
func _ready()->void:
    if timeline.is_empty(): record_gameplay_event("FOUNDING",1,"RENEW was founded.",{"legacy":true},"company_founded")
func record_gameplay_event(event_name:String,day:int,title:String,details:Dictionary={},signature:String="")->Dictionary:
    var canonical:String=str(EVENT_ALIASES.get(event_name,event_name));var event:Dictionary={"type":_mapped_type(canonical),"event":canonical,"day":day,"title":title,"details":details.duplicate(true),"signature":signature}
    if signature.is_empty(): event["signature"]="%s|%s|%s"%[canonical,day,title]
    var key:String=str(event["signature"])
    if _seen_signatures.has(key): return _seen_signatures[key]
    timeline.append(event);_seen_signatures[key]=event;legacy["notable_events"]=timeline.size()
    if canonical=="PROPERTY_ACQUIRED": legacy["properties_acquired"]+=1
    elif canonical=="PROJECT_COMPLETED": legacy["expansions"]+=1
    elif canonical=="ALLIANCE_FORMED": legacy["alliances"]+=1
    elif canonical=="CONTRACT_SIGNED": legacy["contracts"]+=1
    elif canonical=="EMPLOYEE_HIRED" or canonical=="EMPLOYEE_PROMOTED": legacy["employees_milestones"]+=1
    elif canonical=="MAJOR_EVENT": legacy["crises"]+=1
    if timeline.size()>MAX_EVENTS: timeline=timeline.slice(timeline.size()-MAX_EVENTS)
    gameplay_event_recorded.emit(event)
    return event
func get_timeline()->Array[Dictionary]: return timeline
func get_recent(limit:int=20)->Array[Dictionary]: return timeline.slice(maxi(0,timeline.size()-limit))
func get_legacy_summary()->Dictionary:
    var result:Dictionary=legacy.duplicate(true);result["timeline_length"]=timeline.size();result["museum_items"]=get_museum_collection().size();result["years_recorded"]=max(1,int(ceil(float(_latest_day())/365.0)));return result
func has_event(event_type:String,title_contains:String="")->bool:
    var canonical:String=str(EVENT_ALIASES.get(event_type,event_type))
    for event:Dictionary in timeline:
        if str(event.get("details",{}).get("gameplay_event",event.get("type","")))!=canonical:continue
        if title_contains.is_empty() or str(event.get("title","")).to_lower().contains(title_contains.to_lower()):return true
    return false
func capture_state()->Dictionary:return {"system_version":SYSTEM_VERSION,"timeline":timeline.duplicate(true),"legacy":legacy.duplicate(true)}
func restore_state(snapshot:Dictionary)->void:
    if snapshot.is_empty():timeline.clear();legacy["notable_events"]=0;_seen_signatures.clear();_ready();return
    timeline.clear();var raw:Variant=snapshot.get("timeline",[])
    if raw is Array:
        for item:Variant in raw:
            if item is Dictionary: timeline.append((item as Dictionary).duplicate(true))
    legacy=snapshot.get("legacy",legacy).duplicate(true);_seen_signatures.clear()
    for event:Dictionary in timeline:
        var key:String=str(event.get("signature","%s|%s|%s"%[event.get("type","general"),event.get("day",1),event.get("title","")]))
        _seen_signatures[key]=event
func _mapped_type(canonical:String)->String:
    var mapped:Dictionary={"FOUNDING":"founding","PROPERTY_ACQUIRED":"property_acquisition","PROPERTY_RESTORED":"restoration","BUSINESS_OPENED":"founding","FIRST_PRODUCTION":"milestone","FIRST_SALE":"first_sale","FIRST_PROFIT":"first_profit","EMPLOYEE_HIRED":"employee_milestone","EMPLOYEE_PROMOTED":"employee_milestone","CONTRACT_SIGNED":"contract","CONTRACT_FULFILLED":"contract","TECHNOLOGY_RESEARCHED":"technology","ALLIANCE_FORMED":"alliance","PROJECT_COMPLETED":"infrastructure","COMPETITOR_DEFEATED":"corporate_war","MAJOR_EVENT":"world_event"};return str(mapped.get(canonical,"general"))
func _classify_log(text:String)->Dictionary:
    var upper:String=text.to_upper()
    if upper.begins_with("ACQUIRED:"):return {"type":"property_acquisition","title":text,"signature":"log|"+text}
    return {"type":"general","title":text,"signature":"log|"+text}
func get_museum_collection()->Array:
    return legacy.get("museum_unlocks",[])
func _latest_day()->int:
    var latest:int=1
    for event:Dictionary in timeline: latest=maxi(latest,int(event.get("day",1)))
    return latest
