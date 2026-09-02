extends RefCounted
class_name RenewCompetitors

# Persistent corporate agents. Every rival owns a durable corporate profile and
# runs Observe -> Evaluate -> Select -> Execute -> Record -> Remember.
var rivals := [
    {"id":"corp_giant","name":"The Giant","personality":"dominant","cash":500000,"debt":120000,"assets":6,"businesses":4,"employees":85,"technology":2,"price":105,"relationship":-20,"stance":"Aggressive","strength":"capital","districts":[0],"presence":1,"supplier_pressure":0,"suppliers":["National Steel","Bulk Energy"],"customers":["Mass Retail","Municipal Buyers"],"risk_tolerance":0.85,"strategic_priorities":["market_share","acquisitions","price_control"],"memory":[],"last_observation":{},"last_evaluation":{},"last_strategy":"","last_action":"","last_result":{},"strategy_cooldown":0,"offer_cooldown":0,"deal":"none","deal_days":0,"retaliation":0},
    {"id":"corp_specialist","name":"The Specialist","personality":"disciplined","cash":90000,"debt":25000,"assets":3,"businesses":2,"employees":34,"technology":4,"price":118,"relationship":5,"stance":"Efficient","strength":"quality","districts":[1],"presence":1,"supplier_pressure":0,"suppliers":["Precision Components","Certified Timber"],"customers":["Premium Retail","Hospitality Chains"],"risk_tolerance":0.35,"strategic_priorities":["quality","technology","premium_customers"],"memory":[],"last_observation":{},"last_evaluation":{},"last_strategy":"","last_action":"","last_result":{},"strategy_cooldown":0,"offer_cooldown":0,"deal":"none","deal_days":0,"retaliation":0},
    {"id":"corp_network","name":"The Network","personality":"opportunistic","cash":180000,"debt":60000,"assets":5,"businesses":3,"employees":52,"technology":3,"price":125,"relationship":15,"stance":"Connected","strength":"suppliers","districts":[2],"presence":1,"supplier_pressure":1,"suppliers":["River Port Authority","Regional Fuel Consortium","Independent Producers"],"customers":["Regional Distributors","Export Buyers"],"risk_tolerance":0.65,"strategic_priorities":["supply_control","logistics","alliances"],"memory":[],"last_observation":{},"last_evaluation":{},"last_strategy":"","last_action":"","last_result":{},"strategy_cooldown":0,"offer_cooldown":0,"deal":"none","deal_days":0,"retaliation":0}
]

func _normalize() -> void:
    for r in rivals:
        if not r.has("id"): r["id"] = "corp_" + str(r.get("name", "rival")).to_lower().replace(" ", "_")
        var defaults := {"personality":"balanced","debt":0,"assets":1,"businesses":1,"employees":10,"technology":1,"suppliers":[],"customers":[],"risk_tolerance":0.5,"strategic_priorities":[],"memory":[],"last_observation":{},"last_evaluation":{},"last_strategy":"","last_action":"","last_result":{},"strategy_cooldown":0}
        for key in defaults:
            if not r.has(key): r[key] = defaults[key]
        if not r.has("districts"): r["districts"] = [0]
        if not r.has("presence"): r["presence"] = 1
        if not r.has("supplier_pressure"): r["supplier_pressure"] = 0
        if not r.has("offer_cooldown"): r["offer_cooldown"] = 0
        if not r.has("deal"): r["deal"] = "none"
        if not r.has("deal_days"): r["deal_days"] = 0
        if not r.has("retaliation"): r["retaliation"] = 0

func daily_update(day: int) -> Array[String]:
    _normalize()
    var news: Array[String] = []
    for rival in rivals:
        if rival["name"] == "The Giant":
            if day % 3 == 0:
                rival["price"] = max(82, int(rival["price"]) - 4); news.append("The Giant cuts prices to $%d." % rival["price"])
            else: rival["cash"] += 2500
        elif rival["name"] == "The Specialist" and day % 4 == 0:
            rival["price"] = max(92, int(rival["price"]) - 2); rival["technology"] = int(rival["technology"]) + 1; news.append("The Specialist improves efficiency and lowers prices.")
        elif rival["name"] == "The Network" and day % 5 == 0:
            rival["supplier_pressure"] = min(3, int(rival["supplier_pressure"]) + 1); news.append("The Network locks down a major supplier agreement.")
        if int(rival["retaliation"]) > 0:
            rival["retaliation"] = int(rival["retaliation"]) - 1
            if int(rival["retaliation"]) == 0: news.append("%s has cooled its retaliation campaign." % rival["name"])
        if int(rival["offer_cooldown"]) > 0: rival["offer_cooldown"] = int(rival["offer_cooldown"]) - 1
        if int(rival["deal_days"]) > 0:
            rival["deal_days"] = int(rival["deal_days"]) - 1
            if int(rival["deal_days"]) == 0: rival["deal"] = "none"; news.append("%s strategic deal has expired." % rival["name"])
    return news

