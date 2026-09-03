extends Control

var parent
var system
var message: Variant = ""
var selected_type: Variant = 0
var last_day: Variant = -1

func _ready() -> void:
    system = get_node_or_null("/root/RenewInfrastructureSystem")
    parent = get_tree().current_scene
    z_index = 57
    queue_redraw()

func _process(_delta: float) -> void:
    if parent == null: parent = get_tree().current_scene
    if system == null: system = get_node_or_null("/root/RenewInfrastructureSystem")
    if parent != null and system != null and int(parent.day) != last_day:
        if last_day >= 0:
            var upkeep: Variant = system.maintenance_cost(int(parent.day))
            if upkeep > 0:
                parent.cash -= upkeep
                parent._log("INFRASTRUCTURE MAINTENANCE: -$%s." % String.num_int64(upkeep))
        last_day = int(parent.day)
    queue_redraw()

func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo or system == null or parent == null: return
    var regions = parent.get_node_or_null("RegionController")
    var region: Variant = 0
    if regions != null and regions.get("regions") != null: region = int(regions.regions.selected)
    match event.keycode:
        KEY_F11:
            selected_type = (selected_type + 1) % system.TYPES.size()
            message = "Selected %s." % system.TYPES[selected_type].replace("_"," ").capitalize()
        KEY_F12:
            var result = system.build(system.TYPES[selected_type], region, "founder", int(parent.cash), int(parent.day))
            message = result["message"]
            if bool(result.get("ok",false)): parent.cash -= int(result["cost"])
        KEY_F13:
            var list:Array = system.list_region(region)
            var target:String = ""
            for asset in list:
                if str(asset.get("status")) == system.ACTIVE:
                    target = str(asset["id"]); break
            if target == "": message = "No active infrastructure to upgrade in this region."
            else:
                var result = system.upgrade(target,"founder",int(parent.cash),int(parent.day))
                message = result["message"]
                if bool(result.get("ok",false)): parent.cash -= int(result["cost"])
        KEY_F14:
            var list:Array = system.list_region(region)
            var target:String = ""
            for asset in list:
                if str(asset.get("status")) == system.DISRUPTED:
                    target = str(asset["id"]); break
            if target == "": message = "No disrupted infrastructure to repair in this region."
            else:
                var result = system.repair(target,"founder",int(parent.cash),int(parent.day))
                message = result["message"]
                if bool(result.get("ok",false)): parent.cash -= int(result["cost"])

func _draw() -> void:
    if system == null or parent == null: return
    var regions = parent.get_node_or_null("RegionController")
    var region: Variant = 0
    var region_name: Variant = "Region 1"
    if regions != null and regions.get("regions") != null:
        region = int(regions.regions.selected)
        region_name = str(regions.regions.current().get("name","Region"))
    var list:Array = system.list_region(region)
    var active: Variant = 0
    var disrupted: Variant = 0
    var capacity: Variant = 0.0
    var maintenance: Variant = 0
    for asset in list:
        if str(asset.get("status")) == system.ACTIVE:
            active += 1; capacity += float(asset.get("capacity",0.0)); maintenance += int(asset.get("maintenance",0))
        elif str(asset.get("status")) == system.DISRUPTED: disrupted += 1
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
