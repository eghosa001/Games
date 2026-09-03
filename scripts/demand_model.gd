extends RefCounted
class_name RenewDemandModel

# Customer-demand tuning lives here instead of inside SimulationSystem.
# Designers can rebalance sales without changing the simulation loop.
const PRODUCT_CONFIG := {
    "consumer_goods": {
        "base_demand": 55.0,
        "min_demand": 0.0,
        "max_demand": 100.0,
        "modifiers": {
            "price": {"strength": 0.90, "min": 0.45, "max": 1.45},
            "reputation": {"per_point": 0.01, "min": 0.80, "max": 1.50},
            "quality": {"base": 0.75, "per_point": 0.005, "min": 0.75, "max": 1.25},
            "marketing": {"per_level": 0.08, "min": 1.00, "max": 1.40},
            "contracts": {"per_point": 0.01, "min": 1.00, "max": 1.30},
            "employee_productivity": {"min": 0.50, "max": 1.50},
            "district": {"min": 0.50, "max": 1.50},
            "relationships": {"alliance_weight": 0.40, "deal_weight": 0.45, "min": 0.50, "max": 1.80}
        }
    }
}

func get_product_config(product: String = "consumer_goods") -> Dictionary:
    return PRODUCT_CONFIG.get(product, {}).duplicate(true)

func calculate(product: String, player_price: float, competitor_price: float, reputation: int, quality: int, marketing_level: int, contract_bonus: int, employee_productivity: float, district_multiplier: float, district_pressure: float, alliance_sales: float, deal_sales: float) -> Dictionary:
    var config: Dictionary = get_product_config(product)
    if config.is_empty():
        return {"ok": false, "demand": 0, "modifiers": {}}

    var m: Dictionary = config["modifiers"]
    var relative_price := 1.0
    if player_price > 0.0:
        relative_price = competitor_price / player_price
    var price_cfg: Dictionary = m["price"]
    var price_modifier := clamp(1.0 + (relative_price - 1.0) * float(price_cfg["strength"]), float(price_cfg["min"]), float(price_cfg["max"]))

    var rep_cfg: Dictionary = m["reputation"]
    var reputation_modifier := clamp(1.0 + float(reputation) * float(rep_cfg["per_point"]), float(rep_cfg["min"]), float(rep_cfg["max"]))

    var quality_cfg: Dictionary = m["quality"]
    var quality_modifier := clamp(float(quality_cfg["base"]) + float(quality) * float(quality_cfg["per_point"]), float(quality_cfg["min"]), float(quality_cfg["max"]))

    var marketing_cfg: Dictionary = m["marketing"]
    var marketing_modifier := clamp(1.0 + float(marketing_level) * float(marketing_cfg["per_level"]), float(marketing_cfg["min"]), float(marketing_cfg["max"]))

    var contract_cfg: Dictionary = m["contracts"]
    var contract_modifier := clamp(1.0 + float(contract_bonus) * float(contract_cfg["per_point"]), float(contract_cfg["min"]), float(contract_cfg["max"]))

    var employee_cfg: Dictionary = m["employee_productivity"]
    var employee_modifier := clamp(employee_productivity, float(employee_cfg["min"]), float(employee_cfg["max"]))

    var district_cfg: Dictionary = m["district"]
    var district_modifier := clamp(district_multiplier * (1.0 - district_pressure), float(district_cfg["min"]), float(district_cfg["max"]))

    var relationship_cfg: Dictionary = m["relationships"]
    var relationship_modifier := clamp(1.0 + alliance_sales * float(relationship_cfg["alliance_weight"]) + deal_sales * float(relationship_cfg["deal_weight"]), float(relationship_cfg["min"]), float(relationship_cfg["max"]))

    var demand_float := float(config["base_demand"]) * price_modifier * reputation_modifier * quality_modifier * marketing_modifier * contract_modifier * employee_modifier * district_modifier * relationship_modifier
    var demand := clamp(int(round(demand_float)), int(config["min_demand"]), int(config["max_demand"]))

    return {
        "ok": true,
        "product": product,
        "demand": demand,
        "raw_demand": demand_float,
        "relative_price": relative_price,
        "modifiers": {
            "price": price_modifier,
            "reputation": reputation_modifier,
            "quality": quality_modifier,
            "marketing": marketing_modifier,
            "contracts": contract_modifier,
            "employee_productivity": employee_modifier,
            "district": district_modifier,
            "relationships": relationship_modifier
        }
    }