# Full corporate AI loop. player_state is observational input only; the player
# never directly mutates an agent's strategic state.
func strategic_ai_update(day: int, player_state: Dictionary = {}) -> Array[String]:
    _normalize()
    var news: Array[String] = []
    for i in range(rivals.size()):
        var r = rivals[i]
        var observation := _observe(r, day, player_state)
        var evaluation := _evaluate(r, observation)
        var strategy := _select_strategy(r, evaluation, day)
        var action := _execute_strategy(r, strategy, observation, day)
        var result := _record_result(r, action, observation, evaluation)
        r["last_observation"] = observation
        r["last_evaluation"] = evaluation
        r["last_strategy"] = strategy
        r["last_action"] = action
        r["last_result"] = result
        var memory_entry := {"day":day,"strategy":strategy,"action":action,"result":result}
        r["memory"].append(memory_entry)
        if r["memory"].size() > 30: r["memory"].pop_front()
        if not str(result.get("news", "")).is_empty(): news.append(str(result["news"]))
    return news

func _observe(r: Dictionary, day: int, player: Dictionary) -> Dictionary:
    var player_cash := int(player.get("cash", 0))
    var player_rep := int(player.get("reputation", 0))
    var player_price := int(player.get("player_price", 110))
    var player_district := int(player.get("selected_district", 0))
    var target_pressure := 0.0
    if player_district in r["districts"]: target_pressure = 1.0
    return {"day":day,"player_cash":player_cash,"player_reputation":player_rep,"player_price":player_price,"player_district":player_district,"player_threat":clamp(float(player_rep) / 50.0 + float(player.get("acquisition_count", 0)) * 0.12, 0.0, 2.0),"own_cash":int(r["cash"]),"own_debt":int(r["debt"]),"own_assets":int(r["assets"]),"own_businesses":int(r["businesses"]),"own_employees":int(r["employees"]),"own_technology":int(r["technology"]),"own_presence":int(r["presence"]),"district_pressure":target_pressure,"relationship":int(r["relationship"]),"supplier_pressure":int(r["supplier_pressure"])}

func _evaluate(r: Dictionary, o: Dictionary) -> Dictionary:
    var liquidity := float(o["own_cash"]) / max(1.0, float(o["own_debt"]) + 50000.0)
    var threat := float(o["player_threat"])
    var growth_need := clamp(1.0 - float(o["own_presence"]) / 3.0, 0.0, 1.0)
    var supplier_need := clamp(float(o["supplier_pressure"]) / 3.0, 0.0, 1.0)
    var quality_edge := 1.0 if str(r["strength"]) == "quality" else 0.35
    var priorities: Array = r["strategic_priorities"]
    return {"liquidity":liquidity,"threat":threat,"growth_need":growth_need,"supplier_need":supplier_need,"quality_edge":quality_edge,"risk_budget":float(r["risk_tolerance"]),"priority_count":priorities.size()}

func _select_strategy(r: Dictionary, e: Dictionary, day: int) -> String:
    if int(r["strategy_cooldown"]) > 0:
        r["strategy_cooldown"] = int(r["strategy_cooldown"]) - 1
        return "maintain"
    var personality := str(r["personality"])
    if e["threat"] >= 1.0 and personality == "dominant": return "pressure_player"
    if e["supplier_need"] >= 0.66 or "supply_control" in r["strategic_priorities"]: return "secure_supply"
    if e["quality_edge"] > 0.8 and "technology" in r["strategic_priorities"]: return "invest_technology"
    if e["growth_need"] > 0.45 and e["liquidity"] > 0.9: return "expand_region"
    if e["threat"] >= 0.7 and int(r["relationship"]) >= 25: return "build_alliance"
    if day % 11 == 0 and e["liquidity"] > 0.7: return "acquire_asset"
    return "optimize_operations"

