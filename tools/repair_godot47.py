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

# Known Godot 4.7 parser/type blockers from the CI audit.
replace("scripts/supply_chain_system.gd",
'''last_operation={"type":"furniture_factory_inputs","cycles":run_cycles,"consumed":{"timber":FURNITURE_INPUTS["timber"]*run_cycles,"metal":FURNITURE_INPUTS["metal"]*run_cycles,"energy":FURNITURE_INPUTS["energy"]*run_cycles};return {"ok":true,"cycles":run_cycles,"consumed":last_operation["consumed"].duplicate(true)}''',
'''last_operation={"type":"furniture_factory_inputs","cycles":run_cycles,"consumed":{"timber":FURNITURE_INPUTS["timber"]*run_cycles,"metal":FURNITURE_INPUTS["metal"]*run_cycles,"energy":FURNITURE_INPUTS["energy"]*run_cycles}};return {"ok":true,"cycles":run_cycles,"consumed":last_operation["consumed"].duplicate(true)}''')

replace("scripts/business_system.gd", "var output_factor:=employee_factor*business_efficiency*_technology_multiplier()*_property_condition_multiplier()*morale_multiplier", "var output_factor: float = employee_factor*business_efficiency*_technology_multiplier()*_property_condition_multiplier()*morale_multiplier")
replace("scripts/business_system.gd", "var need:=float(industry.inputs[resource])*cycles", "var need: float = float(industry.inputs[resource])*cycles")
replace("scripts/business_system.gd", "var delivery:=supply_chain.procure_bundle(orders,cash,transport_level)", "var delivery: Dictionary = supply_chain.procure_bundle(orders,cash,transport_level)")
replace("scripts/business_system.gd", "var input_result:=supply_chain.consume_furniture_inputs(cycles)", "var input_result: Dictionary = supply_chain.consume_furniture_inputs(cycles)")

replace("scripts/economy.gd", "var ratio:=demand_value/supply_value", "var ratio: float = demand_value/supply_value")
replace("scripts/analytics_system.gd", 'return int(scene.get("day", 1)) if scene != null else 1', 'return int(scene.get("day")) if scene != null and scene.get("day") != null else 1')

# Remove unnecessary typed Variant returns from dependency lookup helpers.
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
        s = re.sub(rf'func {re.escape(name)}\(\)\s*->\s*Variant:', f'func {name}():', s)
    p.write_text(s)

# Make the economic-cycle transition function unambiguous to the 4.7 parser.
p = Path("scripts/economic_cycle_system.gd")
if p.exists():
    s = p.read_text()
    start = s.find("func _advance_phase(")
    end = s.find("\nfunc _economic_signal", start)
    if start >= 0 and end >= 0:
        block = '''func _advance_phase(signal: float, day: int) -> void:\n    var duration: int = day - int(phase_start_day)\n    var next_phase: String = str(phase)\n    match str(phase):\n        BOOM:\n            if duration >= 10 or signal > 1.28:\n                next_phase = OVERHEATING\n        EXPANSION:\n            if duration >= 8 and signal > 1.08:\n                next_phase = BOOM\n        OVERHEATING:\n            if duration >= 6 or signal < 0.92:\n                next_phase = RECESSION\n        RECESSION:\n            if duration >= 8 and signal > 0.96:\n                next_phase = RECOVERY\n        RECOVERY:\n            if duration >= 7 and signal > 1.08:\n                next_phase = EXPANSION\n    if next_phase != str(phase):\n        phase = next_phase\n        phase_start_day = day\n        phase_strength = 0.5\n        cycle_index += 1\n        _publish("Economic cycle entered %s." % str(phase).capitalize(), day)\n    else:\n        phase_strength = clamp(float(phase_strength) + 0.05, 0.0, 1.0)\n'''
        p.write_text(s[:start] + block + s[end:])

# Fix the remaining Object.get() use in analytics without touching Dictionary.get().
p = Path("scripts/analytics_system.gd")
if p.exists():
    s = p.read_text()
    s = s.replace('main.get("restoration", false)', 'main.get("restoration") if main.get("restoration") != null else false')
    p.write_text(s)
