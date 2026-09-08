extends SceneTree

const ASSETS := [
    "res://Assets/Art/resource_timber.svg",
    "res://Assets/Art/resource_iron.svg",
    "res://Assets/Art/resource_energy.svg",
    "res://Assets/Art/resource_food.svg",
    "res://Assets/Art/resource_electronics.svg",
]

func _init() -> void:
    var failures := 0
    for path in ASSETS:
        if not FileAccess.file_exists(path):
            failures += 1
            push_error("Missing resource art asset: %s" % path)
    if failures == 0:
        print("RESOURCE_ART_ASSETS: PASS")
    else:
        print("RESOURCE_ART_ASSETS: FAIL (%d missing)" % failures)
    quit(failures)
