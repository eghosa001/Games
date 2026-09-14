extends Node

const SYSTEM_VERSION := 1
const MODES := ["manual", "alert", "auto"]
var policies := {"procurement":"manual", "pricing":"manual", "maintenance":"manual"}
var cash_reserve := 7500
var last_day := -1
var alerts: Array = []
var last_actions: Array = []

func _ready() -> void:
    _load_policies()
    set_process(true)
    call_deferred("evaluate")

func _process(_delta: float) -> void:
    var state = _state()
    if state == null: return
    var day := int(state.get_value("player", "day", 1))
    if last_day < 0:
        last_day = day
    elif day != last_day:
        last_day = day
        run_daily()

func _state(): return get_node_or_null("/root/RenewGameState")
func _finance(): return get_node_or_null("/root/RenewFinanceSystem")
func _production(): return get_node_or_null("/root/RenewProductionSystem")
func _game():
    var tree := get_tree()
    return tree.current_scene if tree != null else null
func _commands():
    var game = _game()
    return game.get("command_system") if game != null else null

func _load_policies() -> void:
    var state = _state()
    if state == null: return
    for key in policies.keys():
        var mode := str(state.get_value("management", key + "_policy", policies[key]))
        if mode in MODES: policies[key] = mode
    cash_reserve = clampi(int(state.get_value("management", "cash_reserve", cash_reserve)), 0, 250000)

func _save_policies() -> void:
    var state = _state()
    if state == null: return
    for key in policies.keys(): state.set_value("management", key + "_policy", policies[key])
    state.set_value("management", "cash_reserve", cash_reserve)

func _executives() -> Dictionary:
    var commands = _commands()
    if commands != null:
        var employee = commands.get("employee_system")
        if employee != null and employee.has_method("get_executives"):
            return employee.get_executives()
    return {}

func _hq_stage() -> int:
    var registry = get_node_or_null("/root/RenewServices")
    if registry == null or not registry.has_method("get_service"): return 0
    var hq = registry.get_service("RenewHeadquartersSystem")
    return int(hq.get_stage_index()) if hq != null and hq.has_method("get_stage_index") else 0

func can_auto(policy: String) -> Dictionary:
    var seats := _executives()
    if policy == "procurement":
        return {"ok": seats.has("COO") or _hq_stage() >= 2, "reason":"Auto procurement requires a COO or Corporate Center HQ."}
    if policy == "pricing":
        return {"ok": seats.has("CFO") or seats.has("CEO") or _hq_stage() >= 2, "reason":"Auto pricing requires a CFO/CEO or Corporate Center HQ."}
    if policy == "maintenance":
        return {"ok": seats.has("COO") or seats.has("CTO") or _hq_stage() >= 3, "reason":"Auto maintenance requires a COO/CTO or Regional HQ."}
    return {"ok":false, "reason":"Unknown policy."}

func get_policy(policy: String) -> String:
    return str(policies.get(policy, "manual"))

func cycle_policy(policy: String) -> Dictionary:
    if not policies.has(policy): return {"ok":false, "message":"Unknown policy."}
    var current: int = MODES.find(get_policy(policy))
    var next_mode: String = str(MODES[(maxi(0, current) + 1) % MODES.size()])
    if next_mode == "auto":
        var access := can_auto(policy)
        if not bool(access.get("ok", false)):
            policies[policy] = "manual"
            _save_policies(); evaluate()
            return {"ok":false, "message":str(access.get("reason", "Automation locked."))}
    policies[policy] = next_mode
    _save_policies(); evaluate()
    return {"ok":true, "message":"%s policy: %s." % [policy.capitalize(), next_mode.to_upper()]}

func set_cash_reserve(value:int) -> void:
    cash_reserve=clampi(value,0,250000); _save_policies(); evaluate()

func run_daily() -> void:
    last_actions.clear()
    if not _business_open():
        evaluate(); return
    if get_policy("procurement") == "auto": _auto_procure()
    if get_policy("pricing") == "auto": _auto_price()
    if get_policy("maintenance") == "auto": _auto_maintain()
    evaluate()
    if not last_actions.is_empty(): _log("EXECUTIVE DESK: " + " | ".join(last_actions))

func _business_open() -> bool:
    var state = _state()
    return state != null and bool(state.get_value("businesses", "business_open", false))

func _needs_inputs() -> bool:
    var commands = _commands()
    if commands == null: return false
    var business = commands.get("business_system")
    if business == null: return false
    var chain = business.get("supply_chain")
    if chain == null or not chain.has_method("stock"): return false
    var state = _state()
    var industry := str(state.get_value("businesses", "industry_id", "furniture")) if state != null else "furniture"
    var need := {"furniture":{"timber":8.0,"metal":4.0,"energy":12.0},"construction_materials":{"timber":8.0,"iron":8.0,"energy":12.0},"consumer_electronics":{"iron":8.0,"electronics":6.0,"energy":14.0}}.get(industry,{"timber":8.0,"energy":12.0})
    for resource in need.keys():
        if float(chain.stock(str(resource))) < float(need[resource]): return true
    return false

func _auto_procure() -> void:
    if not _needs_inputs(): return
    var finance = _finance()
    if finance == null or int(finance.get("cash")) <= cash_reserve:
        last_actions.append("procurement held for reserve"); return
    var game = _game()
    if game != null and game.has_method("buy_inputs"):
        var before := int(finance.get("cash")); game.buy_inputs(); var after := int(finance.get("cash"))
        if after < before: last_actions.append("inputs reordered")

