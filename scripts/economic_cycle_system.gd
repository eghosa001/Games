extends Node
class_name RenewEconomicCycleSystem
const BOOM := "boom"
const EXPANSION := "expansion"
const OVERHEATING := "overheating"
const RECESSION := "recession"
const RECOVERY := "recovery"
var phase: String = EXPANSION
var phase_strength: float = 0.0
var phase_start_day: int = 1
var cycle_index: int = 0
var indicators: Dictionary = {"demand":1.0,"credit":1.0,"investment":1.0,"employment":1.0,"inflation":1.0}
var industry_profiles: Dictionary = {"consumer":{"boom":1.20,"expansion":1.10,"overheating":0.98,"recession":0.72,"recovery":1.05},"construction":{"boom":1.25,"expansion":1.18,"overheating":1.02,"recession":0.60,"recovery":1.15},"manufacturing":{"boom":1.18,"expansion":1.12,"overheating":1.00,"recession":0.78,"recovery":1.08},"energy":{"boom":1.10,"expansion":1.08,"overheating":1.18,"recession":0.95,"recovery":1.12},"logistics":{"boom":1.16,"expansion":1.12,"overheating":1.04,"recession":0.76,"recovery":1.10},"technology":{"boom":1.28,"expansion":1.20,"overheating":1.08,"recession":0.88,"recovery":1.25},"finance":{"boom":1.22,"expansion":1.14,"overheating":0.90,"recession":0.68,"recovery":1.12},"healthcare":{"boom":1.06,"expansion":1.05,"overheating":1.04,"recession":0.98,"recovery":1.04}}
var phase_targets: Dictionary = {"boom":1.20,"expansion":1.10,"overheating":1.02,"recession":0.76,"recovery":1.05}
var last_day: int = -1
var history: Array = []
func process_day(day: int, context: Dictionary = {}) -> Dictionary:
    if day == last_day:
        return snapshot()
    last_day = day
    var economic_signal: float = _economic_signal(context)
    _advance_phase(economic_signal, day)
    _update_indicators()
    var result: Dictionary = snapshot()
    result["industry_multipliers"] = industry_multipliers()
    history.append(result.duplicate(true))
    if history.size() > 180:
        history.pop_front()
    return result
func industry_multiplier(industry: String) -> float:
    var profile: Dictionary = industry_profiles.get(industry.to_lower(), industry_profiles["consumer"])
    return float(profile.get(phase, 1.0)) * (0.90 + 0.10 * phase_strength)
func industry_multipliers() -> Dictionary:
    var result: Dictionary = {}
    for industry in industry_profiles.keys():
        result[industry] = industry_multiplier(str(industry))
    return result
func get_phase() -> String:
    return phase
func get_indicators() -> Dictionary:
    return indicators.duplicate(true)
func snapshot() -> Dictionary:
    return {"phase":phase,"phase_strength":phase_strength,"phase_start_day":phase_start_day,"cycle_index":cycle_index,"indicators":indicators.duplicate(true)}
func force_phase(new_phase: String, day: int = -1) -> bool:
    if not phase_targets.has(new_phase):
        return false
    phase = new_phase
    phase_start_day = _day() if day < 0 else day
    phase_strength = 0.5
    return true
func _advance_phase(economic_signal: float, day: int) -> void:
    var duration: int = day - phase_start_day
    var next_phase: String = phase
    match phase:
        BOOM:
            if duration >= 10 or economic_signal > 1.28:
                next_phase = OVERHEATING
        EXPANSION:
            if duration >= 8 and economic_signal > 1.08:
                next_phase = BOOM
        OVERHEATING:
            if duration >= 6 or economic_signal < 0.92:
                next_phase = RECESSION
        RECESSION:
            if duration >= 8 and economic_signal > 0.96:
                next_phase = RECOVERY
        RECOVERY:
            if duration >= 7 and economic_signal > 1.08:
                next_phase = EXPANSION
    if next_phase != phase:
        phase = next_phase
        phase_start_day = day
        cycle_index += 1
func _economic_signal(context: Dictionary) -> float:
    var demand: float = float(context.get("demand", 1.0))
    var credit: float = float(context.get("credit", 1.0))
    var investment: float = float(context.get("investment", 1.0))
    return demand * 0.5 + credit * 0.2 + investment * 0.3
func _update_indicators() -> void:
    var target: float = float(phase_targets.get(phase, 1.0))
    phase_strength = clamp(phase_strength + 0.05, 0.0, 1.0)
    indicators["demand"] = lerp(float(indicators.get("demand", 1.0)), target, 0.08)
    indicators["credit"] = lerp(float(indicators.get("credit", 1.0)), target, 0.05)
    indicators["investment"] = lerp(float(indicators.get("investment", 1.0)), target, 0.07)
    indicators["employment"] = lerp(float(indicators.get("employment", 1.0)), target, 0.04)
    indicators["inflation"] = lerp(float(indicators.get("inflation", 1.0)), 2.0 - target, 0.04)
func _day() -> int:
    var state = get_node_or_null("/root/RenewGameState")
    if state != null and state.has_method("get_value"):
        return int(state.get_value("player", "day", 1))
    return max(1, last_day)
func capture_state() -> Dictionary:
    return {"phase":phase,"phase_strength":phase_strength,"phase_start_day":phase_start_day,"cycle_index":cycle_index,"indicators":indicators.duplicate(true),"last_day":last_day,"history":history.duplicate(true)}
func restore_state(snapshot_data: Dictionary) -> void:
    if snapshot_data.is_empty():
        return
    phase = str(snapshot_data.get("phase", EXPANSION))
    phase_strength = float(snapshot_data.get("phase_strength", 0.0))
    phase_start_day = int(snapshot_data.get("phase_start_day", 1))
    cycle_index = int(snapshot_data.get("cycle_index", 0))
    indicators = snapshot_data.get("indicators", indicators).duplicate(true)
    last_day = int(snapshot_data.get("last_day", -1))
    history = snapshot_data.get("history", []).duplicate(true)
