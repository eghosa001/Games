extends Node
class_name RenewInfrastructureSystem

## Physical infrastructure layer: construction, capacity, maintenance, ownership,
## utilization, location, upgrades and disruptions for regional assets.

const ROAD := "road"
const RAILWAY := "railway"
const PORT := "port"
const AIRPORT := "airport"
const POWER_PLANT := "power_plant"
const WAREHOUSE := "warehouse"
const INDUSTRIAL_ZONE := "industrial_zone"
const TECHNOLOGY_PARK := "technology_park"
const TYPES := [ROAD, RAILWAY, PORT, AIRPORT, POWER_PLANT, WAREHOUSE, INDUSTRIAL_ZONE, TECHNOLOGY_PARK]
const ACTIVE := "active"
const CONSTRUCTING := "constructing"
const DISRUPTED := "disrupted"
const CLOSED := "closed"

var assets: Dictionary = {}
var next_id := 1
var events: Array = []
var last_day := 0

var base_specs := {
    ROAD: {"name":"Road Network","cost":18000,"capacity":80.0,"maintenance":180,"build_days":2,"upgrade_cost":14000,"upgrade_capacity":45.0},
    RAILWAY: {"name":"Railway","cost":65000,"capacity":240.0,"maintenance":650,"build_days":5,"upgrade_cost":48000,"upgrade_capacity":120.0},
    PORT: {"name":"Port","cost":110000,"capacity":420.0,"maintenance":1100,"build_days":8,"upgrade_cost":80000,"upgrade_capacity":210.0},
    AIRPORT: {"name":"Airport","cost":145000,"capacity":360.0,"maintenance":1350,"build_days":9,"upgrade_cost":105000,"upgrade_capacity":180.0},
    POWER_PLANT: {"name":"Power Plant","cost":90000,"capacity":520.0,"maintenance":1200,"build_days":7,"upgrade_cost":70000,"upgrade_capacity":260.0},
    WAREHOUSE: {"name":"Warehouse","cost":30000,"capacity":160.0,"maintenance":320,"build_days":3,"upgrade_cost":22000,"upgrade_capacity":80.0},
    INDUSTRIAL_ZONE: {"name":"Industrial Zone","cost":85000,"capacity":300.0,"maintenance":900,"build_days":6,"upgrade_cost":62000,"upgrade_capacity":150.0},
    TECHNOLOGY_PARK: {"name":"Technology Park","cost":125000,"capacity":220.0,"maintenance":1050,"build_days":8,"upgrade_cost":95000,"upgrade_capacity":110.0}
}

func _process(_delta: float) -> void:
    var tree := Engine.get_main_loop()
    if tree == null: return
    var scene = tree.get_current_scene()
    if scene == null or typeof(scene.get("day")) != TYPE_INT: return
    var day := int(scene.get("day"))
    if day != last_day: process_day(day)

func build(type: String, region: int, owner_id: String, cash: int, day: int, construction_days: int = -1) -> Dictionary:
    if not base_specs.has(type): return {"ok":false,"message":"Unknown infrastructure type."}
    if region < 0: return {"ok":false,"message":"Invalid region."}
    var spec: Dictionary = base_specs[type]
    var cost := int(spec["cost"])
    if cash < cost: return {"ok":false,"message":"%s construction requires $%s." % [spec["name"],_money(cost)]}
    var id := "infra_%d" % next_id
    next_id += 1
    var duration := int(spec["build_days"]) if construction_days < 0 else max(1, construction_days)
    assets[id] = {"id":id,"type":type,"name":spec["name"],"region":region,"owner_id":owner_id,"status":CONSTRUCTING,"level":1,"capacity":float(spec["capacity"]),"utilization":0.0,"maintenance":cost_to_maintenance(cost),"construction_cost":cost,"upgrade_count":0,"built_day":day,"completion_day":day+duration,"disruption_until":0,"disruption_reason":"","location":region,"created_day":day}
    _register_ownership(id, owner_id)
    _event(day, "%s started construction in region %d." % [spec["name"],region])
    return {"ok":true,"id":id,"cost":cost,"message":"%s construction started." % spec["name"]}