func _auto_price() -> void:
    var state = _state()
    if state == null: return
    var price := int(state.get_value("businesses", "player_price", 110))
    var profit := int(state.get_value("economy", "last_profit", 0))
    var stock := int(state.get_value("production", "finished_goods", 0))
    var next_price: int = price
    if profit < 0 and stock >= 4: next_price = maxi(80, price - 10)
    elif profit > 0 and stock <= 2: next_price = mini(160, price + 10)
    if next_price != price:
        state.set_value("businesses", "player_price", next_price)
        last_actions.append("price $%d→$%d" % [price, next_price])

func _auto_maintain() -> void:
    var production = _production(); var finance = _finance()
    if production == null or finance == null: return
    var machines = production.get("machines")
    if not machines is Dictionary: return
    for id in machines.keys():
        var machine = machines[id]
        if not machine is Dictionary or not bool(machine.get("owned", false)): continue
        if float(machine.get("condition", 100.0)) >= 72.0 and int(machine.get("maintenance_due", 0)) <= 1: continue
        if int(finance.get("cash")) <= cash_reserve:
            last_actions.append("maintenance held for reserve"); return
        if production.has_method("maintain_machine"):
            var result: Dictionary = production.maintain_machine(str(id), finance)
            if bool(result.get("ok", false)): last_actions.append("%s maintained" % str(id).replace("_", " "))

func evaluate() -> void:
    alerts.clear()
    var state = _state(); var finance = _finance()
    if state == null: return
    var cash := int(finance.get("cash")) if finance != null else int(state.get_value("economy", "cash", 0))
    var debt := int(state.get_value("finance", "debt", 0))
    var profit := int(state.get_value("economy", "last_profit", 0))
    var stock := int(state.get_value("production", "finished_goods", 0))
    if _business_open() and _needs_inputs(): _alert("warning","INPUT RISK","Core inputs are below the operating buffer.")
    if _business_open() and profit < 0: _alert("warning","MARGIN PRESSURE","Latest operating day lost $%d." % absi(profit))
    if debt > 0 and cash < maxi(cash_reserve, int(float(debt) * 0.10)): _alert("critical","LIQUIDITY RISK","Cash reserves are thin relative to debt.")
    if stock >= 16: _alert("warning","SLOW INVENTORY","%d finished units are sitting unsold." % stock)
    _machine_alerts(); _management_alerts()

func _machine_alerts() -> void:
    var production = _production()
    if production == null: return
    var machines = production.get("machines")
    if not machines is Dictionary: return
    for id in machines.keys():
        var machine = machines[id]
        if machine is Dictionary and bool(machine.get("owned", false)):
            var condition := float(machine.get("condition", 100.0))
            if condition < 55.0: _alert("critical","MACHINE CONDITION","%s is at %d%% condition." % [str(id).replace("_", " ").capitalize(),int(condition)])
            elif condition < 75.0: _alert("warning","MAINTENANCE DUE","%s is at %d%% condition." % [str(id).replace("_", " ").capitalize(),int(condition)])

func _management_alerts() -> void:
    var commands = _commands()
    if commands == null: return
    var expansion = commands.get("expansion_system")
    if expansion == null or not expansion.has_method("management_capacity"): return
    var capacity: Dictionary = expansion.management_capacity()
    var used := int(capacity.get("used",0)); var total := int(capacity.get("capacity",0))
    if total > 0 and used >= total: _alert("critical","SPAN OF CONTROL","Management capacity is full (%d/%d)." % [used,total])
    elif total > 0 and used >= total - 1: _alert("warning","MANAGEMENT CAPACITY","Only one management slot remains (%d/%d)." % [used,total])

func _alert(severity:String,title:String,detail:String) -> void:
    alerts.append({"severity":severity,"title":title,"detail":detail})
func get_alerts() -> Array: return alerts.duplicate(true)
func policy_summary() -> String: return "PROCUREMENT %s • PRICING %s • MAINTENANCE %s" % [get_policy("procurement").to_upper(),get_policy("pricing").to_upper(),get_policy("maintenance").to_upper()]
func alert_summary(limit:int=3) -> String:
    evaluate()
    if alerts.is_empty(): return "No material operating exceptions detected."
    var lines:Array=[]
    for i in range(mini(limit,alerts.size())): lines.append("%s — %s" % [alerts[i].get("title","Alert"),alerts[i].get("detail","")])
    return "\n".join(lines)

func _log(text:String) -> void:
    var state = _state()
    if state == null: return
    var logs = state.get_value("company","log_lines",[])
    if not logs is Array: logs=[]
    logs=logs.duplicate(true); logs.append(text)
    if logs.size()>100: logs.pop_front()
    state.set_value("company","log_lines",logs)

func capture_state() -> Dictionary:
    return {"system_version":SYSTEM_VERSION,"policies":policies.duplicate(true),"cash_reserve":cash_reserve,"last_day":last_day,"last_actions":last_actions.duplicate(),"alerts":alerts.duplicate(true)}
func restore_state(snapshot:Dictionary) -> void:
    if snapshot.is_empty(): return
    var saved=snapshot.get("policies",{})
    if saved is Dictionary:
        for key in policies.keys():
            var mode:=str(saved.get(key,policies[key])); if mode in MODES: policies[key]=mode
    cash_reserve=clampi(int(snapshot.get("cash_reserve",cash_reserve)),0,250000)
    last_day=int(snapshot.get("last_day",last_day))
    last_actions=snapshot.get("last_actions",[]).duplicate() if snapshot.get("last_actions",[]) is Array else []
    alerts=snapshot.get("alerts",[]).duplicate(true) if snapshot.get("alerts",[]) is Array else []
    _save_policies()
