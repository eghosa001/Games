extends Node
class_name RenewDemandModel
const CustomerSegmentSystem=preload("res://scripts/customer_segment_system.gd")
var customer_segments=CustomerSegmentSystem.new()
const PRODUCT_CONFIG={"consumer_goods":{"base_demand":55.0,"min_demand":0.0,"max_demand":100.0,"price_strength":0.90},"furniture":{"base_demand":42.0,"min_demand":0.0,"max_demand":100.0,"price_strength":1.15},"appliance":{"base_demand":34.0,"min_demand":0.0,"max_demand":80.0,"price_strength":1.35}}
func get_product_config(product:String="consumer_goods")->Dictionary:return PRODUCT_CONFIG.get(product,{}).duplicate(true)
func product_ids()->Array:return PRODUCT_CONFIG.keys()
func get_customer_segments()->Dictionary:return customer_segments.get_segments()
func calculate(product:String,player_price:float,competitor_price:float,reputation:int,quality:int,marketing_level:int,contract_bonus:int,employee_productivity:float,district_multiplier:float,district_pressure:float,alliance_sales:float,deal_sales:float)->Dictionary:
    var resolved_product:=product;if resolved_product=="consumer_goods":resolved_product="furniture"
    var effective_district:=clamp(district_multiplier*(1.0-district_pressure),0.60,1.40)
    var segment_result:Dictionary=customer_segments.calculate(resolved_product,player_price,competitor_price,quality,reputation,marketing_level,effective_district)
    if not bool(segment_result.get("ok",false)):return {"ok":false,"demand":0,"modifiers":{}}
    var employee_modifier:=clamp(employee_productivity,0.45,1.55);var relationship_modifier:=clamp(1.0+alliance_sales*0.45+deal_sales*0.50,0.50,1.90)
    var demand_float: float =float(segment_result.get("raw_demand",0.0))*employee_modifier*relationship_modifier
    var tech: Node = get_node_or_null("/root/RenewTechnologySystem")
    var market_multiplier: float =tech.market_demand_multiplier() if tech!=null else 1.0
    var event_multiplier:=1.0
    var state: Node = get_node_or_null("/root/RenewGameState")
    if state!=null:
        var event_modifiers=state.get_value("events","modifiers",{})
        if event_modifiers is Dictionary:event_multiplier=float(event_modifiers.get("demand_multiplier",1.0))
    demand_float*=market_multiplier*event_multiplier
    var config:Dictionary=get_product_config(resolved_product);var demand:=clamp(int(round(demand_float)),int(config.get("min_demand",0)),int(config.get("max_demand",100)))
    var segment_details:Dictionary=segment_result.get("segments",{}).duplicate(true)
    for segment in segment_details.keys():
        var detail:Dictionary=segment_details[segment];detail["final_demand"]=int(round(float(detail.get("demand",0))*employee_modifier*relationship_modifier*market_multiplier*event_multiplier));segment_details[segment]=detail
    var relative_price:=1.0 if player_price<=0.0 else float(competitor_price)/player_price;var price_strength:=float(config.get("price_strength",1.15));var price_modifier:=clamp(pow(max(0.01,relative_price),price_strength),0.20,1.80)
    return {"ok":true,"product":resolved_product,"requested_product":product,"demand":demand,"raw_demand":demand_float,"relative_price":relative_price,"segments":segment_details,"segment_count":int(segment_result.get("segment_count",0)),"modifiers":{"price":price_modifier,"employee_productivity":employee_modifier,"relationships":relationship_modifier,"district":effective_district,"market_analysis":market_multiplier,"dynamic_event":event_multiplier,"segments":segment_details}}
