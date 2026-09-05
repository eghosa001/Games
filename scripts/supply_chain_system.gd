extends Node

# Phase 9: one real V1 supply chain. Market resources move into a warehouse,
# iron is processed into metal, factories consume warehouse inputs, and finished
# goods remain in the warehouse until customers buy them.
const SYSTEM_VERSION := 8
const RESOURCE_IDS := ["timber", "iron", "energy", "food", "electronics"]
const WAREHOUSE_LIMIT := 500.0
const FURNITURE_INPUTS := {"timber": 1.0, "metal": 0.5, "energy": 2.0}
const METAL_RECIPE := {"iron": 2.0, "energy": 0.5, "metal": 1.0}
var economy = null
var warehouse: Dictionary = {"timber": 0.0, "iron": 0.0, "metal": 0.0, "energy": 0.0, "food": 0.0, "electronics": 0.0, "goods": 0.0, "consumer_goods": 0.0, "furniture": 0.0, "construction_materials": 0.0, "consumer_electronics": 0.0}
var total_freight_cost: int = 0
var last_operation: Dictionary = {}

func _ready() -> void:
    _ensure_warehouse()

func _ensure_warehouse() -> void:
    for key in ["timber", "iron", "metal", "energy", "food", "electronics", "goods", "consumer_goods", "furniture", "construction_materials", "consumer_electronics"]:
        warehouse[key] = max(0.0, float(warehouse.get(key, 0.0)))

func set_economy(value) -> void:
    economy = value

func stock(resource: String) -> float:
    return float(warehouse.get(resource, 0.0))

func warehouse_snapshot() -> Dictionary:
    return warehouse.duplicate(true)

func _technology():
    return get_node_or_null("/root/RenewTechnologySystem")

func _railway_effects() -> Dictionary:
    var state = get_node_or_null("/root/RenewGameState")
    if state == null: return {}
    var domain = state.get_domain("supply_chain")
    return domain if domain is Dictionary else {}

func _transport_capacity(level: int) -> float:
    var base: float = 40.0 + float(max(0, level - 1)) * 20.0
    var tech = _technology()
    if tech != null: return base * tech.transport_capacity_multiplier()
    return base

func _freight_cost(resource: String, amount: float, level: int) -> int:
    var distance_factor: float = 1.0
    if economy != null and economy.resources.has(resource): distance_factor = 1.0 + float(str(economy.resources[resource].get("region", "Unknown")).length() % 4) * 0.05
    var base_cost: float = amount * (2.0 + float(max(0, 3 - level))) * distance_factor
    var effects = _railway_effects()
    return int(round(base_cost * float(effects.get("transport_cost_multiplier", 1.0))))

func procure(resource: String, amount: float, cash: int, transport_level: int = 1) -> Dictionary:
    if economy == null or not economy.resources.has(resource) or amount <= 0: return {"ok": false, "reason": "invalid_resource"}
    var capacity: float = _transport_capacity(transport_level)
    var effects = _railway_effects()
    var delivery_multiplier: float = float(effects.get("resource_delivery_multiplier", 1.0))
    var delivered_amount: float = amount * delivery_multiplier
    if amount > capacity: return {"ok": false, "reason": "transport_capacity", "capacity": capacity, "requested": amount}
    var warehouse_room: float = WAREHOUSE_LIMIT - stock(resource)
    if delivered_amount > warehouse_room + 0.000001: return {"ok": false, "reason": "warehouse_capacity", "capacity": WAREHOUSE_LIMIT, "available": max(0.0, warehouse_room), "requested": delivered_amount}
    var available: float = float(economy.resources[resource].get("stock", 0.0))
    if available < amount: return {"ok": false, "reason": "market_stock", "available": available, "requested": amount}
    var unit_price: float = float(economy.current_price(resource))
    var material_cost: int = int(round(unit_price * amount))
    var freight: int = _freight_cost(resource, amount, transport_level)
    var total: int = material_cost + freight
    if cash < total: return {"ok": false, "reason": "cash", "cost": total}
    economy.resources[resource]["stock"] = max(0.0, available - amount)
    warehouse[resource] = stock(resource) + delivered_amount
    total_freight_cost += freight
    last_operation = {"type": "procure", "resource": resource, "amount": amount, "delivered_amount": delivered_amount, "material_cost": material_cost, "freight": freight, "cost": total, "region": economy.resources[resource].get("region", "Unknown")}
    return {"ok": true, "resource": resource, "amount": amount, "delivered_amount": delivered_amount, "cost": total, "material_cost": material_cost, "freight": freight}

