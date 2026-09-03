extends Node

## Central gameplay-to-history adapter. UI code never creates history entries.
var _snapshots:Dictionary={}

func _ready()->void:
    set_process(true)

func _process(_delta:float)->void:
    var history=get_node_or_null("/root/RenewHistorySystem")
    var state=get_node_or_null("/root/RenewGameState")
    if history==null or state==null or not history.has_method("record"):return
    var day:=int(state.get_value("player","day",1))
    _transition(history,"property_acquired",bool(state.get_value("properties","owned",false)),day,"PROPERTY_ACQUIRED","Property acquired",{})
    _transition(history,"property_restored",str(state.get_value("properties","stage",""))=="Operational",day,"PROPERTY_RESTORED","Property fully restored",{})
    _transition(history,"business_opened",bool(state.get_value("businesses","business_open",false)),day,"BUSINESS_OPENED","Business opened",{"business":state.get_value("businesses","business_name","")})
    _counter(history,"finished_goods",int(state.get_value("production","finished_goods",0)),day,"FIRST_PRODUCTION","First production completed",{})
    _counter(history,"last_sales",int(state.get_value("economy","last_sales",0)),day,"FIRST_SALE","First sale completed",{"sales":state.get_value("economy","last_sales",0)})
    _counter(history,"total_profit",int(state.get_value("economy","total_profit",0)),day,"FIRST_PROFIT","First profit recorded",{"profit":state.get_value("economy","total_profit",0)})
    _array_counter(history,"employees",state.get_value("employees","roster",[]),day,"EMPLOYEE_HIRED","Employee hired")
    _contract_events(history,state,day)
    _technology_events(history,state,day)
    _alliance_events(history,state,day)
    _project_events(history,state,day)
    _competitor_events(history,state,day)
    _major_events(history,state,day)

func _transition(history,key:String,now:bool,day:int,event_name:String,title:String,details:Dictionary)->void:
    if not _snapshots.has(key):_snapshots[key]=now;return
    if now and not bool(_snapshots[key]):_record(history,event_name,day,title,details,key)
    _snapshots[key]=now

func _counter(history,key:String,now:int,day:int,event_name:String,title:String,details:Dictionary)->void:
    if not _snapshots.has(key):_snapshots[key]=now;return
    if now>int(_snapshots[key]) and int(_snapshots[key])<=0:_record(history,event_name,day,title,details,key)
    _snapshots[key]=now

func _array_counter(history,key:String,value,day:int,event_name:String,title:String)->void:
    var count:=value.size() if value is Array else 0
    if not _snapshots.has(key):_snapshots[key]=count;return
    if count>int(_snapshots[key]):_record(history,event_name,day,title,{"count":count},key)
    _snapshots[key]=count

func _contract_events(history,state,day:int)->void:
    var contracts=state.get_value("contracts","system",{})
    if not contracts is Dictionary:return
    var signed=int(contracts.get("signed_count",contracts.get("active_count",0)))
    var fulfilled=int(contracts.get("fulfilled_count",contracts.get("completed_count",0)))
    _counter(history,"contracts_signed",signed,day,"CONTRACT_SIGNED","Contract signed",{"count":signed})
    _counter(history,"contracts_fulfilled",fulfilled,day,"CONTRACT_FULFILLED","Contract fulfilled",{"count":fulfilled})

func _technology_events(history,state,day:int)->void:
    var tech=state.get_value("technology","technology",{})
    if not tech is Dictionary:return
    var count:=0
    for id in tech.keys():
        if tech[id] is Dictionary and bool(tech[id].get("researched",false)):count+=1
        elif tech[id] is bool and tech[id]:count+=1
    _counter(history,"technologies_researched",count,day,"TECHNOLOGY_RESEARCHED","Technology researched",{"count":count})

func _alliance_events(history,state,day:int)->void:
    var alliances=state.get_value("alliances","alliances",{})
    if not alliances is Dictionary:return
    var count:=alliances.size()
    _counter(history,"alliances_formed",count,day,"ALLIANCE_FORMED","Alliance formed",{"count":count})
    var completed:=0
    for id in alliances.keys():
        var a=alliances[id]
        if not a is Dictionary:continue
        var projects=a.get("projects",{})
        if projects is Dictionary:
            for pid in projects.keys():
                if projects[pid] is Dictionary and str(projects[pid].get("status",""))=="complete":completed+=1
    _counter(history,"projects_completed",completed,day,"PROJECT_COMPLETED","Cooperative project completed",{"count":completed})

func _project_events(history,state,day:int)->void:
    # Kept as a dedicated hook so future cooperative projects can expose a direct counter.
    var reputation=int(state.get_value("regions","regional_reputation",0))
    _counter(history,"regional_reputation",reputation,day,"PROJECT_COMPLETED","Regional cooperative project completed",{"regional_reputation":reputation})

func _competitor_events(history,state,day:int)->void:
    var rivals=state.get_value("competitors","rivals",[])
    if not rivals is Array:return
    var defeated:=0
    for rival in rivals:
        if rival is Dictionary and (bool(rival.get("defeated",false)) or str(rival.get("status",""))=="defeated"):defeated+=1
    _counter(history,"competitors_defeated",defeated,day,"COMPETITOR_DEFEATED","Competitor defeated",{"count":defeated})

func _major_events(history,state,day:int)->void:
    var active=state.get_value("events","active",{})
    if active is Dictionary and not active.is_empty():
        var event_id:=str(active.get("id",""));if not event_id.is_empty() and str(_snapshots.get("major_event_id",""))!=event_id:
            _record(history,"MAJOR_EVENT",day,str(active.get("title","Major event")),{"event_id":event_id,"effects":active.get("effects",{})},"major_event|"+event_id);_snapshots["major_event_id"]=event_id

func _record(history,event_name:String,day:int,title:String,details:Dictionary,key:String)->void:
    if history.has_method("record_gameplay_event"):history.record_gameplay_event(event_name,day,title,details,"phase28|%s|%s"%[key,event_name])
    else:history.record("general",day,title,details,"phase28|%s|%s"%[key,event_name])
