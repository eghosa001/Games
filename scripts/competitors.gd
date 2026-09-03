extends RefCounted
class_name RenewCompetitors

# Phase 14: three persistent NPC corporations. Each rival observes the market,
# evaluates its position, selects a strategy, executes it, and remembers the result.
# Legacy competitor APIs are retained because acquisition, diplomacy, supply and
# simulation systems already depend on this class.
const SYSTEM_VERSION := 4

var rivals := [
    {
        "id":"apex_materials", "name":"Apex Materials", "personality":"aggressive",
        "strategy":"low_price_aggressive", "cash":220000, "debt":70000,
        "assets":5, "businesses":3, "employees":60, "production":78,
        "inventory":140, "technology":2, "price":88, "market_share":0.31,
        "reputation":62, "relationship":-10, "stance":"Low-price attacker",
        "strength":"price", "districts":[0,1], "presence":2,
        "supplier_pressure":0, "suppliers":["National Steel","Bulk Energy"],
        "customers":["Mass Retail","Municipal Buyers"], "risk_tolerance":0.85,
        "strategic_priorities":["market_share","low_price","capacity"],
        "memory":[], "last_observation":{}, "last_evaluation":{},
        "last_strategy":"", "last_action":"", "last_result":{},
        "strategy_cooldown":0, "offer_cooldown":0, "deal":"none",
        "deal_days":0, "retaliation":0
    },
    {
        "id":"northstar_logistics", "name":"Northstar Logistics", "personality":"disciplined",
        "strategy":"logistics_advantage", "cash":185000, "debt":50000,
        "assets":6, "businesses":3, "employees":72, "production":66,
        "inventory":175, "technology":3, "price":108, "market_share":0.27,
        "reputation":70, "relationship":5, "stance":"Logistics specialist",
        "strength":"logistics", "districts":[1,2], "presence":2,
        "supplier_pressure":0, "suppliers":["River Port Authority","Regional Fuel Consortium"],
        "customers":["Regional Distributors","Industrial Buyers"], "risk_tolerance":0.45,
        "strategic_priorities":["logistics","inventory","reliability"],
        "memory":[], "last_observation":{}, "last_evaluation":{},
        "last_strategy":"", "last_action":"", "last_result":{},
        "strategy_cooldown":0, "offer_cooldown":0, "deal":"none",
        "deal_days":0, "retaliation":0
    },
    {
        "id":"greenbuild_industries", "name":"GreenBuild Industries", "personality":"premium",
        "strategy":"premium_high_reputation", "cash":260000, "debt":60000,
        "assets":6, "businesses":3, "employees":54, "production":48,
        "inventory":95, "technology":4, "price":145, "market_share":0.22,
        "reputation":91, "relationship":15, "stance":"Premium leader",
        "strength":"quality", "districts":[0,3], "presence":2,
        "supplier_pressure":0, "suppliers":["Certified Timber","Precision Components"],
        "customers":["Premium Retail","Hospitality Chains","Government"], "risk_tolerance":0.30,
        "strategic_priorities":["reputation","quality","technology"],
        "memory":[], "last_observation":{}, "last_evaluation":{},
        "last_strategy":"", "last_action":"", "last_result":{},
        "strategy_cooldown":0, "offer_cooldown":0, "deal":"none",
        "deal_days":0, "retaliation":0
    }
]

