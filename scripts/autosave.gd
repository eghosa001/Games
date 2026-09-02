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
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _save_current_game()
        if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
            get_tree().quit()

func _save_current_game() -> void:
    var scene := get_tree().current_scene
    if scene == null or not scene.has_method("save_game"):
        return
    var previous_message := String(scene.message) if "message" in scene else ""
    scene.save_game()
    if "message" in scene:
        scene.message = previous_message