func procure_bundle(orders: Array, cash: int, transport_level: int = 1) -> Dictionary:
    var total_amount: float = 0.0
    for order in orders: total_amount += float(order.get("amount", 0.0))
    var capacity: float = _transport_capacity(transport_level)
    if total_amount > capacity: return {"ok": false, "reason": "transport_capacity", "capacity": capacity, "requested": total_amount}
    var total_cost: int = 0
    for order in orders:
        var resource: String = str(order.get("resource", "")); var amount: float = float(order.get("amount", 0.0))
        if economy == null or not economy.resources.has(resource): return {"ok": false, "reason": "invalid_resource", "resource": resource}
        if amount <= 0.0: return {"ok": false, "reason": "invalid_amount", "resource": resource}
        var effects = _railway_effects(); var delivery_multiplier: float = float(effects.get("resource_delivery_multiplier", 1.0)); var delivered_amount: float = amount * delivery_multiplier
        if delivered_amount > WAREHOUSE_LIMIT - stock(resource) + 0.000001: return {"ok": false, "reason": "warehouse_capacity", "resource": resource, "capacity": WAREHOUSE_LIMIT, "available": max(0.0, WAREHOUSE_LIMIT - stock(resource)), "requested": delivered_amount}
        if float(economy.resources[resource].get("stock", 0.0)) < amount: return {"ok": false, "reason": "market_stock", "resource": resource}
        total_cost += int(round(economy.current_price(resource) * amount)) + _freight_cost(resource, amount, transport_level)
    if cash < total_cost: return {"ok": false, "reason": "cash", "cost": total_cost}
    var warehouse_before := warehouse.duplicate(true); var resources_before := economy.resources.duplicate(true); var freight_before := total_freight_cost; var operation_before := last_operation.duplicate(true); var delivered: Array = []; var remaining_cash: int = cash
    for order in orders:
        var result: Dictionary = procure(str(order["resource"]), float(order["amount"]), remaining_cash, transport_level)
        if not bool(result.get("ok", false)):
            warehouse = warehouse_before; economy.resources = resources_before; total_freight_cost = freight_before; last_operation = operation_before
            return {"ok": false, "reason": "delivery_failed", "details": result}
        remaining_cash -= int(result["cost"]); delivered.append(result)
    return {"ok": true, "cost": total_cost, "delivered": delivered, "warehouse": warehouse_snapshot()}

func process_iron_to_metal(cycles: int = 1) -> Dictionary:
    cycles = max(0, cycles); var possible: int = cycles
    possible = min(possible, int(floor(stock("iron") / METAL_RECIPE["iron"]))); possible = min(possible, int(floor(stock("energy") / METAL_RECIPE["energy"])))
    if possible <= 0: return {"ok": false, "reason": "insufficient_iron_or_energy", "cycles": 0}
    var output: float = METAL_RECIPE["metal"] * possible
    if output > WAREHOUSE_LIMIT - stock("metal") + 0.000001: return {"ok": false, "reason": "warehouse_capacity", "resource": "metal", "capacity": WAREHOUSE_LIMIT, "available": max(0.0, WAREHOUSE_LIMIT - stock("metal")), "requested": output}
    warehouse["iron"] -= METAL_RECIPE["iron"] * possible; warehouse["energy"] -= METAL_RECIPE["energy"] * possible; warehouse["metal"] += output
    _sync_production_mirror(["iron", "energy", "metal"])
    last_operation = {"type": "metal_processing", "cycles": possible, "iron_consumed": METAL_RECIPE["iron"] * possible, "energy_consumed": METAL_RECIPE["energy"] * possible, "metal_output": output}
    return {"ok": true, "cycles": possible, "output": output, "iron_consumed": METAL_RECIPE["iron"] * possible, "energy_consumed": METAL_RECIPE["energy"] * possible}

func can_make_inputs(inputs: Dictionary, cycles: int = 1) -> Dictionary:
    var possible: int = max(0, cycles)
    for resource in inputs: possible = min(possible, int(floor(stock(String(resource)) / max(0.0001, float(inputs[resource])))))
    return {"ok": possible > 0, "cycles": possible, "inputs": inputs.duplicate(true)}

