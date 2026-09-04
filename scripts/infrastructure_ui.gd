extends Control

const DomainSystem = preload("res://scripts/domain_system.gd")

var parent
var system
var state_adapter = DomainSystem.new()
var message: Variant = ""
var selected_type: Variant = 0

func _ready() -> void:
    system = get_node_or_null("/root/RenewInfrastructureSystem")
    parent = get_tree().current_scene
    add_child(state_adapter)
    z_index = 57
    queue_redraw()

func _process(_delta: float) -> void:
    if parent == null: parent = get_tree().current_scene
    if system == null: system = get_node_or_null("/root/RenewInfrastructureSystem")
    queue_redraw()

func _region_controller():
    return parent.get_node_or_null("World/RegionController") if parent != null else null

func _region_index() -> int:
    var regions = _region_controller()
    if regions != null and regions.get("regions") != null:
        return int(regions.regions.selected)
    return 0

func _spend_result(result: Dictionary, reason: String) -> bool:
    if not bool(result.get("ok", false)): return false
    var spend = state_adapter.spend(int(result.get("cost", 0)), reason)
    if bool(spend.get("ok", false)): return true
    message = str(spend.get("message", "Payment failed."))
    return false

func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo or system == null or parent == null: return
    var region := _region_index()
    match event.keycode:
        KEY_F11:
            selected_type = (selected_type + 1) % system.TYPES.size()
            message = "Selected %s." % system.TYPES[selected_type].replace("_", " ").capitalize()
        KEY_F12:
            var result = system.build(system.TYPES[selected_type], region, "founder", int(parent.cash), int(parent.day))
            message = result["message"]
            if bool(result.get("ok", false)):
                var asset_id = str(result.get("id", ""))
                var spend = state_adapter.spend(int(result.get("cost", 0)), "infrastructure construction")
                if not bool(spend.get("ok", false)):
                    if asset_id != "": system.assets.erase(asset_id)
                    message = str(spend.get("message", "Construction payment failed."))
        KEY_F13:
            var list: Array = system.list_region(region)
            var target := ""
            for asset in list:
                if str(asset.get("status")) == system.ACTIVE:
                    target = str(asset["id"])
                    break
            if target == "":
                message = "No active infrastructure to upgrade in this region."
            else:
                var before = system.assets.get(target, {}).duplicate(true)
                var result = system.upgrade(target, "founder", int(parent.cash), int(parent.day))
                message = result["message"]
                if bool(result.get("ok", false)):
                    var spend = state_adapter.spend(int(result.get("cost", 0)), "infrastructure upgrade")
                    if not bool(spend.get("ok", false)):
                        system.assets[target] = before
                        message = str(spend.get("message", "Upgrade payment failed."))
        KEY_F14:
            var list: Array = system.list_region(region)
            var target := ""
            for asset in list:
                if str(asset.get("status")) == system.DISRUPTED:
                    target = str(asset["id"])
                    break
            if target == "":
                message = "No disrupted infrastructure to repair in this region."
            else:
                var before = system.assets.get(target, {}).duplicate(true)
                var result = system.repair(target, "founder", int(parent.cash), int(parent.day))
                message = result["message"]
                if bool(result.get("ok", false)):
                    var spend = state_adapter.spend(int(result.get("cost", 0)), "infrastructure repair")
                    if not bool(spend.get("ok", false)):
                        system.assets[target] = before
                        message = str(spend.get("message", "Repair payment failed."))

func _draw() -> void:
    if system == null or parent == null: return
    var region := _region_index()
    var region_name := "Region 1"
    var regions = _region_controller()
    if regions != null and regions.get("regions") != null:
        region_name = str(regions.regions.current().get("name", "Region"))
    var list: Array = system.list_region(region)
    var active := 0
    var disrupted := 0
    var capacity := 0.0
    var maintenance := 0
    for asset in list:
        if str(asset.get("status")) == system.ACTIVE:
            active += 1
            capacity += float(asset.get("capacity", 0.0))
            maintenance += int(asset.get("maintenance", 0))
        elif str(asset.get("status")) == system.DISRUPTED:
            disrupted += 1
    draw_rect(Rect2(845,420,410,255),Color("18242e"),true)
    draw_string(ThemeDB.fallback_font,Vector2(865,448),"PHYSICAL INFRASTRUCTURE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("7891a5"))
    draw_string(ThemeDB.fallback_font,Vector2(865,474),"Region: %s | Assets: %d"%[region_name,active],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(865,498),"Type: %s"%system.TYPES[selected_type].replace("_"," ").capitalize(),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(865,520),"Capacity %.0f | Maintenance/day $%s"%[capacity,String.num_int64(maintenance)],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font,Vector2(865,542),"Disrupted: %d | F11 type | F12 build"%disrupted,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("ffad8f"))
    draw_string(ThemeDB.fallback_font,Vector2(865,562),"F13 upgrade | F14 repair",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,592),message,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,620),"Owned assets have capacity, utilization, upkeep and disruption risk.",HORIZONTAL_ALIGNMENT_LEFT,370,10,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,638),"Construction completes over time; upgrades increase capacity and upkeep.",HORIZONTAL_ALIGNMENT_LEFT,370,10,Color("c6d0d8"))