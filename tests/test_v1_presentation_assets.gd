extends SceneTree

const ASSETS := [
    "res://Assets/Art/building_warehouse_progression.svg",
    "res://Assets/Art/building_factory_progression.svg",
    "res://Assets/Art/building_office_progression.svg",
    "res://Assets/Art/employee_portraits.svg",
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
            push_error("Missing V1 presentation asset: %s" % path)
    if failures == 0:
        print("V1_PRESENTATION_ASSETS: PASS (%d assets)" % ASSETS.size())
    else:
        print("V1_PRESENTATION_ASSETS: FAIL (%d missing)" % failures)
    quit(failures)
