extends Node

## V3.1: victory conditions. Three paths end a campaign with prestige:
## TYCOON (valuation >= $1M), MONOPOLIST (50+ shares in one rival or 2
## buyouts), HEGEMON (3 challenge wins with an alliance of level 3+).
## Wins are recorded once into GameState plus the corporate legacy.
const TYCOON_GOAL := 1000000.0
const MONOPOLY_SHARES := 50
const MONOPOLY_BUYOUTS := 2
const HEGEMON_WINS := 3
const HEGEMON_LEVEL := 3
const PRESTIGE_PATH := "user://renew_prestige.json"
const PRESTIGE_CASH_PER_WIN := 25000
const PRESTIGE_CASH_CAP := 100000
const PRESTIGE_REP_PER_MONOPOLIST := 5
const PRESTIGE_REP_CAP := 20
const PRESTIGE_RESEARCH_PER_HEGEMON := 10

var prestige: Dictionary = {}

func _ready() -> void:
	_load_prestige()

func _state() -> Variant:
	return get_node_or_null("/root/RenewGameState")

func _finance() -> Variant:
	return get_node_or_null("/root/RenewFinanceSystem")

func _service(service_name: String) -> Variant:
	var registry := get_node_or_null("/root/RenewServices")
	if registry != null and registry.has_method("get_service"):
		var node = registry.get_service(service_name)
		if node != null:
			return node
	return get_node_or_null("/root/" + service_name)

func _alliance_system() -> Variant:
	return get_node_or_null("/root/RenewAllianceSystem")

func _day() -> int:
	var state: Variant = _state()
	return int(state.get_value("player", "day", 1)) if state != null else 1

func net_valuation() -> float:
	var finance: Variant = _finance()
	if finance != null and finance.has_method("valuation"):
		return maxf(0.0, float(finance.call("valuation")))
	return 0.0

func monopoly_standing() -> Dictionary:
	var state: Variant = _state()
	var lots: Array = []
	if state != null:
		var raw: Variant = state.get_value("ownership", "holdings", [])
		if raw is Array:
			lots = raw
	var best := 0
	for holding in lots:
		if holding is Dictionary:
			best = maxi(best, int(holding.get("shares", 0)))
	var buyouts := 0
	if state != null:
		buyouts = int(state.get_value("ownership", "acquisition_count", 0))
	return {"best_shares": best, "buyouts": buyouts}

func hegemon_standing() -> Dictionary:
	var system: Variant = _alliance_system()
	if system == null or not system.has_method("get_member_alliance"):
		return {"wins": 0, "level": 0, "has_alliance": false}
	var pact: Dictionary = system.get_member_alliance("player")
	if pact.is_empty():
		return {"wins": 0, "level": 0, "has_alliance": false}
	return {"wins": int(pact.get("challenge_wins", 0)), "level": int(pact.get("level", 1)), "has_alliance": true}

func progress() -> Dictionary:
	var worth := net_valuation()
	var mono := monopoly_standing()
	var hege := hegemon_standing()
	var mono_current := maxi(int(mono["best_shares"]), int(mono["buyouts"]) * MONOPOLY_SHARES / MONOPOLY_BUYOUTS)
	return {
		"tycoon": {"current": worth, "goal": TYCOON_GOAL, "pct": _pct(worth, TYCOON_GOAL), "done": worth >= TYCOON_GOAL},
		"monopolist": {"current": mono_current, "goal": MONOPOLY_SHARES, "pct": _pct(float(mono_current), float(MONOPOLY_SHARES)), "done": int(mono["best_shares"]) >= MONOPOLY_SHARES or int(mono["buyouts"]) >= MONOPOLY_BUYOUTS, "shares": int(mono["best_shares"]), "buyouts": int(mono["buyouts"])},
		"hegemon": {"current": int(hege["wins"]), "goal": HEGEMON_WINS, "pct": _pct(float(hege["wins"]), float(HEGEMON_WINS)), "done": int(hege["wins"]) >= HEGEMON_WINS and int(hege["level"]) >= HEGEMON_LEVEL, "level": int(hege["level"]), "has_alliance": bool(hege["has_alliance"])}
	}

