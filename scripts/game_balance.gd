extends Node

# Early-game balance pass. Keeps the first restoration arc completable without
# requiring a loan before the player has a functioning business.
func _ready() -> void:
    var game = get_tree().root.get_node_or_null("Renew")
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    if game == null or finance == null:
        return
    if int(finance.cash) < 40000:
        var financing_result: Dictionary = finance.record_equity(40000 - int(finance.cash), "early restoration financing")
        if bool(financing_result.get("ok", false)):
            game.cash = int(finance.cash)
    else:
        game.cash = int(finance.cash)
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