func _normalize() -> void:
    for r in rivals:
        if not r.has("id"):
            r["id"] = "corp_" + str(r.get("name", "rival")).to_lower().replace(" ", "_")
        var defaults := {
            "name":"Rival Corporation", "personality":"balanced", "strategy":"balanced",
            "cash":100000, "debt":0, "assets":1, "businesses":1, "employees":10,
            "production":50, "inventory":50, "technology":1, "price":110,
            "market_share":0.10, "reputation":50, "relationship":0,
            "stance":"Balanced", "strength":"general", "districts":[0], "presence":1,
            "supplier_pressure":0, "suppliers":[], "customers":[], "risk_tolerance":0.5,
            "strategic_priorities":[], "memory":[], "last_observation":{},
            "last_evaluation":{}, "last_strategy":"", "last_action":"", "last_result":{},
            "strategy_cooldown":0, "offer_cooldown":0, "deal":"none",
            "deal_days":0, "retaliation":0
        }
        for key in defaults:
            if not r.has(key): r[key] = defaults[key]
        if not r.has("production"): r["production"] = 50
        if not r.has("inventory"): r["inventory"] = 50
        if not r.has("market_share"): r["market_share"] = 0.10
        if not r.has("reputation"): r["reputation"] = 50

func daily_update(day: int) -> Array[String]:
    _normalize()
    var news: Array[String] = []
    for rival in rivals:
        var strategy := str(rival.get("strategy", "balanced"))
        # Baseline daily corporate activity. This is intentionally distinct for
        # each Phase 14 corporation so the market evolves even without player input.
        match strategy:
            "low_price_aggressive":
                rival["cash"] += 2200
                rival["production"] = min(100, int(rival["production"]) + 1)
                if day % 3 == 0:
                    rival["price"] = max(78, int(rival["price"]) - 3)
                    rival["market_share"] = min(0.60, float(rival["market_share"]) + 0.008)
                    news.append("Apex Materials cuts prices to $%d to chase market share." % int(rival["price"]))
            "logistics_advantage":
                rival["inventory"] = min(260, int(rival["inventory"]) + 8)
                rival["cash"] += 1800
                if day % 4 == 0:
                    rival["supplier_pressure"] = max(0, int(rival["supplier_pressure"]) - 1)
                    rival["market_share"] = min(0.55, float(rival["market_share"]) + 0.005)
                    news.append("Northstar Logistics improves delivery reliability and inventory flow.")
            "premium_high_reputation":
                rival["cash"] += 2400
                rival["reputation"] = min(100, int(rival["reputation"]) + 1)
                if day % 5 == 0:
                    rival["technology"] = int(rival["technology"]) + 1
                    news.append("GreenBuild Industries invests in premium technology and quality.")
            _:
                rival["cash"] += 1200

        if int(rival["retaliation"]) > 0:
            rival["retaliation"] = int(rival["retaliation"]) - 1
            if int(rival["retaliation"]) == 0:
                news.append("%s has cooled its retaliation campaign." % rival["name"])
        if int(rival["offer_cooldown"]) > 0:
            rival["offer_cooldown"] = int(rival["offer_cooldown"]) - 1
        if int(rival["deal_days"]) > 0:
            rival["deal_days"] = int(rival["deal_days"]) - 1
            if int(rival["deal_days"]) == 0:
                rival["deal"] = "none"
                news.append("%s strategic deal has expired." % rival["name"])
    return news

# Full corporate AI loop: Observe -> Evaluate -> Select -> Execute -> Record -> Remember.
func strategic_ai_update(day: int, player_state: Dictionary = {}) -> Array[String]:
    _normalize()
    var news: Array[String] = []
    for i in range(rivals.size()):
        var r: Dictionary = rivals[i]
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
        r["memory"].append({"day":day,"strategy":strategy,"action":action,"result":result})
        if r["memory"].size() > 30:
            r["memory"].pop_front()
        if not str(result.get("news", "")).is_empty():
            news.append(str(result["news"]))
    return news

