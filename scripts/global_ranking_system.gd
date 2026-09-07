extends Node
## class_name removed: "RenewGlobalRankingSystem" conflicts with project.godot autoload.

const CATEGORIES := [
    "valuation", "revenue", "profit", "assets", "market_share", "employees",
    "technology", "infrastructure", "regional_presence", "reputation",
    "resource_control", "alliance_influence"
]
const POWER_WEIGHTS := {"economic": 0.18, "resource": 0.12, "industrial": 0.14, "technology": 0.14, "logistics": 0.10, "diplomatic": 0.10, "alliance": 0.10, "cultural": 0.12}
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
func world_power() -> Dictionary:
    var game = get_node_or_null("/root/RenewGameState")
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    var alliance = get_node_or_null("/root/RenewAllianceSystem")
    var infra = get_node_or_null("/root/RenewInfrastructureSystem")
    var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    var worth := 0.0
    if finance != null and finance.has_method("valuation"):
        worth = maxf(0.0, float(finance.call("valuation")))
    var rep := 0
    var tech_count := 0
    var members := 0
    var treasury := 0.0
    var transport := 1
    var regions := 1
    if game != null:
        rep = int(game.get_value("player", "reputation", 0))
        var tech: Variant = game.get_value("technology", "technology", {})
        if tech is Dictionary:
            for key in (tech as Dictionary).keys():
                var entry: Variant = (tech as Dictionary)[key]
                if (entry is Dictionary and bool((entry as Dictionary).get("researched", false))) or (entry is bool and bool(entry)):
                    tech_count += 1
        transport = int(game.get_value("supply_chain", "transport_level", 1))
        regions = maxi(1, int(game.get_value("regions", "selected_district", 0)) + 1)
    if alliance != null and alliance.has_method("get_member_alliance"):
        var pact: Dictionary = alliance.get_member_alliance("player")
        if not pact.is_empty():
            members = (pact.get("members", {}) as Dictionary).size()
            treasury = float(pact.get("treasury", 0.0))
    var treaties := 0
    if diplomacy != null and diplomacy.has_method("list_treaties"):
        treaties = (diplomacy.list_treaties() as Array).size()
    var infra_score := 0.0
    if infra != null and infra.has_method("list_assets"):
        for asset in infra.list_assets():
            if asset is Dictionary and str((asset as Dictionary).get("status", "")) == "active":
                infra_score += 1.0
    var dims := {
        "economic": clampf(worth / 1000000.0 * 100.0, 0.0, 100.0),
        "resource": clampf(float(regions) / 3.0 * 100.0, 0.0, 100.0),
        "industrial": clampf((float(transport) / 5.0 * 50.0) + minf(50.0, worth / 20000.0), 0.0, 100.0),
        "technology": clampf(float(tech_count) / 6.0 * 100.0, 0.0, 100.0),
        "logistics": clampf(float(transport) / 5.0 * 100.0, 0.0, 100.0),
        "diplomatic": clampf(float(treaties) / 4.0 * 100.0, 0.0, 100.0),
        "alliance": clampf(minf(60.0, float(members) / 5.0 * 60.0) + minf(40.0, treasury / 25000.0), 0.0, 100.0),
        "cultural": clampf(float(rep), 0.0, 100.0),
    }
    var total := 0.0
    for key in (POWER_WEIGHTS as Dictionary).keys():
        total += float(dims.get(key, 0.0)) * float((POWER_WEIGHTS as Dictionary)[key])
    dims["total"] = clampf(total, 0.0, 100.0)
    return dims
func world_power_text() -> String:
    var power := world_power()
    return "WORLD POWER %.0f — Econ %.0f Res %.0f Ind %.0f Tech %.0f Log %.0f Dip %.0f Ally %.0f Cult %.0f." % [float(power.get("total", 0.0)), float(power.get("economic", 0.0)), float(power.get("resource", 0.0)), float(power.get("industrial", 0.0)), float(power.get("technology", 0.0)), float(power.get("logistics", 0.0)), float(power.get("diplomatic", 0.0)), float(power.get("alliance", 0.0)), float(power.get("cultural", 0.0))]
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
    var selected_region: String = str(main.get("selected_region")) if main.get("selected_region") != null else "global"
    register_company(player_id, "RENEW", selected_region)
    update_company(player_id, _derive_player_metrics(main))

func _derive_player_metrics(main) -> Dictionary:
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    var infrastructure = get_node_or_null("/root/RenewInfrastructureSystem")
    var alliance = get_node_or_null("/root/RenewAllianceSystem")
    var employees = get_node_or_null("/root/RenewEmployeeSystem")
    var ownership = main.get_node_or_null("Systems/OwnershipSystem")
    if ownership == null: ownership = main.get_node_or_null("OwnershipSystem")
    var cash: Variant = float(main.get("cash")) if main.get("cash") != null else 0.0
    var reputation: Variant = float(main.get("reputation")) if main.get("reputation") != null else 0.0
    var revenue: Variant = float(main.get("revenue")) if main.get("revenue") != null else 0.0
    var profit: Variant = float(main.get("profit")) if main.get("profit") != null else 0.0
    var assets: Variant = cash
    var valuation: Variant = cash
    if finance != null:
        var bs = finance.get("balance_sheet")
        if bs is Dictionary: assets = float(bs.get("assets", assets)); valuation = float(finance.get("valuation")) if finance.get("valuation") != null else assets
        revenue = max(revenue, float(finance.get("revenue")) if finance.get("revenue") != null else revenue)
        profit = max(profit, float(finance.get("profit")) if finance.get("profit") != null else profit)
    var infra_score: Variant = 0.0
    if infrastructure != null and infrastructure.has_method("list_assets"):
        for asset in infrastructure.list_assets():
            if asset is Dictionary and str(asset.get("status", "")) == "active":
                infra_score += float(asset.get("capacity", 0.0))
    var employee_count: Variant = float(employees.active_count()) if employees != null else float(main.get("employees")) if main.get("employees") != null else 0.0
    var alliance_score: Variant = 0.0
    if alliance != null:
        var a = alliance.get_member_alliance("founder")
        if a is Dictionary: alliance_score = float(a.get("treasury", 0.0)) + float(a.get("reputation", 0.0)) * 1000.0
    var ownership_score: Variant = 0.0
    if ownership != null and ownership.has_method("get_ownership_percent"):
        ownership_score = float(ownership.get_ownership_percent("renew_co", "founder"))
    return {
        "valuation": valuation, "revenue": revenue, "profit": profit, "assets": assets,
        "market_share": max(0.0, float(main.get("market_share")) if main.get("market_share") != null else 0.0), "employees": employee_count,
        "technology": float(main.get("technology_level")) if main.get("technology_level") != null else 0.0, "infrastructure": infra_score,
        "regional_presence": float(main.get("regions_unlocked")) if main.get("regions_unlocked") != null else 1.0, "reputation": reputation,
        "resource_control": float(main.get("resource_control")) if main.get("resource_control") != null else 0.0, "alliance_influence": alliance_score + ownership_score
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
