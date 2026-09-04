extends Node

func _ready():
    var files = [
        "user://renew_corporate.json",
        "user://renew_market.json",
        "user://renew_goals.json",
        "user://renew_milestones.json",
        "user://renew_save.backup.json"
    ]
    for path in files:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
            print("Removed legacy file: ", path)
    print("Legacy cleanup complete. Restart the game.")
    queue_free()