func _observe(r: Dictionary, day: int, player: Dictionary) -> Dictionary:
    var player_cash := int(player.get("cash", 0))
    var player_rep := int(player.get("reputation", 0))
    var player_price := int(player.get("player_price", 110))
    var player_district := int(player.get("selected_district", 0))
    var target_pressure := 1.0 if player_district in r["districts"] else 0.0
    return {
        "day":day, "player_cash":player_cash, "player_reputation":player_rep,
        "player_price":player_price, "player_district":player_district,
        "player_threat":clamp(float(player_rep) / 50.0 + float(player.get("acquisition_count", 0)) * 0.12, 0.0, 2.0),
        "own_cash":int(r["cash"]), "own_debt":int(r["debt"]), "own_assets":int(r["assets"]),
        "own_businesses":int(r["businesses"]), "own_employees":int(r["employees"]),
        "own_technology":int(r["technology"]), "own_presence":int(r["presence"]),
        "own_production":int(r["production"]), "own_inventory":int(r["inventory"]),
        "own_market_share":float(r["market_share"]), "own_reputation":int(r["reputation"]),
        "district_pressure":target_pressure, "relationship":int(r["relationship"]),
        "supplier_pressure":int(r["supplier_pressure"])
    }

func _evaluate(r: Dictionary, o: Dictionary) -> Dictionary:
    var liquidity := float(o["own_cash"]) / max(1.0, float(o["own_debt"]) + 50000.0)
    var threat := float(o["player_threat"])
    var growth_need := clamp(0.40 - float(o["own_market_share"]), 0.0, 0.40) / 0.40
    var inventory_health := clamp(float(o["own_inventory"]) / 150.0, 0.0, 1.0)
    var quality_edge := 1.0 if str(r["strength"]) == "quality" else 0.35
    return {
        "liquidity":liquidity, "threat":threat, "growth_need":growth_need,
        "inventory_health":inventory_health, "quality_edge":quality_edge,
        "risk_budget":float(r["risk_tolerance"]), "market_share":float(r["market_share"]),
        "reputation":int(r["reputation"])
    }

func _select_strategy(r: Dictionary, e: Dictionary, day: int) -> String:
    if int(r["strategy_cooldown"]) > 0:
        r["strategy_cooldown"] = int(r["strategy_cooldown"]) - 1
        return "maintain"
    match str(r["strategy"]):
        "low_price_aggressive":
            if e["threat"] >= 0.65 or e["market_share"] < 0.31: return "pressure_player"
            if e["liquidity"] > 0.8 and day % 7 == 0: return "expand_capacity"
            return "optimize_operations"
        "logistics_advantage":
            if e["inventory_health"] < 0.65 or int(r["supplier_pressure"]) > 0: return "secure_supply"
            if e["threat"] >= 0.8: return "logistics_push"
            if day % 9 == 0: return "expand_region"
            return "optimize_operations"
        "premium_high_reputation":
            if e["quality_edge"] > 0.8 and int(r["technology"]) < 7: return "invest_technology"
            if e["threat"] >= 0.9 and int(r["relationship"]) >= 25: return "build_alliance"
            if day % 10 == 0: return "premium_branding"
            return "optimize_operations"
        _:
            return "optimize_operations"

