extends Node

# Compatibility guard for the old phone shell.
# The premium RENEW command deck is now responsive and owns mobile presentation,
# live active trading and the real-world economy. Keeping a second phone UI here
# caused duplicate controls and preserved the obsolete END DAY flow.

func _ready() -> void:
    call_deferred("_apply_mobile_compatibility")
    if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_changed):
        get_viewport().size_changed.connect(_on_viewport_changed)

func _on_viewport_changed() -> void:
    call_deferred("_apply_mobile_compatibility")

func _is_mobile_layout() -> bool:
    var size := get_viewport().get_visible_rect().size
    return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or size.x < 700.0

func _apply_mobile_compatibility() -> void:
    var hud := get_parent() as CanvasLayer
    if hud != null:
        hud.scale = Vector2.ONE

    var renew := get_tree().root.get_node_or_null("Renew")
    if renew == null:
        return

    # Legacy world canvases are desktop-era full-screen layers. On phones they
    # yield to the managed responsive screens opened from the premium command deck.
    var mobile := _is_mobile_layout()
    var legacy_world_paths := [
        "World/EmpireController", "World/Corporate", "World/WorldMissions",
        "World/RegionController", "World/BranchController", "World/RivalSupplyController"
    ]
    for path in legacy_world_paths:
        var node := renew.get_node_or_null(path)
        if node is CanvasItem:
            node.visible = not mobile

    # If an old MobileGameShell survived a scene reload/hot reload, remove it so
    # there is never a second set of trading/time controls above the command deck.
    if hud != null:
        var obsolete := hud.get_node_or_null("MobileGameShell")
        if obsolete != null:
            obsolete.queue_free()
