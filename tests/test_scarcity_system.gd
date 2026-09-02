extends SceneTree

var passed := 0
var failed := 0
func check(ok:bool,label:String)->void:
    if ok: passed+=1; print("PASS: "+label)
    else: failed+=1; push_error("FAIL: "+label)
func _init()->void: call_deferred("run")
func run()->void:
    var Economy=load("res://scripts/economy.gd")
    var Production=load("res://scripts/production.gd")
    check(Economy!=null,"Economy loads")
    check(Production!=null,"Production facade loads")
    if Economy==null or Production==null: quit(1); return
    var economy=Economy.new()
    var normal=int(economy.quote("materials",10,0)["cost"])
    economy.resources["materials"]["stock"]=10
    var scarce_state=economy.scarcity("materials")
    var scarce=int(economy.quote("materials",10,0)["cost"])
    check(float(scarce_state["availability"])<0.2,"Low stock produces low availability")
    check(float(scarce_state["price_multiplier"])>1.5,"Scarcity creates strong price pressure")
    check(scarce>normal,"Scarcity raises input purchase cost")
    check(float(scarce_state["production_factor"])<1.0,"Scarcity reduces production factor")

    var production=Production.new()
    production.system.inventory={"materials":100,"packaging":100,"fuel":100,"goods":0}
    var normal_run=production.produce(economy,10)
    economy.resources["materials"]["stock"]=1
    economy.resources["packaging"]["stock"]=1
    economy.resources["fuel"]["stock"]=1
    production.system.inventory={"materials":100,"packaging":100,"fuel":100,"goods":0}
    var scarce_run=production.produce(economy,10)
    check(normal_run["ok"],"Normal supply permits production")
    check(int(scarce_run.get("requested_cycles",0))==10,"Scarcity test requested full production")
    check(int(scarce_run.get("cycles",0))<int(normal_run.get("cycles",0)),"Scarcity reduces production throughput")

    print("SCARCITY SYSTEM RESULT: %d passed, %d failed"%[passed,failed])
    quit(1 if failed>0 else 0)
