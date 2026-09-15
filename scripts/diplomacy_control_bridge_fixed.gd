extends "res://scripts/diplomacy_control_bridge.gd"

## Production correction: an accepted JV that could not fund must remain retryable.
## The base bridge synchronized only when the simulation day changed, so a failed
## daily transaction/unchanged day could leave an accepted venture permanently
## stuck even after the player restored liquidity.

func _process(_delta: float) -> void:
    var tree: Variant = Engine.get_main_loop()
    var scene = tree.get_current_scene() if tree != null else null
    if scene == null:
        return
    var diplomacy = _service("RenewDiplomacySystem")
    if diplomacy == null:
        return
    var day := int(scene.get("day"))
    var needs_funding_retry := false
    for treaty in diplomacy.list_treaties("active"):
        if str(treaty.get("type", "")) != "joint_venture":
            continue
        var treaty_id := str(treaty.get("id", ""))
        var state: Dictionary = applied.get(treaty_id, {})
        if not bool(state.get("funded", false)):
            needs_funding_retry = true
            break
    if day == last_day and not needs_funding_retry:
        return
    last_day = day
    _sync(diplomacy, day)
