extends Node

# RENEW safety net: periodically persist the canonical GameState so a mobile session
# ending unexpectedly does not erase a long run. Manual F5/F9 save/load remains available.
const SaveSystem := preload("res://scripts/save_system.gd")
const AUTOSAVE_INTERVAL := 30.0
var elapsed: Variant = 0.0

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
    # SaveSystem owns serialization. It captures the authoritative GameState itself;
    # autosave must not ask Main to manually collect individual systems.
    SaveSystem.save_game({})
