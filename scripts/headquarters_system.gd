extends Node
class_name RenewHeadquartersSystem

const STAGES := ["Small Office", "Headquarters", "Corporate Center", "Regional HQ", "Global Headquarters"]
const STAGE_COSTS := [0, 15000, 40000, 90000, 200000]
const AREA_SPECS := {
    "executive_offices": {"name": "Executive Offices", "cost": 2500, "min_stage": 0},
    "board_room": {"name": "Board Room", "cost": 4500, "min_stage": 1},
    "research": {"name": "Research", "cost": 8000, "min_stage": 1},
    "training": {"name": "Training Center", "cost": 6000, "min_stage": 1},
    "archives": {"name": "Archives", "cost": 3000, "min_stage": 0},
    "museum": {"name": "Museum", "cost": 9000, "min_stage": 2},
    "technology_center": {"name": "Technology Center", "cost": 12000, "min_stage": 2}
}

var stage_index: Variant = 0
var stage_progress: Variant = 0
var owned_areas: Dictionary = {}
var area_levels: Dictionary = {}
var headquarters_name: Variant = "RENEW Office"
var headquarters_region: Variant = ""
var headquarters_value: Variant = 0
var expansion_history: Array = []
var last_upgrade_day: Variant = 0

func _ready() -> void:
    for area_id in AREA_SPECS.keys():
        owned_areas[area_id] = false
        area_levels[area_id] = 0

func get_stage() -> String: return STAGES[clamp(stage_index, 0, STAGES.size() - 1)]
func get_stage_index() -> int: return stage_index
func stage_cost(target_index: int = -1) -> int:
    var target: Variant = target_index if target_index >= 0 else stage_index + 1
    return STAGE_COSTS[clamp(target, 0, STAGE_COSTS.size() - 1)]
func can_upgrade(cash: int) -> Dictionary:
    if stage_index >= STAGES.size() - 1: return {"ok": false, "reason": "Global Headquarters is the final stage."}
    var target: Variant = stage_index + 1; var cost: Variant = stage_cost(target)
    if cash < cost: return {"ok": false, "reason": "HQ expansion requires $%s." % _money(cost), "cost": cost}
    return {"ok": true, "cost": cost, "target": target, "stage": STAGES[target]}
func upgrade(cash: int, day: int = 0) -> Dictionary:
    var check: Variant = can_upgrade(cash)
    if not bool(check.get("ok", false)): return check
    stage_index += 1; stage_progress = 0; last_upgrade_day = day; headquarters_value += int(check["cost"])
    expansion_history.append({"day": day, "stage": get_stage(), "cost": int(check["cost"])})
    return {"ok": true, "cost": int(check["cost"]), "stage": get_stage(), "stage_index": stage_index}

## Atomic transaction: HQ state and canonical finance either both commit or both roll back.
func upgrade_with_finance(finance: Node, day: int = 0) -> Dictionary:
    if finance == null or not finance.has_method("spend") or not finance.has_method("can_afford") or not finance.has_method("capture_state") or not finance.has_method("restore_state"):
        return {"ok": false, "reason": "Financial system is unavailable."}
    var cash := int(finance.cash); var check: Dictionary = can_upgrade(cash)
    if not bool(check.get("ok", false)): return check
    var finance_snapshot: Dictionary = finance.capture_state(); var hq_snapshot: Dictionary = capture_state()
    var upgraded: Dictionary = upgrade(cash, day)
    if not bool(upgraded.get("ok", false)): return upgraded
    var payment: Dictionary = finance.spend(int(upgraded.get("cost", 0)), "headquarters upgrade")
    if not bool(payment.get("ok", false)):
        restore_state(hq_snapshot); finance.restore_state(finance_snapshot)
        return {"ok": false, "reason": str(payment.get("message", "HQ payment failed."))}
    upgraded["payment"] = payment; return upgraded

func unlock_area(area_id: String, cash: int) -> Dictionary:
    if not AREA_SPECS.has(area_id): return {"ok": false, "reason": "Unknown headquarters area."}
    if has_area(area_id): return {"ok": false, "reason": "%s is already operational." % AREA_SPECS[area_id]["name"]}
    var spec: Dictionary = AREA_SPECS[area_id]
    if stage_index < int(spec["min_stage"]): return {"ok": false, "reason": "%s unlocks at %s." % [spec["name"], STAGES[int(spec["min_stage"])]]}
    var cost: Variant = int(spec["cost"])
    if cash < cost: return {"ok": false, "reason": "%s requires $%s." % [spec["name"], _money(cost)]}
    owned_areas[area_id] = true; area_levels[area_id] = 1; headquarters_value += cost
    return {"ok": true, "cost": cost, "area": spec["name"]}
