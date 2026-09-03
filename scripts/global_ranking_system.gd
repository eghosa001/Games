extends Node
class_name RenewGlobalRankingSystem

const CATEGORIES := [
    "valuation", "revenue", "profit", "assets", "market_share", "employees",
    "technology", "infrastructure", "regional_presence", "reputation",
    "resource_control", "alliance_influence"
]
const SNAPSHOT_DAILY := "daily"
const SNAPSHOT_WEEKLY := "weekly"
const MAX_HISTORY := 365

var companies: Dictionary = {}
var daily_snapshots: Array = []
var weekly_snapshots: Array = []
var historical: Dictionary = {}
var regional_rankings: Dictionary = {}
var last_day: Variant = -1

func _ready() -> void:
    process_day(_current_day())

func _process(_delta: float) -> void:
    var day: Variant = _current_day()
    if day != last_day:
        process_day(day)

func register_company(company_id: String, name: String = "", region: String = "global") -> Dictionary:
    var id: Variant = str(company_id)
    if not companies.has(id):
        companies[id] = {"id": id, "name": name if name != "" else id, "region": region, "metrics": {}}
    else:
        if name != "": companies[id]["name"] = name
        if region != "": companies[id]["region"] = region
    return companies[id]

func update_company(company_id: String, metrics: Dictionary) -> Dictionary:
    var entry: Variant = register_company(company_id)
    var clean: Dictionary = entry.get("metrics", {}).duplicate(true)
    for category in CATEGORIES:
        if metrics.has(category): clean[category] = max(0.0, float(metrics[category]))
    entry["metrics"] = clean
    companies[company_id] = entry
    return entry

func process_day(day: int) -> void:
    if day == last_day and not daily_snapshots.is_empty(): return
    _discover_companies()
    var snapshot: Variant = _build_snapshot(day)
    daily_snapshots.append(snapshot)
    if daily_snapshots.size() > MAX_HISTORY: daily_snapshots.pop_front()
    if day % 7 == 0 or weekly_snapshots.is_empty():
        weekly_snapshots.append(snapshot.duplicate(true))
        if weekly_snapshots.size() > MAX_HISTORY: weekly_snapshots.pop_front()
    last_day = day
    _rebuild_historical()
    _rebuild_regional(day)

func get_ranking(category: String, limit: int = 20, region: String = "") -> Array:
    if not CATEGORIES.has(category): return []
    var rows: Array = []
    for id in companies.keys():
        var c: Dictionary = companies[id]
        if region != "" and str(c.get("region", "")) != region: continue
        var metrics: Dictionary = c.get("metrics", {})
        rows.append({"rank": 0, "id": id, "name": c.get("name", id), "region": c.get("region", ""), "score": float(metrics.get(category, 0.0))})
    rows.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
    for i in range(rows.size()): rows[i]["rank"] = i + 1
    return rows.slice(0, min(limit, rows.size()))

func get_category_rankings(limit: int = 20) -> Dictionary:
    var result: Variant = {}
    for category in CATEGORIES: result[category] = get_ranking(category, limit)
    return result

func get_regional_ranking(region: String, category: String, limit: int = 20) -> Array:
    return get_ranking(category, limit, region)

func get_historical_ranking(category: String, snapshot_day: int = -1, limit: int = 20) -> Array:
    if snapshot_day < 0: return get_ranking(category, limit)
    var key: Variant = str(snapshot_day)
    if not historical.has(key): return []
    var snap: Dictionary = historical[key]
    var rows: Array = snap.get(category, []).duplicate(true)
    return rows.slice(0, min(limit, rows.size()))

func get_daily_snapshots() -> Array: return daily_snapshots.duplicate(true)
func get_weekly_snapshots() -> Array: return weekly_snapshots.duplicate(true)
func get_snapshot(day: int) -> Dictionary: return historical.get(str(day), {}).duplicate(true)

func _build_snapshot(day: int) -> Dictionary:
    var snapshot: Variant = {"day": day, "timestamp": Time.get_unix_time_from_system(), "rankings": {}}
    for category in CATEGORIES: snapshot["rankings"][category] = get_ranking(category, companies.size())
    return snapshot

func _rebuild_historical() -> void:
    historical.clear()
    for snap in daily_snapshots:
        historical[str(snap.get("day", -1))] = snap.get("rankings", {}).duplicate(true)

