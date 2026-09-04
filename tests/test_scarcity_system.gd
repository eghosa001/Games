extends SceneTree

var passed := 0
var failed := 0
func check(ok:bool,label:String)->void:
    if ok: passed+=1; print("PASS: "+label)
    else: failed+=1; push_error("FAIL: "+label)
func _init()->void: call_deferred("run")
func run()->void:
    var Economy=load("res://scripts/economy.gd")
    var ProductionSystem=load("res://scripts/production_system.gd")
    check(Economy!=null,"Economy loads")
    check(ProductionSystem!=null,"ProductionSystem loads")
    if Economy==null or ProductionSystem==null: quit(1); return
    var economy=Economy.new()
    var normal=int(economy.quote("timber",10,0)["cost"])
    economy.resources["timber"]["stock"]=10
    var scarce_state=economy.scarcity("timber")
    var scarce=int(economy.quote("timber",10,0)["cost"])
    check(float(scarce_state["availability"])<0.2,"Low stock produces low availability")
    check(float(scarce_state["price_multiplier"])>1.5,"Scarcity creates strong price pressure")
    check(scarce>normal,"Scarcity raises input purchase cost")
    check(float(scarce_state["production_factor"])<1.0,"Scarcity reduces production factor")

    var production=ProductionSystem.new()
    economy.resources["food"]["stock"]=100
    economy.resources["electronics"]["stock"]=140
    economy.resources["energy"]["stock"]=180
    production.inventory={"food":100,"electronics":100,"energy":100,"goods":0}
    var normal_run=production.produce(economy,10)
    economy.resources["food"]["stock"]=1
    economy.resources["electronics"]["stock"]=1
    economy.resources["energy"]["stock"]=1
    production.inventory={"food":100,"electronics":100,"energy":100,"goods":0}
    var scarce_run=production.produce(economy,10)
    check(normal_run["ok"],"Normal supply permits production")
    check(int(scarce_run.get("requested_cycles",0))==10,"Scarcity test requested full production")
    check(int(scarce_run.get("cycles",0))<int(normal_run.get("cycles",0)),"Scarcity reduces production throughput")

    print("SCARCITY SYSTEM RESULT: %d passed, %d failed"%[passed,failed])
    quit(1 if failed>0 else 0)
