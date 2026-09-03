extends RefCounted
class_name RenewCustomerSegmentSystem

## V1 customer model: segments instead of thousands of individual customer records.
## Sales demand is calculated per segment, then aggregated for the product.
const SYSTEM_VERSION := 1

const SEGMENT_CONFIG := {
    "budget": {
        "price_sensitivity": 1.35,
        "quality_requirement": 45,
        "demand": 28.0,
        "preferred_products": {"consumer_goods": 1.00, "furniture": 0.75, "appliance": 0.45}
    },
    "standard": {
        "price_sensitivity": 1.00,
        "quality_requirement": 60,
        "demand": 32.0,
        "preferred_products": {"consumer_goods": 1.00, "furniture": 1.00, "appliance": 0.80}
    },
    "premium": {
        "price_sensitivity": 0.70,
        "quality_requirement": 80,
        "demand": 18.0,
        "preferred_products": {"consumer_goods": 0.65, "furniture": 1.20, "appliance": 1.35}
    },
    "industrial": {
        "price_sensitivity": 0.85,
        "quality_requirement": 70,
        "demand": 14.0,
        "preferred_products": {"consumer_goods": 0.55, "furniture": 1.15, "appliance": 1.25}
    },
    "government": {
        "price_sensitivity": 0.90,
        "quality_requirement": 65,
        "demand": 10.0,
        "preferred_products": {"consumer_goods": 0.80, "furniture": 1.30, "appliance": 1.10}
    }
}

func segment_ids() -> Array:
    return SEGMENT_CONFIG.keys()

func get_segment_config(segment: String) -> Dictionary:
    return SEGMENT_CONFIG.get(segment, {}).duplicate(true)

func get_segments() -> Dictionary:
    return SEGMENT_CONFIG.duplicate(true)

func calculate_segment_demand(segment: String, product: String, player_price: float, competitor_price: float, quality: int, reputation: int = 0, marketing_level: int = 0, district_multiplier: float = 1.0) -> Dictionary:
    var config: Dictionary = get_segment_config(segment)
    if config.is_empty(): return {"ok": false, "segment": segment, "demand": 0}
    var preferred_products: Dictionary = config.get("preferred_products", {})
    var product_preference := float(preferred_products.get(product, 0.0))
    if product_preference <= 0.0:
        return {"ok": true, "segment": segment, "product": product, "demand": 0, "raw_demand": 0.0, "modifiers": {"preference": 0.0}}

    var reference_price := max(1.0, competitor_price)
    var relative_price := max(0.01, player_price) / reference_price
    var sensitivity := float(config.get("price_sensitivity", 1.0))
    var price_modifier := clamp(pow(1.0 / relative_price, sensitivity), 0.20, 1.80)

    var quality_requirement := float(config.get("quality_requirement", 60))
    var quality_modifier := 1.0
    if float(quality) < quality_requirement:
        quality_modifier = clamp(float(quality) / max(1.0, quality_requirement), 0.25, 1.0)
    else:
        quality_modifier = clamp(1.0 + (float(quality) - quality_requirement) * 0.008, 1.0, 1.25)

    var reputation_modifier := clamp(1.0 + float(reputation) * 0.006, 0.80, 1.35)
    var marketing_modifier := clamp(1.0 + float(marketing_level) * 0.04, 1.0, 1.25)
    var district_modifier := clamp(district_multiplier, 0.60, 1.40)
    var base_demand := float(config.get("demand", 0.0))
    var raw_demand := base_demand * product_preference * price_modifier * quality_modifier * reputation_modifier * marketing_modifier * district_modifier
    var demand := max(0, int(round(raw_demand)))

    return {
        "ok": true,
        "segment": segment,
        "product": product,
        "demand": demand,
        "raw_demand": raw_demand,
        "relative_price": relative_price,
        "modifiers": {
            "price": price_modifier,
            "quality": quality_modifier,
            "reputation": reputation_modifier,
            "marketing": marketing_modifier,
            "district": district_modifier,
            "preference": product_preference
        }
    }

func calculate(product: String, player_price: float, competitor_price: float, quality: int, reputation: int = 0, marketing_level: int = 0, district_multiplier: float = 1.0) -> Dictionary:
    var by_segment: Dictionary = {}
    var total := 0
    var raw_total := 0.0
    for segment in segment_ids():
        var result: Dictionary = calculate_segment_demand(segment, product, player_price, competitor_price, quality, reputation, marketing_level, district_multiplier)
        by_segment[segment] = result
        total += int(result.get("demand", 0))
        raw_total += float(result.get("raw_demand", 0.0))
    return {"ok": true, "product": product, "demand": total, "raw_demand": raw_total, "segments": by_segment, "segment_count": by_segment.size()}
