extends Node

# Early-game balance pass. Keeps the first restoration arc completable without
# requiring a loan before the player has a functioning business.
func _ready() -> void:
    var game = get_parent()
    if game == null:
        return
    game.cash = max(int(game.cash), 40000)
    if game.has_method("_log"):
        game._log("BALANCE: early restoration financing adjusted for a clean first run.")
    game.stages = [
        ["Neglected", 0, 0],
        ["Cleaned", 20, 1000],
        ["Repaired", 40, 3000],
        ["Rebuilt", 60, 4500],
        ["Installed", 80, 6000],
        ["Designed", 100, 7500]
    ]
