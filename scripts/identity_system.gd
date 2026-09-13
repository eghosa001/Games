extends Node

## V8.3: player identities. Eight paths with three tiers each reward how the
## player actually plays; claims persist in progression/claimed_goals.
const IDENTITIES := [
    {"id": "builder", "title": "Builder", "metric": "restored", "tiers": [1, 3, 6]},
    {"id": "tycoon", "title": "Tycoon", "metric": "valuation", "tiers": [100000.0, 500000.0, 1000000.0]},
    {"id": "industrialist", "title": "Industrialist", "metric": "businesses", "tiers": [1, 2, 4]},
    {"id": "diplomat", "title": "Diplomat", "metric": "allies", "tiers": [2, 3, 5]},
    {"id": "innovator", "title": "Innovator", "metric": "technologies", "tiers": [1, 3, 6]},
    {"id": "collector", "title": "Collector", "metric": "assets", "tiers": [2, 4, 7]},
    {"id": "magnate", "title": "Magnate", "metric": "industries", "tiers": [1, 2, 3]},
    {"id": "competitor", "title": "Competitor", "metric": "takeovers", "tiers": [1, 2, 4]},
]
const TIER_REWARDS := [
    {"cash": 500, "rep": 2},
    {"cash": 2000, "rep": 4},
    {"cash": 5000, "rep": 8},
]

func _state() -> Variant:
    return get_node_or_null("/root/RenewGameState")

func _finance() -> Variant:
    return get_node_or_null("/root/RenewFinanceSystem")

func _alliance_system() -> Variant:
    return get_node_or_null("/root/RenewAllianceSystem")

func metric_value(metric: String) -> float:
    var state: Variant = _state()
    if state == null:
        return 0.0
    match metric:
        "restored":
            var count := 0
            var catalog: Variant = state.get_value("properties", "catalog", [])
            if catalog is Array:
                for entry in (catalog as Array):
                    if entry is Dictionary and int((entry as Dictionary).get("furnishing", 0)) >= 100:
                        count += 1
            return float(count)
        "valuation":
            var finance: Variant = _finance()
            if finance != null and finance.has_method("valuation"):
                return maxf(0.0, float(finance.call("valuation")))
            return 0.0
        "businesses":
            var total := 0
            if bool(state.get_value("businesses", "business_open", false)):
                total += 1
            var expansion: Variant = state.get_value("branches", "expansion", {})
            if expansion is Dictionary:
                total += (expansion as Dictionary).size()
            return float(total)
        "allies":
            var system: Variant = _alliance_system()
            if system != null and system.has_method("get_member_alliance"):
                var pact: Dictionary = system.get_member_alliance("player")
                if not pact.is_empty():
                    return float((pact.get("members", {}) as Dictionary).size())
            return 0.0
        "technologies":
            var tech: Variant = state.get_value("technology", "technology", {})
            if tech is Dictionary:
                var n := 0
                for key in (tech as Dictionary).keys():
                    var entry: Variant = (tech as Dictionary)[key]
                    if (entry is Dictionary and bool((entry as Dictionary).get("researched", false))) or (entry is bool and bool(entry)):
                        n += 1
                return float(n)
            return 0.0
        "assets":
            return metric_value("restored") + metric_value("businesses")
        "industries":
            var seen := {}
            var current := str(state.get_value("businesses", "industry_id", ""))
            if not current.is_empty():
                seen[current] = true
            var sites: Variant = state.get_value("branches", "expansion", {})
            if sites is Dictionary:
                for key in (sites as Dictionary).keys():
                    var site: Variant = (sites as Dictionary)[key]
                    if site is Dictionary and not str((site as Dictionary).get("industry", "")).is_empty():
                        seen[str((site as Dictionary).get("industry", ""))] = true
            return float(seen.size())
        "takeovers":
            var score := int(state.get_value("ownership", "acquisition_count", 0))
            var lots: Variant = state.get_value("ownership", "holdings", [])
            if lots is Array:
                for holding in (lots as Array):
                    if holding is Dictionary and int((holding as Dictionary).get("shares", 0)) >= 50:
                        score += 1
            return float(score)
    return 0.0

func claimed() -> Dictionary:
    var state: Variant = _state()
    if state == null:
        return {}
    var raw: Variant = state.get_value("progression", "claimed_goals", {})
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}

func progress() -> Array:
    var table := claimed()
    var out: Array = []
    for identity in IDENTITIES:
        var value := metric_value(str(identity["metric"]))
        var reached := 0
        var tiers: Array = identity["tiers"]
        for i in range(tiers.size()):
            if value >= float(tiers[i]):
                reached = i + 1
        out.append({"id": str(identity["id"]), "title": str(identity["title"]), "value": value, "next": tiers[reached] if reached < tiers.size() else null, "claimed": reached, "total": tiers.size()})
    return out

func status_text() -> String:
    var parts: Array = []
    for row in progress():
        parts.append("%s %d/%d" % [str(row["title"]), int(row["claimed"]), int(row["total"])])
    return "IDENTITIES — " + ", ".join(parts) + "."

func evaluate() -> Array:
    var state: Variant = _state()
    if state == null:
        return []
    var table := claimed()
    var awarded: Array = []
    for identity in IDENTITIES:
        var value := metric_value(str(identity["metric"]))
        var tiers: Array = identity["tiers"]
        for i in range(tiers.size()):
            var key := "identity_%s_%d" % [str(identity["id"]), i + 1]
            if bool(table.get(key, false)):
                continue
            if value < float(tiers[i]):
                continue
            table[key] = true
            var reward: Dictionary = TIER_REWARDS[i]
            var finance: Variant = _finance()
            if finance != null and finance.has_method("receive"):
                finance.receive(int(reward["cash"]), "identity reward: %s %d" % [str(identity["title"]), i + 1])
            state.set_value("player", "reputation", int(state.get_value("player", "reputation", 0)) + int(reward["rep"]))
            var legacy := get_node_or_null("/root/RenewCorporateLegacy")
            if legacy != null and legacy.has_method("record_award"):
                legacy.record_award("Identity: %s %d" % [str(identity["title"]), i + 1], {"identity": str(identity["id"]), "tier": i + 1})
            _announce("IDENTITY: %s %d — %s (+$%s, +%d rep)." % [str(identity["title"]), i + 1, _tier_name(i), _money(int(reward["cash"])), int(reward["rep"])])
            awarded.append({"id": str(identity["id"]), "tier": i + 1})
    if not awarded.is_empty():
        state.set_value("progression", "claimed_goals", table)
    return awarded

func _tier_name(tier: int) -> String:
    return ["Apprentice", "Established", "Legendary"][clampi(tier, 0, 2)]

func _money(amount: int) -> String:
    if amount >= 1000:
        return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)

func _announce(text: String) -> void:
    var state: Variant = _state()
    if state == null:
        return
    state.set_value("company", "message", text)
    var logs: Variant = state.get_value("company", "log_lines", [])
    if logs is Array:
        var lines: Array = (logs as Array).duplicate(true)
        lines.append(text)
        while lines.size() > 100:
            lines.pop_front()
        state.set_value("company", "log_lines", lines)

func capture_state() -> Dictionary:
    return {"claimed_goals": claimed().duplicate(true)}

func restore_state(state_data: Dictionary) -> void:
    if state_data.is_empty():
        return
    var state: Variant = _state()
    if state == null:
        return
    var raw: Variant = state_data.get("claimed_goals", {})
    if raw is Dictionary:
        state.set_value("progression", "claimed_goals", (raw as Dictionary).duplicate(true))
