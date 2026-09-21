extends SceneTree

const WorldScene := preload("res://scenes/RestoraWorld3D.tscn")
const District := preload("res://scripts/restora_district_3d_presenter.gd")

var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := WorldScene.instantiate()
    root.add_child(world)
    await process_frame

    var sun := world.get_node_or_null("Sun") as DirectionalLight3D
    var rim := world.get_node_or_null("PropertyRim") as OmniLight3D
    var environment_node := world.get_node_or_null("Environment") as WorldEnvironment
    check("premium world lights resolve", sun != null and rim != null and environment_node != null and environment_node.environment != null)

    world._update_environment_for_snapshot({
        "economy_phase": "boom",
        "prosperity_tier": 3,
        "active_event_count": 0,
        "active_event_category": "",
    }, false)
    var boom_sun := sun.light_energy if sun != null else 0.0
    var boom_ambient := environment_node.environment.ambient_light_energy if environment_node != null and environment_node.environment != null else 0.0

    world._update_environment_for_snapshot({
        "economy_phase": "recession",
        "prosperity_tier": 0,
        "active_event_count": 0,
        "active_event_category": "",
    }, false)
    var recession_sun := sun.light_energy if sun != null else 0.0
    var recession_ambient := environment_node.environment.ambient_light_energy if environment_node != null and environment_node.environment != null else 0.0
    check("boom is visibly brighter than recession", boom_sun > recession_sun and boom_ambient > recession_ambient)

    world._update_environment_for_snapshot({
        "economy_phase": "recession",
        "prosperity_tier": 1,
        "active_event_count": 1,
        "active_event_category": "energy",
    }, false)
    check("energy crisis warms the world rim", rim != null and rim.light_color.r > rim.light_color.b)
    check("crisis raises rim emphasis", rim != null and rim.light_energy > 0.48)

    var district := District.new()
    root.add_child(district)
    await process_frame
    district.apply_snapshot({
        "stage": "operational",
        "business_open": true,
        "activity_tier": 3,
        "traffic_level": 3,
        "worker_visual_count": 5,
        "reputation": 70,
        "prosperity_tier": 3,
        "economy_phase": "boom",
        "active_event_count": 1,
        "active_event_category": "supply_chain",
        "rival_name": "Apex Materials",
        "rival_market_share": 0.31,
        "rival_presence": 2,
    }, false)
    await process_frame

    var rival_facade := district.get("_rival_facade") as MeshInstance3D
    var rival_label := district.get("_rival_label") as Label3D
    var event_label := district.get("_event_label") as Label3D
    check("rival has physical district presence", rival_facade != null and rival_facade.visible and rival_facade.scale.y > 0.45)
    check("rival identity is visible in world", rival_label != null and rival_label.visible and rival_label.text.contains("APEX MATERIALS"))
    check("live event is visible in world", event_label != null and event_label.text.contains("LIVE EVENT"))
    check("prosperity dressing responds to simulation", _visible_count(district.get("_prosperity_props")) == 3)

    district.queue_free()
    world.queue_free()
    await process_frame

    print("PREMIUM WORLD FEEDBACK: %s" % ("PASS" if failed == 0 else "FAIL"))
    quit(1 if failed > 0 else 0)

func _visible_count(value: Variant) -> int:
    if not value is Array:
        return 0
    var count := 0
    for node in value:
        if node is Node3D and (node as Node3D).visible:
            count += 1
    return count

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
