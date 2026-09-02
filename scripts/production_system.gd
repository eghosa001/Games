extends Node
class_name RenewProductionSystem

const SYSTEM_VERSION := 1
var finished_goods: int = 0
var quality: int = 60
var recipe := {"materials": 1, "packaging": 1, "fuel": 1}
var output_per_cycle := 2
var history: Array[Dictionary] = []

func produce(economy: RenewEconomy, cycles: int) -> Dictionary:
    if economy == null or cycles <= 0:
        return {"ok": false, "cycles": 0, "output": 0, "quality": quality}
    var possible := cycles
    for resource in recipe:
        if not economy.resources.has(resource):
            return {"ok": false, "cycles": 0, "output": 0, "quality": quality}
        possible = min(possible, int(economy.resources[resource]["stock"] / int(recipe[resource])))
    if possible <= 0:
        return {"ok": false, "cycles": 0, "output": 0, "quality": quality}
    for resource in recipe:
        economy.resources[resource]["stock"] -= int(recipe[resource]) * possible
    quality = clamp(quality + randi_range(-3, 4), 30, 100)
    var output := possible * output_per_cycle
    finished_goods += output
    history.append({"cycles": possible, "output": output, "quality": quality})
    if history.size() > 250: history.pop_front()
    return {"ok": true, "cycles": possible, "output": output, "quality": quality, "finished_goods": finished_goods}

func consume_goods(amount: int) -> bool:
    if amount < 0 or amount > finished_goods: return false
    finished_goods -= amount
    return true

func capture_state() -> Dictionary:
    return {"system_version": SYSTEM_VERSION, "finished_goods": finished_goods, "quality": quality, "recipe": recipe.duplicate(true), "output_per_cycle": output_per_cycle, "history": history.duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    finished_goods = int(snapshot.get("finished_goods", 0))
    quality = int(snapshot.get("quality", 60))
    recipe = snapshot.get("recipe", recipe).duplicate(true)
    output_per_cycle = int(snapshot.get("output_per_cycle", 2))
    history = snapshot.get("history", []).duplicate(true)