func _execute_strategy(r: Dictionary, strategy: String, o: Dictionary, day: int) -> String:
    match strategy:
        "pressure_player":
            r["price"] = max(78, int(r["price"]) - 2)
            r["retaliation"] = max(int(r["retaliation"]), 3)
            r["market_share"] = min(0.60, float(r["market_share"]) + 0.004)
            r["strategy_cooldown"] = 2
            return "cut_prices"
        "secure_supply":
            r["supplier_pressure"] = max(0, int(r["supplier_pressure"]) - 1)
            if "Strategic Reserve" not in r["suppliers"]: r["suppliers"].append("Strategic Reserve")
            r["inventory"] = min(300, int(r["inventory"]) + 18)
            r["assets"] = int(r["assets"]) + 1
            r["cash"] = max(0, int(r["cash"]) - 4500)
            r["strategy_cooldown"] = 3
            return "secure_supplier"
        "logistics_push":
            r["inventory"] = min(300, int(r["inventory"]) + 12)
            r["market_share"] = min(0.55, float(r["market_share"]) + 0.006)
            r["cash"] = max(0, int(r["cash"]) - 2500)
            r["strategy_cooldown"] = 3
            return "improve_delivery_network"
        "invest_technology":
            if int(r["cash"]) >= 6000:
                r["cash"] = int(r["cash"]) - 6000
                r["technology"] = int(r["technology"]) + 1
                r["production"] = min(100, int(r["production"]) + 4)
                r["reputation"] = min(100, int(r["reputation"]) + 1)
                r["strategy_cooldown"] = 4
                return "upgrade_technology"
            return "defer_technology"
        "premium_branding":
            r["reputation"] = min(100, int(r["reputation"]) + 2)
            r["price"] = max(110, int(r["price"]) + 2)
            r["strategy_cooldown"] = 4
            return "strengthen_premium_brand"
        "expand_capacity":
            if int(r["cash"]) >= 12000:
                r["cash"] = int(r["cash"]) - 12000
                r["assets"] = int(r["assets"]) + 1
                r["businesses"] = int(r["businesses"]) + 1
                r["employees"] = int(r["employees"]) + 8
                r["production"] = min(100, int(r["production"]) + 8)
                r["strategy_cooldown"] = 5
                return "expand_capacity"
            return "defer_capacity"
        "expand_region":
            if int(r["cash"]) >= 12000:
                var target := (int(r["districts"].back()) + 1) % 4
                if target not in r["districts"]: r["districts"].append(target)
                r["presence"] = min(3, int(r["presence"]) + 1)
                r["businesses"] = int(r["businesses"]) + 1
                r["assets"] = int(r["assets"]) + 1
                r["employees"] = int(r["employees"]) + 8
                r["cash"] = int(r["cash"]) - 12000
                r["strategy_cooldown"] = 5
                return "open_regional_operation"
            return "defer_expansion"
        "build_alliance":
            r["relationship"] = min(100, int(r["relationship"]) + 4)
            r["deal"] = "alliance"
            r["deal_days"] = 8
            r["strategy_cooldown"] = 4
            return "form_strategic_alliance"
        "acquire_asset":
            if int(r["cash"]) >= 10000:
                r["cash"] = int(r["cash"]) - 10000
                r["assets"] = int(r["assets"]) + 1
                r["businesses"] = int(r["businesses"]) + 1
                r["employees"] = int(r["employees"]) + 5
                r["strategy_cooldown"] = 6
                return "acquire_business_asset"
            return "defer_acquisition"
        _:
            r["cash"] = int(r["cash"]) + 1500 + int(r["businesses"]) * 100
            r["employees"] = max(1, int(r["employees"]))
            r["strategy_cooldown"] = 1
            return "optimize_operations"

func _record_result(r: Dictionary, action: String, o: Dictionary, e: Dictionary) -> Dictionary:
    var delta_cash := int(r["cash"]) - int(o["own_cash"])
    var result := {
        "action":action, "cash_delta":delta_cash, "assets":int(r["assets"]),
        "businesses":int(r["businesses"]), "employees":int(r["employees"]),
        "technology":int(r["technology"]), "production":int(r["production"]),
        "inventory":int(r["inventory"]), "market_share":float(r["market_share"]),
        "reputation":int(r["reputation"]), "presence":int(r["presence"]),
        "success":true, "news":""
    }
    match action:
        "cut_prices": result["news"] = "%s launched another aggressive price move." % r["name"]
        "secure_supplier": result["news"] = "%s secured supply and increased inventory resilience." % r["name"]
        "improve_delivery_network": result["news"] = "%s strengthened its logistics network." % r["name"]
        "upgrade_technology": result["news"] = "%s invested in technology and production quality." % r["name"]
        "strengthen_premium_brand": result["news"] = "%s strengthened its premium brand and reputation." % r["name"]
        "expand_capacity": result["news"] = "%s expanded production capacity." % r["name"]
        "open_regional_operation": result["news"] = "%s opened a new regional operation." % r["name"]
        "form_strategic_alliance": result["news"] = "%s is building a strategic alliance network." % r["name"]
        "acquire_business_asset": result["news"] = "%s acquired another business asset." % r["name"]
    return result

