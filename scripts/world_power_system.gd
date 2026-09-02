extends Node
class_name RenewWorldPowerSystem

const DIMENSIONS := ["economic", "resource", "industrial", "technology", "logistics", "diplomatic", "alliance", "cultural_reputation"]
const WEIGHTS := {"economic": 0.18, "resource": 0.12, "industrial": 0.14, "technology": 0.14, "logistics": 0.10, "diplomatic": 0.10, "alliance": 0.10, "cultural_reputation": 0.12}
const MAX_HISTORY := 365

var entities: Dictionary = {}
var snapshots: Array = []
var history: Dictionary = {}
var last_day := -1

func _ready() -> void:
    process_day(_current_day())

func _process(_delta: float) -> void:
    var day := _current_day()
    if day != last_day: process_day(day)

func register_entity(entity_id: String, name: String = "", region: String = "global") -> Dictionary:
    var id := str(entity_id)
    if not entities.has(id): entities[id] = {"id": id, "name": name if name != "" else id, "region": region, "dimensions": {}, "score": 0.0}
    else:
        if name != "": entities[id]["name"] = name
        if region != "": entities[id]["region"] = region
    return entities[id]

func update_entity(entity_id: String, dimensions: Dictionary) -> Dictionary:
    var entry := register_entity(entity_id)
    var values: Dictionary = entry.get("dimensions", {}).duplicate(true)
    for dimension in DIMENSIONS:
        if dimensions.has(dimension): values[dimension] = clamp(float(dimensions[dimension]), 0.0, 100.0)
    entry["dimensions"] = values
    entry["score"] = _calculate_score(values)
    entities[entity_id] = entry
    return entry

func process_day(day: int) -> void:
    if day == last_day and not snapshots.is_empty(): return
    _discover_entities()
    var rankings := _build_rankings()
    var snapshot := {"day": day, "rankings": rankings}
    snapshots.append(snapshot)
    if snapshots.size() > MAX_HISTORY: snapshots.pop_front()
    history[str(day)] = rankings.duplicate(true)
    if history.size() > MAX_HISTORY:
        var oldest := str(snapshots[0].get("day", day))
        history.erase(oldest)
    last_day = day

func get_world_power(entity_id: String) -> float:
    return float(entities.get(entity_id, {}).get("score", 0.0))

func get_breakdown(entity_id: String) -> Dictionary:
    var entry: Dictionary = entities.get(entity_id, {})
    var values: Dictionary = entry.get("dimensions", {})
    var result := {}
    for dimension in DIMENSIONS:
        var value := float(values.get(dimension, 0.0))
        result[dimension] = {"score": value, "weight": WEIGHTS[dimension], "weighted": value * float(WEIGHTS[dimension])}
    result["total"] = float(entry.get("score", _calculate_score(values)))
    return result

func get_global_ranking(limit: int = 20) -> Array:
    var rows: Array = []
    for id in entities.keys():
        var e: Dictionary = entities[id]
        rows.append({"rank": 0, "id": id, "name": e.get("name", id), "region": e.get("region", "global"), "score": float(e.get("score", 0.0))})
    rows.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
    for i in range(rows.size()): rows[i]["rank"] = i + 1
    return rows.slice(0, min(limit, rows.size()))

func get_historical(day: int, entity_id: String = "") -> Variant:
    var ranking: Array = history.get(str(day), [])
    if entity_id == "": return ranking.duplicate(true)
    for row in ranking:
        if str(row.get("id", "")) == entity_id: return row.duplicate(true)
    return {}

func get_snapshots() -> Array: return snapshots.duplicate(true)

func _build_rankings() -> Array:
    var rows: Array = []
    for id in entities.keys():
        var e: Dictionary = entities[id]
        rows.append({"rank": 0, "id": id, "name": e.get("name", id), "region": e.get("region", "global"), "score": float(e.get("score", 0.0)), "breakdown": get_breakdown(id)})
    rows.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
    for i in range(rows.size()): rows[i]["rank"] = i + 1
    return rows

func _calculate_score(values: Dictionary) -> float:
    var total := 0.0
    for dimension in DIMENSIONS: total += clamp(float(values.get(dimension, 0.0)), 0.0, 100.0) * float(WEIGHTS[dimension])
    return clamp(total, 0.0, 100.0)

func _discover_entities() -> void:
    var tree := Engine.get_main_loop()
    if tree == null: return
    var main = tree.get_current_scene()
    if main == null: return
    var ranking = tree.get_root().get_node_or_null("RenewGlobalRankingSystem")
    if ranking != null:
        for row in ranking.get_ranking("valuation", 1000):
            var id := str(row.get("id", ""))
            if id == "": continue
            register_entity(id, str(row.get("name", id)), str(row.get("region", "global")))
            var metrics: Dictionary = ranking.companies.get(id, {}).get("metrics", {})
            update_entity(id, _dimensions_from_metrics(metrics))

func _dimensions_from_metrics(metrics: Dictionary) -> Dictionary:
    return {
        "economic": _normalize_dimension([float(metrics.get("valuation", 0.0)), float(metrics.get("revenue", 0.0)), float(metrics.get("profit", 0.0))]),
        "resource": _normalize_value(float(metrics.get("resource_control", 0.0))),
        "industrial": _normalize_dimension([float(metrics.get("assets", 0.0)), float(metrics.get("employees", 0.0))]),
        "technology": _normalize_value(float(metrics.get("technology", 0.0))),
        "logistics": _normalize_value(float(metrics.get("infrastructure", 0.0))),
        "diplomatic": _normalize_value(float(metrics.get("reputation", 0.0))),
        "alliance": _normalize_value(float(metrics.get("alliance_influence", 0.0))),
        "cultural_reputation": _normalize_value(float(metrics.get("reputation", 0.0)))
    }

func _normalize_dimension(values: Array) -> float:
    var total := 0.0
    for value in values: total += _normalize_value(value)
    return total / max(1.0, float(values.size()))

func _normalize_value(value: float) -> float:
    if value <= 0.0: return 0.0
    return clamp(log(value + 1.0) / log(100000001.0) * 100.0, 0.0, 100.0)

func capture_state() -> Dictionary:
    return {"entities": entities.duplicate(true), "snapshots": snapshots.duplicate(true), "history": history.duplicate(true), "last_day": last_day}

func restore_state(state: Dictionary) -> void:
    entities = state.get("entities", {}).duplicate(true)
    snapshots = state.get("snapshots", []).duplicate(true)
    history = state.get("history", {}).duplicate(true)
    last_day = int(state.get("last_day", -1))

func _current_day() -> int:
    var tree := Engine.get_main_loop()
    if tree == null: return 1
    var main = tree.get_current_scene()
    if main != null and main.get("day") != null: return int(main.get("day"))
    return 1
