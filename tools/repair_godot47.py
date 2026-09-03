from pathlib import Path
import re


def replace(path, old, new):
    p = Path(path)
    if not p.exists():
        return
    s = p.read_text()
    ns = s.replace(old, new)
    if ns != s:
        p.write_text(ns)

# Keep dependency lookup helpers explicitly typed as Node so Godot 4.7 does
# not treat conditional returns as an incomplete inferred return path.
for path, names in {
    "scripts/simulation_system.gd": ["_game_state", "_finance", "_production", "_economy", "_contracts"],
    "scripts/technology_system.gd": ["_state"],
    "scripts/seasonal_restoration_system.gd": ["_state"],
    "scripts/news_system.gd": ["_state", "_main"],
}.items():
    p = Path(path)
    if not p.exists():
        continue
    s = p.read_text()
    for name in names:
        s = re.sub(rf'func {re.escape(name)}\(\)\s*(?:->\s*Variant)?\s*:', f'func {name}() -> Node:', s)
    p.write_text(s)

# Explicitly type ambiguous arithmetic locals in supply-chain code.
replace("scripts/supply_chain_system.gd", "var base:=40.0+max(0,level-1)*20.0", "var base: float = 40.0+float(max(0,level-1))*20.0")
replace("scripts/supply_chain_system.gd", "var revenue:=sold*max(0,price)", "var revenue: int = sold*max(0,price)")

# Convert the compact business entry points to unambiguous Godot 4.7 control flow.
replace("scripts/business_system.gd", '''func _technology():return get_node_or_null("/root/RenewTechnologySystem")''', '''func _technology() -> Node:\n    return get_node_or_null("/root/RenewTechnologySystem")''')
replace("scripts/business_system.gd", '''func open_business()->void:\n    if not bool(state_adapter.get_value("properties","owned",false)) or str(state_adapter.get_value("properties","stage","Neglected"))!="Operational":state_adapter.message("Finish restoration first.");return\n    if bool(state_adapter.get_value("businesses","business_open",false)):state_adapter.message("%s is already open."%_business_name());return\n    var existing_purpose:=str(state_adapter.get_value("businesses","business_purpose",""));if existing_purpose.is_empty():state_adapter.message("Choose what this restored property will become: press 4, 5 or 6.");return\n    create_business(existing_purpose)''', '''func open_business() -> void:\n    if not bool(state_adapter.get_value("properties", "owned", false)) or str(state_adapter.get_value("properties", "stage", "Neglected")) != "Operational":\n        state_adapter.message("Finish restoration first.")\n        return\n    if bool(state_adapter.get_value("businesses", "business_open", false)):\n        state_adapter.message("%s is already open." % _business_name())\n        return\n    var existing_purpose: String = str(state_adapter.get_value("businesses", "business_purpose", ""))\n    if existing_purpose.is_empty():\n        state_adapter.message("Choose what this restored property will become: press 4, 5 or 6.")\n        return\n    create_business(existing_purpose)''')
replace("scripts/business_system.gd", '''func create_business(purpose_id:String="")->void:\n    if not bool(state_adapter.get_value("properties","owned",false)) or str(state_adapter.get_value("properties","stage","Neglected"))!="Operational":state_adapter.message("Finish restoration first.");return''', '''func create_business(purpose_id: String = "") -> void:\n    if not bool(state_adapter.get_value("properties", "owned", false)) or str(state_adapter.get_value("properties", "stage", "Neglected")) != "Operational":\n        state_adapter.message("Finish restoration first.")\n        return''')

# Keep research-next's return value explicit on every branch.
replace("scripts/technology_system.gd", '''func research_next()->bool:\n    for tier in [1,2,3]:\n        for id in TECHNOLOGIES.keys():\n            if int(TECHNOLOGIES[id]["tier"])==tier and not is_unlocked(id) and bool(can_research(id).get("ok",false)):return research(id)\n    var state=_state(); if state!=null:state.set_value("company","message","No technology is currently researchable."); return false''', '''func research_next() -> bool:\n    for tier in [1, 2, 3]:\n        for id in TECHNOLOGIES.keys():\n            if int(TECHNOLOGIES[id]["tier"]) == tier and not is_unlocked(id) and bool(can_research(id).get("ok", false)):\n                return research(id)\n    var state = _state()\n    if state != null:\n        state.set_value("company", "message", "No technology is currently researchable.")\n    return false''')