func ai_status(index: int) -> Dictionary:
    _normalize()
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r: Dictionary = rivals[index]
    return {
        "ok":true, "id":r["id"], "name":r["name"], "personality":r["personality"],
        "strategy":r["strategy"], "cash":r["cash"], "debt":r["debt"], "assets":r["assets"],
        "businesses":r["businesses"], "employees":r["employees"], "production":r["production"],
        "inventory":r["inventory"], "technology":r["technology"], "price":r["price"],
        "market_share":r["market_share"], "reputation":r["reputation"], "districts":r["districts"],
        "suppliers":r["suppliers"], "customers":r["customers"], "risk_tolerance":r["risk_tolerance"],
        "strategic_priorities":r["strategic_priorities"], "last_strategy":r["last_strategy"],
        "last_action":r["last_action"], "memory_size":r["memory"].size()
    }

func retaliation_after_acquisition(index: int) -> Dictionary:
    _normalize()
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r: Dictionary = rivals[index]
    var pressure_gain := 1 if str(r["strategy"]) != "logistics_advantage" else 0
    r["retaliation"] = max(int(r["retaliation"]), 6)
    r["offer_cooldown"] = max(int(r["offer_cooldown"]), 6)
    r["relationship"] = max(-100, int(r["relationship"]) - 12)
    r["supplier_pressure"] = min(3, int(r["supplier_pressure"]) + pressure_gain)
    r["price"] = max(78, int(r["price"]) - (3 if str(r["strategy"]) == "low_price_aggressive" else 1))
    return {"ok":true,"message":"%s retaliated: competition intensified for the next several days." % r["name"]}

func strategic_update(day: int, selected_district: int, reputation: int) -> Array[String]:
    return strategic_ai_update(day, {"selected_district":selected_district,"reputation":reputation})

func competitive_status(index: int) -> Dictionary:
    _normalize()
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r: Dictionary = rivals[index]
    return {
        "ok":true, "name":r["name"], "stance":r["stance"], "strength":r["strength"],
        "relationship":int(r["relationship"]), "presence":int(r["presence"]),
        "supplier_pressure":int(r["supplier_pressure"]), "retaliation_days":int(r["retaliation"]),
        "message":"%s — %s. Strength: %s. Presence %d." % [r["name"],r["stance"],r["strength"],int(r["presence"])]
    }

func _district_name(index: int) -> String:
    var names := ["Old Market","Industrial Belt","River Port","North Growth Corridor"]
    return names[index] if index >= 0 and index < names.size() else "Unknown District"

func district_pressure(district_index: int) -> float:
    _normalize()
    var pressure := 0.0
    for rival in rivals:
        if district_index in rival["districts"]:
            pressure += 0.05 * float(rival["presence"])
            if int(rival["retaliation"]) > 0: pressure += 0.025
    return pressure

func supplier_pressure(district_index: int) -> int:
    _normalize()
    var pressure := 0
    for rival in rivals:
        if district_index in rival["districts"]: pressure += int(rival["supplier_pressure"])
    return pressure

func improve_relationship(index: int) -> String:
    if index < 0 or index >= rivals.size(): return "Unknown company."
    rivals[index]["relationship"] = min(100, int(rivals[index]["relationship"]) + 5)
    return "Relationship with %s improved to %d." % [rivals[index]["name"], rivals[index]["relationship"]]

