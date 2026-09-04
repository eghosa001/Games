extends CanvasLayer

# Existing mobile UI implementation retained; this guard prevents milestone seeding
# from touching optional expansion data before the authoritative systems are ready.

var parent: Node
var observed_milestones: Dictionary = {}
var celebrations: Dictionary = {}

func _regional_reached() -> bool:
    var region = parent.get_node_or_null("World/RegionController") if parent != null else null
    if region == null or region.regions == null:
        return false
    return int(region.regions.player_presence.count(1)) > 1

func _empire_reached() -> bool:
    if parent == null:
        return false
    var expansion = parent.expansion
    if expansion == null:
        return false
    var count: int = 0
    for p in expansion.properties:
        if bool(p.get("owned", false)):
            count += 1
    for site in expansion.resource_sites:
        if bool(site.get("owned", false)):
            count += 1
    return count >= 3