func consume_inputs(inputs: Dictionary, cycles: int) -> Dictionary:
    var check: Dictionary = can_make_inputs(inputs, cycles)
    if not check["ok"]: return check
    var run_cycles: int = int(check["cycles"]); var consumed: Dictionary = {}
    for resource in inputs:
        var amount: float = float(inputs[resource]) * run_cycles; warehouse[String(resource)] -= amount; consumed[String(resource)] = amount
    _sync_production_mirror(inputs.keys())
    last_operation = {"type": "industry_inputs", "cycles": run_cycles, "consumed": consumed.duplicate(true)}
    return {"ok": true, "cycles": run_cycles, "consumed": consumed}

func _production_node():
    var root = get_tree().root; var production = root.get_node_or_null("RenewProductionSystem")
    if production != null: return production
    var scene = get_tree().current_scene
    return scene.get_node_or_null("Systems/ProductionSystem") if scene else null

func _active_product() -> String:
    var state = get_node_or_null("/root/RenewGameState")
    if state != null:
        var industry_id := str(state.get_value("businesses", "industry_id", ""))
        if not industry_id.is_empty():
            var production = _production_node()
            if production != null:
                var snapshot = production.capture_state()
                var last_run = snapshot.get("last_run", {})
                var last_product := str(last_run.get("product", ""))
                if last_product == industry_id or not last_product.is_empty(): return last_product
            if industry_id in ["furniture", "construction_materials", "consumer_electronics"]: return industry_id
    return "consumer_goods"

func _sync_production_mirror(resources: Array) -> void:
    var production = _production_node()
    if production == null: return
    for resource in resources:
        var key := str(resource)
        production.inventory[key] = int(floor(stock(key)))
    var active_product := _active_product()
    if active_product in resources or resources.is_empty():
        production.finished_goods = int(floor(stock(active_product)))
        production.inventory["goods"] = production.finished_goods

func receive_product(product: String, amount: int) -> Dictionary:
    _ensure_warehouse()
    if product.is_empty() or amount <= 0: return {"ok": false, "reason": "invalid_product"}
    var available_room: float = WAREHOUSE_LIMIT - stock(product)
    if float(amount) > available_room + 0.000001:
        return {"ok": false, "reason": "warehouse_capacity", "product": product, "capacity": WAREHOUSE_LIMIT, "available": max(0.0, available_room), "requested": amount}
    warehouse[product] = stock(product) + amount
    _sync_production_mirror([product])
    last_operation = {"type": "receive_product", "product": product, "amount": amount}
    return {"ok": true, "product": product, "amount": amount}

func can_make_furniture(cycles: int = 1) -> Dictionary: return can_make_inputs(FURNITURE_INPUTS, cycles)
func consume_furniture_inputs(cycles: int) -> Dictionary: return consume_inputs(FURNITURE_INPUTS, cycles)
func receive_furniture(amount: int) -> Dictionary: return receive_product("furniture", amount)

func sell_product(product: String, amount: int, price: int) -> Dictionary:
    if product.is_empty() or amount <= 0 or price < 0: return {"ok": false, "reason": "invalid_sale", "sold": 0, "revenue": 0}
    _ensure_warehouse()
    var sold: int = min(amount, int(floor(stock(product))))
    if sold <= 0: return {"ok": false, "reason": "no_inventory", "product": product, "sold": 0, "revenue": 0}
    var revenue: int = sold * price
    warehouse[product] = stock(product) - sold
    _sync_production_mirror([product])
    last_operation = {"type": "customer_sale", "product": product, "amount": sold, "price": price, "revenue": revenue}
    return {"ok": true, "product": product, "sold": sold, "revenue": revenue}

func sell_furniture(amount: int, price: int) -> Dictionary:
    return sell_product("furniture", amount, price)

func capture_state() -> Dictionary:
    return {"system_version": SYSTEM_VERSION, "warehouse": warehouse_snapshot(), "total_freight_cost": total_freight_cost, "last_operation": last_operation.duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    warehouse = snapshot.get("warehouse", warehouse).duplicate(true); total_freight_cost = int(snapshot.get("total_freight_cost", 0)); last_operation = snapshot.get("last_operation", {}).duplicate(true); _ensure_warehouse(); _sync_production_mirror(warehouse.keys())