# Explicitly type the seasonal/news helper return paths.
replace("scripts/seasonal_restoration_system.gd", '''func restore_next()->Dictionary:\n    var step=_next_step(_seasonal().get("progress",{}));if step.is_empty():return {"ok":false,"reason":"complete"};return restore_step(step)''', '''func restore_next() -> Dictionary:\n    var step = _next_step(_seasonal().get("progress", {}))\n    if step.is_empty():\n        return {"ok": false, "reason": "complete"}\n    return restore_step(step)''')
replace("scripts/news_system.gd", '''func _employee_by_id(employee_id:String)->Dictionary:\n    var employees=get_node_or_null("/root/RenewEmployeeSystem");if employees==null or not employees.has_method("get_employee"):return {};return employees.get_employee(employee_id)''', '''func _employee_by_id(employee_id: String) -> Dictionary:\n    var employees = get_node_or_null("/root/RenewEmployeeSystem")\n    if employees == null or not employees.has_method("get_employee"):\n        return {}\n    return employees.get_employee(employee_id)''')

# --- Remaining 4.7 blockers found by CI ---
# Avoid one-line suites around returns: Godot 4.7's parser is stricter about
# control-flow completion in these legacy compact functions.
def replace_function(path, name, replacement):
    p = Path(path)
    if not p.exists():
        return
    s = p.read_text()
    pattern = rf'(?ms)^func {re.escape(name)}\(.*?(?=^func |\Z)'
    ns, count = re.subn(pattern, replacement.rstrip() + "\n", s, count=1)
    if count:
        p.write_text(ns)

replace_function("scripts/business_system.gd", "_ready", '''func _ready() -> void:\n    add_child(state_adapter)\n    add_child(supply_chain)\n    supply_chain.set_economy(economy)''')
replace_function("scripts/business_system.gd", "get_industries", '''func get_industries() -> Array:\n    var result: Array = []\n    for key in INDUSTRIES.keys():\n        result.append(INDUSTRIES[key].duplicate(true))\n    return result''')
replace_function("scripts/business_system.gd", "get_industry", '''func get_industry(industry_id: String) -> Dictionary:\n    return INDUSTRIES.get(industry_id, {}).duplicate(true)''')
replace_function("scripts/business_system.gd", "get_business_purposes", '''func get_business_purposes() -> Array:\n    return PURPOSES.get(_origin_property_type(), []).duplicate(true)''')
replace_function("scripts/business_system.gd", "get_business_purpose", '''func get_business_purpose(index: int) -> Dictionary:\n    var choices: Array = get_business_purposes()\n    if index < 0 or index >= choices.size():\n        return {}\n    return choices[index].duplicate(true)''')

replace_function("scripts/simulation_system.gd", "end_day", '''func end_day(args: Dictionary = {}) -> Dictionary:\n    var finance = _finance()\n    if finance == null:\n        return {"ok": false, "message": "FinanceSystem is unavailable."}\n    var debt_result: Dictionary = finance.settle_debt_day()\n    var economy = _economy()\n    if economy != null:\n        economy.end_market_day()\n    last_result = debt_result\n    return debt_result''')

replace_function("scripts/supply_chain_system.gd", "_transport_capacity", '''func _transport_capacity(level: int) -> float:\n    var base: float = 40.0 + float(max(0, level - 1)) * 20.0\n    var tech = _technology()\n    if tech != null:\n        return base * tech.transport_capacity_multiplier()\n    return base''')
replace_function("scripts/supply_chain_system.gd", "_freight_cost", '''func _freight_cost(resource: String, amount: float, level: int) -> int:\n    var distance_factor: float = 1.0\n    if economy != null and economy.resources.has(resource):\n        distance_factor = 1.0 + float(str(economy.resources[resource].get("region", "Unknown")).length() % 4) * 0.05\n    var base_cost: float = amount * (2.0 + float(max(0, 3 - level))) * distance_factor\n    var effects = _railway_effects()\n    return int(round(base_cost * float(effects.get("transport_cost_multiplier", 1.0))))''')
replace_function("scripts/supply_chain_system.gd", "receive_furniture", '''func receive_furniture(amount: int) -> void:\n    warehouse["furniture"] = min(WAREHOUSE_LIMIT, stock("furniture") + max(0, amount))''')

# 'next' is a reserved identifier in this parser context; keep all phase
# transition state in an explicitly named variable.
replace("scripts/economic_cycle_system.gd", "var next: Variant = phase", "var next_phase: Variant = phase")
replace("scripts/economic_cycle_system.gd", "next = OVERHEATING", "next_phase = OVERHEATING")
replace("scripts/economic_cycle_system.gd", "next = BOOM", "next_phase = BOOM")
replace("scripts/economic_cycle_system.gd", "next = RECESSION", "next_phase = RECESSION")
replace("scripts/economic_cycle_system.gd", "next = RECOVERY", "next_phase = RECOVERY")
replace("scripts/economic_cycle_system.gd", "next = EXPANSION", "next_phase = EXPANSION")
replace("scripts/economic_cycle_system.gd", "if next != phase:", "if next_phase != phase:")
replace("scripts/economic_cycle_system.gd", "phase = next;", "phase = next_phase;")
