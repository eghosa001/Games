extends "res://scripts/game_state.gd"

## Compatibility correction for schema-v8 saves.
## The base capture path stores DiplomacySystem under diplomacy.system, while a
## legacy restore branch still reads diplomacy.diplomacy. Restore the canonical
## captured snapshot after the base domain restores have completed.

func _restore_domain_systems() -> void:
    super._restore_domain_systems()
    var diplomacy := _find_system("RenewDiplomacySystem", "Systems/DiplomacySystem")
    if diplomacy == null or not diplomacy.has_method("restore_state"):
        return
    var diplomacy_domain: Dictionary = domains.get("diplomacy", {})
    var snapshot = diplomacy_domain.get("system", null)
    if snapshot is Dictionary and not snapshot.is_empty():
        diplomacy.restore_state((snapshot as Dictionary).duplicate(true))