func upgrade(asset_id: String, owner_id: String, cash: int, day: int) -> Dictionary:
    if not assets.has(asset_id): return {"ok":false,"message":"Infrastructure asset not found."}
    var asset: Dictionary = assets[asset_id]
    if str(asset.get("owner_id")) != owner_id: return {"ok":false,"message":"Only the infrastructure owner can upgrade it."}
    if str(asset.get("status")) != ACTIVE: return {"ok":false,"message":"Infrastructure must be active before upgrading."}
    var type := str(asset.get("type")); var spec: Dictionary = base_specs[type]
    var level := int(asset.get("level",1)); var cost := int(spec["upgrade_cost"]) * level
    if cash < cost: return {"ok":false,"message":"Upgrade requires $%s." % _money(cost)}
    asset["level"] = level + 1
    asset["capacity"] = float(asset.get("capacity",spec["capacity"])) + float(spec["upgrade_capacity"])
    asset["maintenance"] = int(round(float(asset.get("maintenance",cost_to_maintenance(int(spec["cost"])))) * 1.18))
    asset["upgrade_count"] = int(asset.get("upgrade_count",0)) + 1
    asset["last_upgrade_day"] = day
    assets[asset_id] = asset
    _event(day, "%s upgraded to level %d." % [asset["name"],asset["level"]])
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d." % [asset["name"],asset["level"]]}

func disrupt(asset_id: String, duration: int, reason: String, day: int) -> Dictionary:
    if not assets.has(asset_id): return {"ok":false,"message":"Infrastructure asset not found."}
    var asset: Dictionary = assets[asset_id]
    asset["status"] = DISRUPTED; asset["disruption_until"] = max(day + 1, day + duration); asset["disruption_reason"] = reason
    assets[asset_id] = asset
    _event(day, "%s disrupted: %s." % [asset["name"],reason])
    return {"ok":true,"message":"Infrastructure disrupted."}

func repair(asset_id: String, owner_id: String, cash: int, day: int) -> Dictionary:
    if not assets.has(asset_id): return {"ok":false,"message":"Infrastructure asset not found."}
    var asset: Dictionary = assets[asset_id]
    if str(asset.get("owner_id")) != owner_id: return {"ok":false,"message":"Only the owner can repair infrastructure."}
    if str(asset.get("status")) != DISRUPTED: return {"ok":false,"message":"Asset is not disrupted."}
    var cost := max(500, int(round(float(asset.get("maintenance",500)) * 2.5)))
    if cash < cost: return {"ok":false,"message":"Repair requires $%s." % _money(cost)}
    asset["status"] = ACTIVE; asset["disruption_until"] = 0; asset["disruption_reason"] = ""; asset["last_repair_day"] = day
    assets[asset_id] = asset
    return {"ok":true,"cost":cost,"message":"%s repaired and operational." % asset["name"]}

func process_day(day: int) -> Dictionary:
    var maintenance_due := 0; var completed := 0; var recovered := 0; var disrupted := 0
    for id in assets.keys():
        var asset: Dictionary = assets[id]
        if str(asset.get("status")) == CONSTRUCTING and day >= int(asset.get("completion_day",day+1)):
            asset["status"] = ACTIVE; completed += 1
            _event(day, "%s construction completed in region %d." % [asset["name"],int(asset["region"])])
        elif str(asset.get("status")) == DISRUPTED and day >= int(asset.get("disruption_until",day+1)):
            asset["status"] = ACTIVE; asset["disruption_reason"] = ""; recovered += 1
            _event(day, "%s disruption cleared." % asset["name"])
        if str(asset.get("status")) == ACTIVE:
            var region_factor := 1.0 + float(int(asset.get("region",0)) % 3) * 0.04
            var utilization := clamp((0.45 + float(asset.get("level",1)) * 0.05) * region_factor,0.10,0.98)
            asset["utilization"] = utilization
            if day > int(asset.get("created_day",day)) and day % 23 == (int(str(id).replace("infra_","")) % 23):
                asset["status"] = DISRUPTED; asset["disruption_until"] = day + 2; asset["disruption_reason"] = "regional infrastructure incident"; disrupted += 1
                _event(day, "%s suffered a regional infrastructure incident." % asset["name"])
            else:
                maintenance_due += int(round(float(asset.get("maintenance",0)) * (0.75 + utilization * 0.50)))
        assets[id] = asset
    last_day = day
    return {"maintenance":maintenance_due,"completed":completed,"recovered":recovered,"disrupted":disrupted}

