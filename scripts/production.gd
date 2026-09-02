extends RefCounted
class_name RenewProduction

var recipe := {"materials": 1, "packaging": 1, "fuel": 1}
var output_per_cycle := 2
var quality := 60

func produce(economy: RenewEconomy, cycles: int) -> Dictionary:
    var possible := cycles
    for resource in recipe:
        possible = min(possible, int(economy.resources[resource]["stock"] / recipe[resource]))
    if possible <= 0:
        return {"ok": false, "cycles": 0, "output": 0, "quality": quality}
    for resource in recipe:
        economy.resources[resource]["stock"] -= recipe[resource] * possible
    var output := possible * output_per_cycle
    quality = clamp(quality + randi_range(-3, 4), 30, 100)
    return {"ok": true, "cycles": possible, "output": output, "quality": quality}