func progress_text() -> String:
	var p := progress()
	var t: Dictionary = p["tycoon"]
	var m: Dictionary = p["monopolist"]
	var h: Dictionary = p["hegemon"]
	var text := "GOALS — Tycoon: $%s / $1M (%d%%). Monopolist: %d shares, %d buyouts (%d%%). Hegemon: %d wins, level %d (%d%%)." % [_money(float(t["current"])), int(t["pct"]), int(m["shares"]), int(m["buyouts"]), int(m["pct"]), int(h["current"]), int(h["level"]), int(h["pct"])]
	if prestige_wins() > 0:
		var b := prestige_bonuses()
		text += " LEGACY: %d victories — heirs start with +$%s, +%d rep, +%d research." % [prestige_wins(), _money(float(b["starting_cash"])), int(b["starting_reputation"]), int(b["starting_research"])]
	return text

func stored_victory() -> Dictionary:
	var state: Variant = _state()
	if state == null:
		return {}
	var claimed: Variant = state.get_value("progression", "milestones", {})
	if not claimed is Dictionary:
		return {}
	for key in (claimed as Dictionary).keys():
		if str(key).begins_with("victory_"):
			var record: Variant = (claimed as Dictionary)[key]
			if record is Dictionary:
				return record
	return {}

func check_victory() -> Dictionary:
	var prior := stored_victory()
	if not prior.is_empty():
		return {"ok": false, "already": true, "path": str(prior.get("path", ""))}
	var p := progress()
	var path := ""
	if bool(p["tycoon"]["done"]):
		path = "tycoon"
	elif bool(p["monopolist"]["done"]):
		path = "monopolist"
	elif bool(p["hegemon"]["done"]):
		path = "hegemon"
	if path.is_empty():
		return {"ok": false}
	var record := {"path": path, "day": _day()}
	var state: Variant = _state()
	if state != null:
		var claimed: Variant = state.get_value("progression", "milestones", {})
		var table: Dictionary = (claimed as Dictionary).duplicate(true) if claimed is Dictionary else {}
		table["victory_" + path] = record
		state.set_value("progression", "milestones", table)
	var legacy := get_node_or_null("/root/RenewCorporateLegacy")
	if legacy != null and legacy.has_method("record_award"):
		legacy.record_award("Campaign victory: %s" % path.capitalize(), {"path": path, "day": _day()})
	_bank_prestige(path)
	_announce("VICTORY — %s! %s" % [path.capitalize(), _epithet(path)])
	return {"ok": true, "path": path, "day": _day()}

func prestige_wins() -> int:
	return int(prestige.get("wins_total", 0))

func prestige_path_wins(path: String) -> int:
	var paths: Variant = prestige.get("paths", {})
	if paths is Dictionary:
		return int((paths as Dictionary).get(path, 0))
	return 0

func prestige_bonuses() -> Dictionary:
	var cash: int = mini(prestige_wins() * PRESTIGE_CASH_PER_WIN, PRESTIGE_CASH_CAP)
	var rep: int = mini(prestige_path_wins("monopolist") * PRESTIGE_REP_PER_MONOPOLIST, PRESTIGE_REP_CAP)
	var research: int = prestige_path_wins("hegemon") * PRESTIGE_RESEARCH_PER_HEGEMON
	return {"starting_cash": cash, "starting_reputation": rep, "starting_research": research}

func found_new_company() -> Dictionary:
	var prior := stored_victory()
	if prior.is_empty():
		return {"ok": false, "message": "Only victorious founders can start a new dynasty."}
	_load_prestige()
	var bonuses := prestige_bonuses()
	var state: Variant = _state()
	if state != null and state.has_method("clear"):
		state.clear()
	var finance: Variant = _finance()
	if finance != null:
		finance.set("financing", {})
		finance.set("debt", 0)
		finance.set("loan_payment", 0)
		finance.set("revenue", 0.0)
		finance.set("operating_expenses", 0.0)
		finance.set("interest_expense", 0.0)
		finance.set("retained_earnings", 0.0)
		finance.set("equity_contributed", 25000.0 + float(bonuses["starting_cash"]))
		finance.set("cash", 25000 + int(bonuses["starting_cash"]))
	if state != null:
		state.set_value("player", "reputation", int(bonuses["starting_reputation"]))
		state.set_value("technology", "research_points", 20 + int(bonuses["starting_research"]))
	_reset_satellites()
	_announce("A new dynasty begins with $%s in heir capital." % _money(25000.0 + float(bonuses["starting_cash"])))
	return {"ok": true, "bonuses": bonuses, "prior_path": str(prior.get("path", ""))}

