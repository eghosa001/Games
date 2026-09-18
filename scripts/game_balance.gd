extends Node

## Early-game balance guard.
## Opening cash and restoration costs are authoritative in FinanceSystem,
## GameState and PropertySystem. This scene helper must never grant hidden
## startup capital or replace the canonical restoration-stage configuration.

func _ready() -> void:
    var game = get_tree().root.get_node_or_null("Renew")
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    var state = get_node_or_null("/root/RenewGameState")
    if game == null or finance == null or state == null:
        return
    state.set_value("economy", "cash", int(finance.cash))