func _execute_strategy(r: Dictionary, strategy: String, o: Dictionary, day: int) -> String:
    match strategy:
        "pressure_player":
            r["price"] = max(78, int(r["price"]) - 2)
            r["retaliation"] = max(int(r["retaliation"]), 3)
            r["strategy_cooldown"] = 2
            return "cut_prices"
        "secure_supply":
            r["supplier_pressure"] = max(0, int(r["supplier_pressure"]) - 1)
            if "Strategic Reserve" not in r["suppliers"]: r["suppliers"].append("Strategic Reserve")
            r["assets"] = int(r["assets"]) + 1
            r["cash"] = max(0, int(r["cash"]) - 4500)
            r["strategy_cooldown"] = 3
            return "secure_supplier"
        "invest_technology":
            if int(r["cash"]) >= 6000:
                r["cash"] -= 6000; r["technology"] = int(r["technology"]) + 1
                r["strategy_cooldown"] = 4; return "upgrade_technology"
            return "defer_technology"
        "expand_region":
            if int(r["cash"]) >= 12000:
                var target := (int(r["districts"].back()) + 1) % 4
                if not target in r["districts"]: r["districts"].append(target)
                r["presence"] = min(3, int(r["presence"]) + 1); r["businesses"] = int(r["businesses"]) + 1; r["assets"] = int(r["assets"]) + 1; r["employees"] = int(r["employees"]) + 8; r["cash"] -= 12000
                r["strategy_cooldown"] = 5; return "open_regional_operation"
            return "defer_expansion"
        "build_alliance":
            r["relationship"] = min(100, int(r["relationship"]) + 4)
            r["deal"] = "alliance"; r["deal_days"] = 8; r["strategy_cooldown"] = 4
            return "form_strategic_alliance"
        "acquire_asset":
            if int(r["cash"]) >= 10000:
                r["cash"] -= 10000; r["assets"] = int(r["assets"]) + 1; r["businesses"] = int(r["businesses"]) + 1; r["employees"] = int(r["employees"]) + 5; r["strategy_cooldown"] = 6; return "acquire_business_asset"
            return "defer_acquisition"
        _:
            r["cash"] += 1500 + int(r["businesses"]) * 100; r["employees"] = max(1, int(r["employees"])); r["strategy_cooldown"] = 1; return "optimize_operations"

func _record_result(r: Dictionary, action: String, o: Dictionary, e: Dictionary) -> Dictionary:
    var delta_cash := int(r["cash"]) - int(o["own_cash"])
    var result := {"action":action,"cash_delta":delta_cash,"assets":int(r["assets"]),"businesses":int(r["businesses"]),"employees":int(r["employees"]),"technology":int(r["technology"]),"presence":int(r["presence"]),"success":true,"news":""}
    if action == "cut_prices": result["news"] = "%s responded to your growth with a competitive price move." % r["name"]
    elif action == "secure_supplier": result["news"] = "%s secured another supply relationship and strengthened its network." % r["name"]
    elif action == "upgrade_technology": result["news"] = "%s invested in new technology." % r["name"]
    elif action == "open_regional_operation": result["news"] = "%s opened a new regional operation." % r["name"]
    elif action == "form_strategic_alliance": result["news"] = "%s is building a strategic alliance network." % r["name"]
    elif action == "acquire_business_asset": result["news"] = "%s acquired another business asset." % r["name"]
    return result

func ai_status(index: int) -> Dictionary:
    _normalize()
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    return {"ok":true,"id":r["id"],"name":r["name"],"personality":r["personality"],"cash":r["cash"],"debt":r["debt"],"assets":r["assets"],"businesses":r["businesses"],"employees":r["employees"],"technology":r["technology"],"districts":r["districts"],"suppliers":r["suppliers"],"customers":r["customers"],"risk_tolerance":r["risk_tolerance"],"strategic_priorities":r["strategic_priorities"],"last_strategy":r["last_strategy"],"last_action":r["last_action"],"memory_size":r["memory"].size()}

func retaliation_after_acquisition(index: int) -> Dictionary:
    _normalize()
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    var pressure_gain := 1 if index != 1 else 0
    r["retaliation"] = max(int(r["retaliation"]), 6); r["offer_cooldown"] = max(int(r["offer_cooldown"]), 6); r["relationship"] = max(-100, int(r["relationship"]) - 12); r["supplier_pressure"] = min(3, int(r["supplier_pressure"]) + pressure_gain); r["price"] = max(78, int(r["price"]) - (3 if index == 0 else 1))
    return {"ok":true,"message":"%s retaliated: competition intensified for the next several days." % r["name"]}

func strategic_update(day: int, selected_district: int, reputation: int) -> Array[String]:
    return strategic_ai_update(day, {"selected_district":selected_district,"reputation":reputation})

func competitive_status(index: int) -> Dictionary:
    _normalize()
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    return {"ok":true,"name":r["name"],"stance":r["stance"],"strength":r["strength"],"relationship":int(r["relationship"]),"presence":int(r["presence"]),"supplier_pressure":int(r["supplier_pressure"]),"retaliation_days":int(r["retaliation"]),"message":"%s — %s. Strength: %s. Presence %d." % [r["name"],r["stance"],r["strength"],int(r["presence"])]}