func maintenance_cost(_day: int = -1) -> int:
    var total := 0
    for asset in assets.values():
        if str(asset.get("status")) == ACTIVE:
            total += int(round(float(asset.get("maintenance",0)) * (0.75 + float(asset.get("utilization",0.0)) * 0.50)))
    return total

func capacity(region: int, type: String = "") -> float:
    var total := 0.0
    for asset in assets.values():
        if int(asset.get("region",-1)) != region or str(asset.get("status")) != ACTIVE: continue
        if type != "" and str(asset.get("type")) != type: continue
        total += float(asset.get("capacity",0.0)) * float(asset.get("utilization",0.0))
    return total

func total_capacity(region: int, type: String = "") -> float:
    var total := 0.0
    for asset in assets.values():
        if int(asset.get("region",-1)) != region or str(asset.get("status")) != ACTIVE: continue
        if type != "" and str(asset.get("type")) != type: continue
        total += float(asset.get("capacity",0.0))
    return total

func utilization(asset_id: String) -> float: return float(assets.get(asset_id,{}).get("utilization",0.0))

func regional_modifier(region: int) -> Dictionary:
    var result := {"logistics":1.0,"production":1.0,"energy":1.0,"storage":1.0,"technology":1.0,"capacity":total_capacity(region)}
    for asset in assets.values():
        if int(asset.get("region",-1)) != region or str(asset.get("status")) != ACTIVE: continue
        var u := float(asset.get("utilization",0.0)); var level := float(asset.get("level",1))
        match str(asset.get("type")):
            ROAD: result["logistics"] *= max(0.72,1.0 - 0.035*level*u)
            RAILWAY: result["logistics"] *= max(0.58,1.0 - 0.055*level*u)
            PORT: result["logistics"] *= max(0.62,1.0 - 0.045*level*u)
            AIRPORT: result["logistics"] *= max(0.78,1.0 - 0.025*level*u)
            POWER_PLANT: result["energy"] += 0.08*level*u
            WAREHOUSE: result["storage"] += 0.10*level*u
            INDUSTRIAL_ZONE: result["production"] += 0.07*level*u
            TECHNOLOGY_PARK: result["technology"] += 0.10*level*u
    return result

func list_region(region: int) -> Array:
    var result:Array = []
    for asset in assets.values():
        if int(asset.get("region",-1)) == region: result.append(asset.duplicate(true))
    return result

func list_assets() -> Array:
    var result:Array = []
    for asset in assets.values(): result.append(asset.duplicate(true))
    return result

func _register_ownership(asset_id: String, owner_id: String) -> void:
    var ownership = _ownership()
    if ownership == null: return
    var entity_id := "infrastructure:%s" % asset_id
    if not ownership.has_entity(entity_id):
        ownership.register_entity(entity_id, ownership.ENTITY_ASSET, 1000, 1.0)
        ownership.issue_shares(entity_id, owner_id, 1000, ownership.VOTE_ORDINARY, "infrastructure ownership")

func _ownership():
    var root := get_tree().root
    var node = root.get_node_or_null("RenewOwnershipSystem")
    if node != null: return node
    var scene := get_tree().current_scene
    return scene.get_node_or_null("OwnershipSystem") if scene != null else null

func cost_to_maintenance(cost: int) -> int: return max(100,int(round(float(cost)*0.01)))
func _event(day: int, text: String) -> void:
    events.append({"day":day,"text":text})
    if events.size() > 100: events.pop_front()
func _money(value: int) -> String: return String.num_int64(value)
func capture_state() -> Dictionary: return {"assets":assets.duplicate(true),"next_id":next_id,"events":events.duplicate(true),"last_day":last_day}
func restore_state(state: Dictionary) -> void:
    assets = state.get("assets",{}).duplicate(true); next_id = int(state.get("next_id",1)); events = state.get("events",[]).duplicate(true); last_day = int(state.get("last_day",0))