func offer_alliance(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r: Dictionary = rivals[index]
    if int(r["relationship"]) >= 35:
        r["relationship"] = min(100, int(r["relationship"]) + 3)
        r["deal"] = "alliance"
        r["deal_days"] = 12
        return {"ok":true,"message":"%s accepted a 12-day strategic alliance." % r["name"]}
    r["relationship"] = min(100, int(r["relationship"]) + 10)
    return {"ok":false,"message":"%s wants stronger trust before an alliance." % r["name"]}

func propose_supply_deal(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r: Dictionary = rivals[index]
    if int(r["relationship"]) < 25: return {"ok":false,"message":"Trust is too low for a supply deal."}
    if str(r["strategy"]) != "logistics_advantage": return {"ok":false,"message":"%s is not a strong logistics partner." % r["name"]}
    r["deal"] = "supply"
    r["deal_days"] = 10
    r["supplier_pressure"] = max(0, int(r["supplier_pressure"]) - 1)
    r["relationship"] = min(100, int(r["relationship"]) + 4)
    return {"ok":true,"message":"%s signed a 10-day supply agreement. Input pressure is reduced." % r["name"]}

func propose_customer_partnership(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r: Dictionary = rivals[index]
    if int(r["relationship"]) < 25: return {"ok":false,"message":"Trust is too low for a customer partnership."}
    if str(r["strategy"]) != "premium_high_reputation": return {"ok":false,"message":"%s prefers its own premium customer network." % r["name"]}
    r["deal"] = "customer"
    r["deal_days"] = 10
    r["relationship"] = min(100, int(r["relationship"]) + 4)
    return {"ok":true,"message":"%s signed a 10-day premium customer partnership." % r["name"]}

func reject_acquisition(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r: Dictionary = rivals[index]
    r["offer_cooldown"] = 14
    r["relationship"] = max(-100, int(r["relationship"]) - 5)
    return {"ok":true,"message":"Acquisition rejected. %s will remember the decision." % r["name"]}

func negotiate_acquisition(index: int, player_cash: int, reputation: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"ok":false,"message":"Unknown company."}
    var r: Dictionary = rivals[index]
    if reputation < 35: return {"ok":false,"message":"Your company needs 35 reputation to negotiate a major acquisition."}
    var cost := 45000 + int(r["presence"]) * 18000
    if int(r["relationship"]) < 10: cost += 15000
    if player_cash < cost: return {"ok":false,"message":"Negotiation requires $%s available capital." % _money(cost),"cost":cost}
    r["cash"] = max(0, int(r["cash"]) - int(cost / 2))
    r["presence"] = max(1, int(r["presence"]) - 1)
    r["offer_cooldown"] = 20
    r["relationship"] = min(50, int(r["relationship"]) + 8)
    return {"ok":true,"cost":cost,"message":"You acquired a strategic foothold from %s. Their remaining operations are still active." % r["name"]}

func alliance_bonus(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"discount":0.0,"sales":0.0,"risk":0.0}
    var r: Dictionary = rivals[index]
    if int(r["relationship"]) < 35 and r["deal"] == "none": return {"discount":0.0,"sales":0.0,"risk":0.0}
    match str(r["strategy"]):
        "low_price_aggressive": return {"discount":0.06,"sales":0.03,"risk":0.05}
        "logistics_advantage": return {"discount":0.10,"sales":0.05,"risk":0.0}
        "premium_high_reputation": return {"discount":0.02,"sales":0.10,"risk":0.0}
        _: return {"discount":0.04,"sales":0.04,"risk":0.0}

func deal_bonus(index: int) -> Dictionary:
    if index < 0 or index >= rivals.size(): return {"sales":0.0,"discount":0.0,"supplier":0,"risk":0.0}
    match str(rivals[index]["deal"]):
        "supply": return {"sales":0.0,"discount":0.10,"supplier":-1,"risk":0.02}
        "customer": return {"sales":0.12,"discount":0.0,"supplier":0,"risk":0.02}
        "alliance": return {"sales":0.05,"discount":0.05,"supplier":0,"risk":0.03}
        _: return {"sales":0.0,"discount":0.0,"supplier":0,"risk":0.0}

func capture_state() -> Dictionary:
    _normalize()
    return {"system_version":SYSTEM_VERSION,"rivals":rivals.duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    var saved = snapshot.get("rivals", [])
    if saved is Array and not saved.is_empty():
        rivals = saved.duplicate(true)
        _normalize()

func _money(value: int) -> String:
    return "%,d" % value