func _district_name(index: int) -> String:
    var names := ["Old Market","Industrial Belt","River Port","North Growth Corridor"]
    return names[index] if index >= 0 and index < names.size() else "Unknown District"

func district_pressure(district_index: int) -> float:
    _normalize(); var pressure := 0.0
    for rival in rivals:
        if district_index in rival["districts"]:
            pressure += 0.05 * float(rival["presence"])
            if int(rival["retaliation"]) > 0: pressure += 0.025
    return pressure

func supplier_pressure(district_index: int) -> int:
    _normalize(); var pressure := 0
    for rival in rivals:
        if district_index in rival["districts"]: pressure += int(rival["supplier_pressure"])
    return pressure

func improve_relationship(index: int) -> String:
    if index < 0 or index >= rivals.size(): return "Unknown company."
    rivals[index]["relationship"] = min(100, int(rivals[index]["relationship"]) + 5)
    return "Relationship with %s improved to %d." % [rivals[index]["name"], rivals[index]["relationship"]]

func offer_alliance(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    if int(r["relationship"]) >= 35:
        r["relationship"] = min(100, int(r["relationship"]) + 3); r["deal"] = "alliance"; r["deal_days"] = 12
        return {"ok":true,"message":"%s accepted a 12-day strategic alliance." % r["name"]}
    r["relationship"] = min(100, int(r["relationship"]) + 10)
    return {"ok":false,"message":"%s wants stronger trust before an alliance." % r["name"]}

func propose_supply_deal(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    if int(r["relationship"]) < 25: return {"ok":false,"message":"Trust is too low for a supply deal."}
    if index != 2: return {"ok":false,"message":"%s is not a strong logistics partner." % r["name"]}
    r["deal"] = "supply"; r["deal_days"] = 10; r["supplier_pressure"] = max(0, int(r["supplier_pressure"]) - 1); r["relationship"] = min(100, int(r["relationship"]) + 4)
    return {"ok":true,"message":"The Network signed a 10-day supply agreement. Input pressure is reduced."}

func propose_customer_partnership(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    if int(r["relationship"]) < 25: return {"ok":false,"message":"Trust is too low for a customer partnership."}
    if index != 1: return {"ok":false,"message":"The Specialist prefers quality partnerships rather than customer distribution."}
    r["deal"] = "customer"; r["deal_days"] = 10; r["relationship"] = min(100, int(r["relationship"]) + 4)
    return {"ok":true,"message":"The Specialist signed a 10-day customer partnership. Premium demand increases."}

func reject_acquisition(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]; r["offer_cooldown"] = 14; r["relationship"] = max(-100, int(r["relationship"]) - 5)
    return {"ok":true,"message":"Acquisition rejected. %s will remember the decision." % r["name"]}

func negotiate_acquisition(index: int, player_cash: int, reputation: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r = rivals[index]
    if reputation < 35: return {"ok":false,"message":"Your company needs 35 reputation to negotiate a major acquisition."}
    var cost := 45000 + int(r["presence"]) * 18000
    if int(r["relationship"]) < 10: cost += 15000
    if player_cash < cost: return {"ok":false,"message":"Negotiation requires $%s available capital." % _money(cost),"cost":cost}
    r["cash"] = max(0, int(r["cash"]) - cost / 2); r["presence"] = max(1, int(r["presence"]) - 1); r["offer_cooldown"] = 20; r["relationship"] = min(50, int(r["relationship"]) + 8)
    return {"ok":true,"cost":cost,"message":"You acquired a strategic foothold from %s. Their remaining operations are still active." % r["name"]}

func alliance_bonus(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"discount":0.0,"sales":0.0,"risk":0.0}
    var r = rivals[index]
    if int(r["relationship"]) < 35 and r["deal"] == "none": return {"discount":0.0,"sales":0.0,"risk":0.0}
    match index:
        0: return {"discount":0.08,"sales":0.02,"risk":0.0}
        1: return {"discount":0.02,"sales":0.10,"risk":0.0}
        _: return {"discount":0.12,"sales":0.03,"risk":0.15}

func deal_bonus(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"sales":0.0,"discount":0.0,"supplier":0,"risk":0.0}
    match str(rivals[index]["deal"]):
        "supply": return {"sales":0.0,"discount":0.10,"supplier":-1,"risk":0.02}
        "customer": return {"sales":0.12,"discount":0.0,"supplier":0,"risk":0.02}
        "alliance": return {"sales":0.05,"discount":0.05,"supplier":0,"risk":0.03}
        _: return {"sales":0.0,"discount":0.0,"supplier":0,"risk":0.0}

func _money(value: int) -> String: return "%,d" % value
