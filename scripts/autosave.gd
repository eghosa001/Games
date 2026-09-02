extends Node

# RENEW safety net: periodically persist the current company so a mobile session
# ending unexpectedly does not erase a long run. Manual F5/F9 save/load remains available.
const AUTOSAVE_INTERVAL := 30.0
var elapsed := 0.0

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed < AUTOSAVE_INTERVAL:
        return
    elapsed = 0.0
    _save_current_game()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_current_game()
        get_tree().quit()

func _save_current_game() -> void:
    var scene := get_tree().current_scene
    if scene != null and scene.has_method("save_game"):
        scene.save_game()
