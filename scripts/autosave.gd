extends Node

# RENEW safety net: periodically persist the canonical GameState so a mobile session
# ending unexpectedly does not erase a long run. Manual F5/F9 save/load remains available.
const SaveSystem := preload("res://scripts/save_system.gd")
const AUTOSAVE_INTERVAL := 30.0

var _autosave_timer: Timer

func _ready() -> void:
    _autosave_timer = Timer.new()
    _autosave_timer.name = "AutosaveTimer"
    _autosave_timer.wait_time = AUTOSAVE_INTERVAL
    _autosave_timer.one_shot = false
    _autosave_timer.timeout.connect(_on_autosave_timeout)
    add_child(_autosave_timer)
    _autosave_timer.start()

func _exit_tree() -> void:
    if _autosave_timer != null:
        if _autosave_timer.timeout.is_connected(_on_autosave_timeout):
            _autosave_timer.timeout.disconnect(_on_autosave_timeout)
        _autosave_timer.stop()
        _autosave_timer.queue_free()
        _autosave_timer = null

func _on_autosave_timeout() -> void:
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
