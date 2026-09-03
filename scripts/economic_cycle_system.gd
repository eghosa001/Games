extends Node
class_name RenewEconomicCycleSystem

const BOOM := "boom"
const EXPANSION := "expansion"
const OVERHEATING := "overheating"
const RECESSION := "recession"
const RECOVERY := "recovery"

var phase: Variant = EXPANSION
var phase_strength: Variant = 0.0
var phase_start_day: Variant = 1
var cycle_index: Variant = 0
var indicators: Variant = {"demand":1.0,"credit":1.0,"investment":1.0,"employment":1.0,"inflation":1.0}
var industry_profiles: Variant = {
    "consumer": {"boom":1.20,"expansion":1.10,"overheating":0.98,"recession":0.72,"recovery":1.05},
    "construction": {"boom":1.25,"expansion":1.18,"overheating":1.02,"recession":0.60,"recovery":1.15},
    "manufacturing": {"boom":1.18,"expansion":1.12,"overheating":1.00,"recession":0.78,"recovery":1.08},
    "energy": {"boom":1.10,"expansion":1.08,"overheating":1.18,"recession":0.95,"recovery":1.12},
    "logistics": {"boom":1.16,"expansion":1.12,"overheating":1.04,"recession":0.76,"recovery":1.10},
    "technology": {"boom":1.28,"expansion":1.20,"overheating":1.08,"recession":0.88,"recovery":1.25},
    "finance": {"boom":1.22,"expansion":1.14,"overheating":0.90,"recession":0.68,"recovery":1.12},
    "healthcare": {"boom":1.06,"expansion":1.05,"overheating":1.04,"recession":0.98,"recovery":1.04}
}
var phase_targets: Variant = {"boom":1.20,"expansion":1.10,"overheating":1.02,"recession":0.76,"recovery":1.05}
var last_day: Variant = -1
var history: Array = []

func process_day(day: int, context: Dictionary = {}) -> Dictionary:
    if day == last_day: return snapshot()
    last_day = day
    var signal: Variant = _economic_signal(context)
    _advance_phase(signal, day)
    _update_indicators()
    var result: Variant = snapshot()
    result["industry_multipliers"] = industry_multipliers()
    history.append(result.duplicate(true))
    if history.size() > 180: history.pop_front()
    return result

func industry_multiplier(industry: String) -> float:
    var profile: Dictionary = industry_profiles.get(industry.to_lower(), industry_profiles["consumer"])
    return float(profile.get(phase, 1.0)) * (0.90 + 0.10 * phase_strength)

func industry_multipliers() -> Dictionary:
    var result: Variant = {}
    for industry in industry_profiles.keys(): result[industry] = industry_multiplier(str(industry))
    return result

func get_phase() -> String: return phase
func get_indicators() -> Dictionary: return indicators.duplicate(true)
func snapshot() -> Dictionary:
    return {"phase":phase,"phase_strength":phase_strength,"phase_start_day":phase_start_day,"cycle_index":cycle_index,"indicators":indicators.duplicate(true)}

func force_phase(new_phase: String, day: int = -1) -> bool:
    if not phase_targets.has(new_phase): return false
    phase = new_phase; phase_start_day = _day() if day < 0 else day; phase_strength = 0.5; return true

func _advance_phase(signal: float, day: int) -> void:
    var duration: Variant = day - phase_start_day
    var next: Variant = phase
    match phase:
        BOOM: if duration >= 10 or signal > 1.28: next = OVERHEATING
        EXPANSION: if duration >= 8 and signal > 1.08: next = BOOM
        OVERHEATING: if duration >= 6 or signal < 0.92: next = RECESSION
        RECESSION: if duration >= 8 and signal > 0.96: next = RECOVERY
        RECOVERY: if duration >= 7 and signal > 1.08: next = EXPANSION
    if next != phase:
        phase = next; phase_start_day = day; phase_strength = 0.5; cycle_index += 1
        _publish("Economic cycle entered %s." % phase.capitalize(), day)
    else:
        phase_strength = clamp(phase_strength + 0.05, 0.0, 1.0)

func _economic_signal(context: Dictionary) -> float:
    var demand: Variant = float(context.get("demand", indicators["demand"]))
    var investment: Variant = float(context.get("investment", indicators["investment"]))
    var credit: Variant = float(context.get("credit", indicators["credit"]))
    var inflation: Variant = float(context.get("inflation", indicators["inflation"]))
    return demand * 0.40 + investment * 0.30 + credit * 0.20 + (2.0 - inflation) * 0.10

func _update_indicators() -> void:
    var target: Variant = float(phase_targets[phase])
    indicators["demand"] = lerp(float(indicators["demand"]), target, 0.18)
    indicators["investment"] = lerp(float(indicators["investment"]), target, 0.15)
    indicators["credit"] = lerp(float(indicators["credit"]), 1.0 if phase in [BOOM, EXPANSION, RECOVERY] else 0.78, 0.12)
    indicators["employment"] = lerp(float(indicators["employment"]), 1.0 if phase != RECESSION else 0.84, 0.12)
    indicators["inflation"] = lerp(float(indicators["inflation"]), 1.0 if phase in [RECESSION, RECOVERY] else (1.18 if phase == OVERHEATING else 1.06), 0.14)

func _publish(text: String, day: int) -> void:
    var news = get_node_or_null("/root/RenewNewsSystem")
    if news != null and news.has_method("publish"): news.publish(text, day)

func _day() -> int:
    var scene: Variant = get_tree().current_scene if get_tree() != null else null
    return int(scene.get("day")) if scene != null else 1

func capture_state() -> Dictionary:
    return {"phase":phase,"phase_strength":phase_strength,"phase_start_day":phase_start_day,"cycle_index":cycle_index,"indicators":indicators.duplicate(true),"last_day":last_day,"history":history.duplicate(true)}
func restore_state(state: Dictionary) -> void:
    phase = str(state.get("phase", EXPANSION)); phase_strength = float(state.get("phase_strength",0.0)); phase_start_day = int(state.get("phase_start_day",1)); cycle_index = int(state.get("cycle_index",0)); indicators = state.get("indicators",indicators).duplicate(true); last_day = int(state.get("last_day",-1)); history = state.get("history",[]).duplicate(true)

func _process(_delta: float) -> void:
    var scene: Variant = get_tree().current_scene if get_tree() != null else null
    if scene == null: return
    var day: Variant = int(scene.get("day"))
    if day > 0 and day != last_day: process_day(day)
