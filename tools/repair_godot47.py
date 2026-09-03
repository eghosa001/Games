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

# Godot 4.7 compatibility repairs must be conservative. In particular, do
# not force nullable dependency helpers to -> Node: get_node_or_null() can
# legitimately return null, and typed Node returns then create new compile
# errors. Source files should own their correct return types.

# Explicitly type ambiguous arithmetic locals in supply-chain code.
replace("scripts/supply_chain_system.gd", "var base:=40.0+max(0,level-1)*20.0", "var base: float = 40.0+float(max(0,level-1))*20.0")
replace("scripts/supply_chain_system.gd", "var revenue:=sold*max(0,price)", "var revenue: int = sold*max(0,price)")

# Convert only known compact entry points when the old compact form is still
# present. These replacements are idempotent and preserve established APIs.
replace("scripts/business_system.gd", '''func _technology():return get_node_or_null("/root/RenewTechnologySystem")''', '''func _technology():\n    return get_node_or_null("/root/RenewTechnologySystem")''')

# Keep research-next's return value explicit on every branch.
def replace_function(path, name, replacement):
    p = Path(path)
    if not p.exists():
        return
    s = p.read_text()
    pattern = rf'(?ms)^func {re.escape(name)}\(.*?(?=^func |\Z)'
    ns, count = re.subn(pattern, replacement.rstrip() + "\n", s, count=1)
    if count:
        p.write_text(ns)

replace_function("scripts/technology_system.gd", "research_next", '''func research_next() -> bool:
    for tier in [1, 2, 3]:
        for id in TECHNOLOGIES.keys():
            if int(TECHNOLOGIES[id]["tier"]) == tier and not is_unlocked(id) and bool(can_research(id).get("ok", false)):
                return research(id)
    var state = _state()
    if state != null:
        state.set_value("company", "message", "No technology is currently researchable.")
    return false''')

replace_function("scripts/seasonal_restoration_system.gd", "restore_next", '''func restore_next() -> Dictionary:
    var step = _next_step(_seasonal().get("progress", {}))
    if step.is_empty():
        return {"ok": false, "reason": "complete"}
    return restore_step(step)''')

replace_function("scripts/news_system.gd", "_employee_by_id", '''func _employee_by_id(employee_id: String) -> Dictionary:
    var employees = get_node_or_null("/root/RenewEmployeeSystem")
    if employees == null or not employees.has_method("get_employee"):
        return {}
    return employees.get_employee(employee_id)''')

# Avoid one-line return/control-flow constructs that were previously fragile
# under the 4.7 parser, without rewriting already-stable implementations.
replace_function("scripts/simulation_system.gd", "end_day", '''func end_day(args: Dictionary = {}) -> Dictionary:
    var finance = _finance()
    if finance == null:
        return {"ok": false, "message": "FinanceSystem is unavailable."}
    var debt_result: Dictionary = finance.settle_debt_day()
    var economy = _economy()
    if economy != null:
        economy.end_market_day()
    last_result = debt_result
    return debt_result''')

# Keep existing supply-chain arithmetic fixes.
replace_function("scripts/supply_chain_system.gd", "_transport_capacity", '''func _transport_capacity(level: int) -> float:
    var base: float = 40.0 + float(max(0, level - 1)) * 20.0
    var tech = _technology()
    if tech != null:
        return base * tech.transport_capacity_multiplier()
    return base''')
replace_function("scripts/supply_chain_system.gd", "_freight_cost", '''func _freight_cost(resource: String, amount: float, level: int) -> int:
    var distance_factor: float = 1.0
    if economy != null and economy.resources.has(resource):
        distance_factor = 1.0 + float(str(economy.resources[resource].get("region", "Unknown")).length() % 4) * 0.05
    var base_cost: float = amount * (2.0 + float(max(0, 3 - level))) * distance_factor
    var effects = _railway_effects()
    return int(round(base_cost * float(effects.get("transport_cost_multiplier", 1.0))))''')
replace_function("scripts/supply_chain_system.gd", "receive_furniture", '''func receive_furniture(amount: int) -> void:
    warehouse["furniture"] = min(WAREHOUSE_LIMIT, stock("furniture") + max(0, amount))''')

# The phase-transition local must never use the reserved identifier `next`.
# This is idempotent for both old and already-fixed source.
replace("scripts/economic_cycle_system.gd", "var next: Variant = phase", "var next_phase: Variant = phase")
replace("scripts/economic_cycle_system.gd", "next = OVERHEATING", "next_phase = OVERHEATING")
replace("scripts/economic_cycle_system.gd", "next = BOOM", "next_phase = BOOM")
replace("scripts/economic_cycle_system.gd", "next = RECESSION", "next_phase = RECESSION")
replace("scripts/economic_cycle_system.gd", "next = RECOVERY", "next_phase = RECOVERY")
replace("scripts/economic_cycle_system.gd", "next = EXPANSION", "next_phase = EXPANSION")
replace("scripts/economic_cycle_system.gd", "if next != phase:", "if next_phase != phase:")
replace("scripts/economic_cycle_system.gd", "phase = next;", "phase = next_phase;")