func _reset_satellites() -> void:
	var world := _service("RenewWorldEventSystem")
	if world != null and world.has_method("restore_state"):
		world.restore_state({})
	var liveops := _service("RenewLiveOpsSystem")
	if liveops != null:
		liveops.set("current_season", 1)
		liveops.set("season_start_day", 1)
		liveops.set("offers", {})
		liveops.set("challenges", {})
		var goal: Variant = liveops.get("community_goal")
		if goal is Dictionary:
			(goal as Dictionary)["progress"] = 0.0
		liveops.set("last_day", -1)
	var history := _service("RenewHistorySystem")
	if history != null and history.has_method("restore_state"):
		history.restore_state({})
	var news := _service("RenewNewsSystem")
	if news != null and news.has_method("restore_state"):
		news.restore_state({})
	var bridge := _service("RenewDiplomacyControl")
	if bridge != null and bridge.has_method("restore_state"):
		bridge.restore_state({})
	var scene: Variant = get_tree().current_scene if get_tree() != null else null
	if scene != null:
		var commands = scene.get_node_or_null("GameplayCommandSystem")
		if commands != null:
			var relationships = commands.get("relationship_system")
			if relationships != null:
				var model = relationships.get("rivals")
				if model != null and model.has_method("reset_to_founding"):
					model.reset_to_founding()

func _bank_prestige(path: String) -> void:
	_load_prestige()
	prestige["wins_total"] = prestige_wins() + 1
	var paths: Variant = prestige.get("paths", {})
	var table: Dictionary = (paths as Dictionary).duplicate(true) if paths is Dictionary else {}
	table[path] = int(table.get(path, 0)) + 1
	prestige["paths"] = table
	_save_prestige()