func _rebuild_regional(day: int) -> void:
    regional_rankings.clear()
    var regions: Variant = {}
    for id in companies.keys(): regions[str(companies[id].get("region", "global"))] = true
    for region in regions.keys():
        var block: Variant = {"day": day, "rankings": {}}
        for category in CATEGORIES: block["rankings"][category] = get_ranking(category, companies.size(), str(region))
        regional_rankings[str(region)] = block

func _discover_companies() -> void:
    var tree: Variant = Engine.get_main_loop()
    if tree == null: return
    var main = tree.get_current_scene()
    if main == null: return
    var rivals = main.get("rivals")
    if rivals is Array:
        for rival in rivals:
            if rival is Dictionary:
                var id: Variant = str(rival.get("id", rival.get("name", "rival")))
                var region: Variant = str(rival.get("region", "global"))
                register_company(id, str(rival.get("name", id)), region)
                update_company(id, _derive_metrics(rival))
    var player_id: Variant = "founder"
    register_company(player_id, "RENEW", str(main.get("selected_region", "global")))
    update_company(player_id, _derive_player_metrics(main))

func _derive_player_metrics(main) -> Dictionary:
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    var infrastructure = get_node_or_null("/root/RenewInfrastructureSystem")
    var alliance = get_node_or_null("/root/RenewAllianceSystem")
    var employees = get_node_or_null("/root/RenewEmployeeSystem")
    var ownership = main.get_node_or_null("OwnershipSystem")
    var cash: Variant = float(main.get("cash", 0.0))
    var reputation: Variant = float(main.get("reputation", 0.0))
    var revenue: Variant = float(main.get("revenue", 0.0))
    var profit: Variant = float(main.get("profit", 0.0))
    var assets: Variant = cash
    var valuation: Variant = cash
    if finance != null:
        var bs = finance.get("balance_sheet")
        if bs is Dictionary: assets = float(bs.get("assets", assets)); valuation = float(finance.get("valuation", assets))
        revenue = max(revenue, float(finance.get("revenue", revenue)))
        profit = max(profit, float(finance.get("profit", profit)))
    var infra_score: Variant = float(infrastructure.total_capacity("")) if infrastructure != null else 0.0
    var employee_count: Variant = float(employees.active_count()) if employees != null else float(main.get("employees", 0))
    var alliance_score: Variant = 0.0
    if alliance != null:
        var a = alliance.get_member_alliance("founder")
        if a is Dictionary: alliance_score = float(a.get("treasury", 0.0)) + float(a.get("reputation", 0.0)) * 1000.0
    var ownership_score: Variant = 0.0
    if ownership != null and ownership.has_method("get_ownership_percent"):
        ownership_score = float(ownership.get_ownership_percent("renew_co", "founder"))
    return {
        "valuation": valuation, "revenue": revenue, "profit": profit, "assets": assets,
        "market_share": max(0.0, float(main.get("market_share", 0.0))), "employees": employee_count,
        "technology": float(main.get("technology_level", 0.0)), "infrastructure": infra_score,
        "regional_presence": float(main.get("regions_unlocked", 1)), "reputation": reputation,
        "resource_control": float(main.get("resource_control", 0.0)), "alliance_influence": alliance_score + ownership_score
    }

func _derive_metrics(data: Dictionary) -> Dictionary:
    var m: Variant = {}
    for category in CATEGORIES: m[category] = float(data.get(category, data.get("metrics", {}).get(category, 0.0)))
    if m["valuation"] <= 0.0: m["valuation"] = float(data.get("assets", 0.0)) - float(data.get("debt", 0.0))
    return m

func capture_state() -> Dictionary:
    return {"companies": companies.duplicate(true), "daily_snapshots": daily_snapshots.duplicate(true), "weekly_snapshots": weekly_snapshots.duplicate(true), "historical": historical.duplicate(true), "regional_rankings": regional_rankings.duplicate(true), "last_day": last_day}

func restore_state(state: Dictionary) -> void:
    companies = state.get("companies", {}).duplicate(true)
    daily_snapshots = state.get("daily_snapshots", []).duplicate(true)
    weekly_snapshots = state.get("weekly_snapshots", []).duplicate(true)
    historical = state.get("historical", {}).duplicate(true)
    regional_rankings = state.get("regional_rankings", {}).duplicate(true)
    last_day = int(state.get("last_day", -1))

func _current_day() -> int:
    var tree: Variant = Engine.get_main_loop()
    if tree == null: return 1
    var main = tree.get_current_scene()
    if main != null and main.get("day") != null: return int(main.get("day"))
    return 1