func upgrade_area(area_id: String, cash: int) -> Dictionary:
    if not has_area(area_id): return {"ok": false, "reason": "Build this area first."}
    var level: Variant = int(area_levels.get(area_id, 1)); var cost: Variant = int(AREA_SPECS[area_id]["cost"]) * level
    if cash < cost: return {"ok": false, "reason": "Area upgrade requires $%s." % _money(cost)}
    area_levels[area_id] = level + 1; headquarters_value += cost
    return {"ok": true, "cost": cost, "level": level + 1, "area": AREA_SPECS[area_id]["name"]}

## Atomic transaction: area state and canonical finance either both commit or both roll back.
func build_area_with_finance(finance: Node, area_id: String) -> Dictionary:
    if finance == null or not finance.has_method("spend") or not finance.has_method("can_afford") or not finance.has_method("capture_state") or not finance.has_method("restore_state"):
        return {"ok": false, "reason": "Financial system is unavailable."}
    var cash := int(finance.cash); var hq_snapshot: Dictionary = capture_state(); var finance_snapshot: Dictionary = finance.capture_state()
    var result: Dictionary = upgrade_area(area_id, cash) if has_area(area_id) else unlock_area(area_id, cash)
    if not bool(result.get("ok", false)): return result
    var payment: Dictionary = finance.spend(int(result.get("cost", 0)), "headquarters area upgrade")
    if not bool(payment.get("ok", false)):
        restore_state(hq_snapshot); finance.restore_state(finance_snapshot)
        return {"ok": false, "reason": str(payment.get("message", "Area payment failed."))}
    result["payment"] = payment; return result

func has_area(area_id: String) -> bool: return bool(owned_areas.get(area_id, false))
func area_level(area_id: String) -> int: return int(area_levels.get(area_id, 0))
func get_area_status() -> Array:
    var result: Array = []
    for area_id in AREA_SPECS.keys():
        var spec: Dictionary = AREA_SPECS[area_id]
        result.append({"id": area_id, "name": spec["name"], "unlocked": stage_index >= int(spec["min_stage"]), "built": has_area(area_id), "level": area_level(area_id), "min_stage": STAGES[int(spec["min_stage"])]})
    return result
func executive_capacity() -> int: return area_level("executive_offices") * 3
func board_governance_available() -> bool: return has_area("board_room")
func research_capacity() -> int: return area_level("research") * 2
func training_capacity() -> int: return area_level("training") * 4
func archive_capacity() -> int: return area_level("archives") * 100
func museum_available() -> bool: return has_area("museum")
func technology_capacity() -> int: return area_level("technology_center") * 3
func daily_modifier() -> Dictionary:
    return {"executive_capacity": executive_capacity(), "research_capacity": research_capacity(), "training_capacity": training_capacity(), "archive_capacity": archive_capacity(), "technology_capacity": technology_capacity(), "board_governance": board_governance_available(), "museum": museum_available()}
func capture_state() -> Dictionary:
    return {"stage_index": stage_index, "stage_progress": stage_progress, "owned_areas": owned_areas.duplicate(true), "area_levels": area_levels.duplicate(true), "headquarters_name": headquarters_name, "headquarters_region": headquarters_region, "headquarters_value": headquarters_value, "expansion_history": expansion_history.duplicate(true), "last_upgrade_day": last_upgrade_day}
func restore_state(state: Dictionary) -> void:
    stage_index = clamp(int(state.get("stage_index", 0)), 0, STAGES.size() - 1); stage_progress = int(state.get("stage_progress", 0)); headquarters_name = str(state.get("headquarters_name", "RENEW Office")); headquarters_region = str(state.get("headquarters_region", "")); headquarters_value = int(state.get("headquarters_value", 0))
    var history = state.get("expansion_history", []); expansion_history = history.duplicate(true) if history is Array else []; last_upgrade_day = int(state.get("last_upgrade_day", 0))
    var saved_areas = state.get("owned_areas", {}); if saved_areas is Dictionary:
        for area_id in AREA_SPECS.keys(): owned_areas[area_id] = bool(saved_areas.get(area_id, false))
    var saved_levels = state.get("area_levels", {}); if saved_levels is Dictionary:
        for area_id in AREA_SPECS.keys(): area_levels[area_id] = max(0, int(saved_levels.get(area_id, 0)))
func _money(value: int) -> String: return "%,d" % value