func _load_prestige() -> void:
	prestige = {}
	if not FileAccess.file_exists(PRESTIGE_PATH):
		return
	var file := FileAccess.open(PRESTIGE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		prestige = parsed

func _save_prestige() -> void:
	var file := FileAccess.open(PRESTIGE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(prestige))

func _pct(current: float, goal: float) -> int:
	if goal <= 0.0:
		return 100
	return clampi(int(round(current / goal * 100.0)), 0, 100)

func _money(amount: float) -> String:
	if amount >= 1000000.0:
		return "%.2fM" % (amount / 1000000.0)
	if amount >= 1000.0:
		return "%.1fK" % (amount / 1000.0)
	return str(int(amount))

func _epithet(path: String) -> String:
	match path:
		"tycoon":
			return "A seven-figure empire stands where a warehouse stood."
		"monopolist":
			return "The market answers to one name now."
		"hegemon":
			return "Every alliance banner flies your colors."
	return "The city is yours."

func has_fired(flag: String) -> bool:
	var state: Variant = _state()
	if state == null:
		return false
	var claimed: Variant = state.get_value("progression", "milestones", {})
	return claimed is Dictionary and (claimed as Dictionary).has(flag)

func _mark_fired(flag: String, day: int) -> void:
	var state: Variant = _state()
	if state == null:
		return
	var claimed: Variant = state.get_value("progression", "milestones", {})
	var table: Dictionary = (claimed as Dictionary).duplicate(true) if claimed is Dictionary else {}
	table[flag] = {"day": day}
	state.set_value("progression", "milestones", table)

func maybe_endgame_crisis(day: int = -1) -> Dictionary:
	var d: int = day if day >= 0 else _day()
	var p := progress()
	var state: Variant = _state()
	if state == null:
		return {}
	if not has_fired("crisis_market_crash") and d >= 60 and float(p["tycoon"]["pct"]) >= 70.0:
		return _fire_market_crash(d)
	if not has_fired("crisis_antitrust") and int(p["monopolist"]["shares"]) >= 30:
		return _fire_antitrust(d)
	if not has_fired("crisis_schism") and int(p["hegemon"]["current"]) >= 2:
		return _fire_schism(d)
	return {}

func _fire_market_crash(day: int) -> Dictionary:
	var finance: Variant = _finance()
	var target_loss := 150000.0
	if finance != null and float(finance.get("cash")) >= 100000.0:
		target_loss = 75000.0
	var loss := 0.0
	if finance != null and finance.has_method("spend"):
		var affordable: int = maxi(0, mini(int(target_loss), int(finance.get("cash"))))
		if affordable > 0:
			finance.spend(affordable, "market crash")
			loss = float(affordable)
	_mark_fired("crisis_market_crash", day)
	_record_crisis("market_crash", day, {"loss": loss})
	var text := "MARKET CRASH — panic selling wipes $%s off your books." % _money(loss)
	if loss < 150000.0:
		text += " Deep cash reserves cushioned the fall."
	_announce(text)
	return {"ok": true, "id": "market_crash", "loss": loss}

func _fire_antitrust(day: int) -> Dictionary:
	var state: Variant = _state()
	var seized := 20
	if int(state.get_value("player", "reputation", 0)) >= 60:
		seized = 10
	var lots: Variant = state.get_value("ownership", "holdings", [])
	var remaining := seized
	if lots is Array:
		var arr: Array = lots as Array
		while remaining > 0:
			var biggest: Dictionary = {}
			for holding in arr:
				if holding is Dictionary and int(holding.get("shares", 0)) > int(biggest.get("shares", 0)):
					biggest = holding
			if biggest.is_empty():
				break
			var take: int = mini(remaining, int(biggest.get("shares", 0)))
			biggest["shares"] = int(biggest.get("shares", 0)) - take
			remaining -= take
		var cleaned: Array = []
		for holding in arr:
			if holding is Dictionary and int(holding.get("shares", 0)) > 0:
				cleaned.append(holding)
		state.set_value("ownership", "holdings", cleaned)
	var taken := seized - remaining
	_mark_fired("crisis_antitrust", day)
	_record_crisis("antitrust", day, {"shares_seized": taken})
	var text := "ANTITRUST RULING — regulators seize %d of your rival shares." % taken
	if seized < 20:
		text += " Your lobbyists softened the ruling."
	_announce(text)
	return {"ok": true, "id": "antitrust", "shares_seized": taken}

func _fire_schism(day: int) -> Dictionary:
	var system: Variant = _alliance_system()
	var trust_hit := 15.0
	var treasury_hit := 2000
	if system != null and system.has_method("get_member_alliance"):
		var pact: Dictionary = system.get_member_alliance("player")
		if not pact.is_empty() and int(pact.get("level", 1)) >= 4:
			trust_hit = 5.0
			treasury_hit = 500
	_apply_schism(trust_hit, treasury_hit)
	_mark_fired("crisis_schism", day)
	_record_crisis("schism", day, {"trust_hit": trust_hit, "treasury_hit": treasury_hit})
	var text := "ALLIANCE SCHISM — a rival faction splits your pact (-%d trust, -$%s treasury)." % [int(trust_hit), _money(float(treasury_hit))]
	if trust_hit < 15.0:
		text += " Your elders hold the pact together."
	_announce(text)
	return {"ok": true, "id": "schism", "trust_hit": trust_hit}

func _apply_schism(trust_hit: float, treasury_hit: int) -> void:
	var state: Variant = _state()
	if state == null:
		return
	var table: Variant = state.get_value("alliances", "alliances", {})
	if not table is Dictionary:
		return
	for key in (table as Dictionary).keys():
		var pact: Variant = (table as Dictionary)[key]
		if pact is Dictionary and (pact as Dictionary).get("members", {}).has("player"):
			(pact as Dictionary)["trust"] = clampf(float((pact as Dictionary).get("trust", 50.0)) - trust_hit, 0.0, 100.0)
			(pact as Dictionary)["treasury"] = maxi(0, int((pact as Dictionary).get("treasury", 0)) - treasury_hit)
	state.set_value("alliances", "alliances", table)

func _record_crisis(crisis_id: String, day: int, details: Dictionary) -> void:
	var legacy := get_node_or_null("/root/RenewCorporateLegacy")
	if legacy != null and legacy.has_method("record"):
		var info := details.duplicate(true)
		info["day"] = day
		legacy.call("record", "endgame_crisis", crisis_id, info, day)

func _announce(text: String) -> void:
	var state: Variant = _state()
	if state == null:
		return
	var line := text if text.begins_with("EVENT:") else "EVENT: " + text
	state.set_value("company", "message", line)
	var logs: Variant = state.get_value("company", "log_lines", [])
	if logs is Array:
		var lines: Array = (logs as Array).duplicate(true)
		lines.append(line)
		while lines.size() > 100:
			lines.pop_front()
		state.set_value("company", "log_lines", lines)

func capture_state() -> Dictionary:
	return {}

func restore_state(_state_data: Dictionary) -> void:
	pass