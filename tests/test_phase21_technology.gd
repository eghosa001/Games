extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS: "+label)
    else:failed+=1;push_error("FAIL: "+label)
func _init()->void:call_deferred("run")
func run()->void:
    var State=load("res://scripts/game_state.gd");var Tech=load("res://scripts/technology_system.gd")
    check(State!=null,"GameState script loads");check(Tech!=null,"TechnologySystem script loads")
    if State==null or Tech==null:quit(1);return
    var state=State.new();state.name="RenewGameState";root.add_child(state);await process_frame
    var tech=Tech.new();root.add_child(tech);await process_frame
    check(tech.get_technologies().size()==9,"V1 technology tree has 9 technologies")
    check(tech.get_technology("automation").get("name","")=="Automation","Automation exists")
    check(tech.get_technology("smart_factory").get("tier",0)==3,"Smart Factory is Tier 3")
    check(tech.can_research("efficient_production").get("ok",false)==true,"Tier 1 research is available")
    var start_cash=int(state.get_value("economy","cash",0));var start_points=int(state.get_value("technology","research_points",0));var start_day=int(state.get_value("player","day",0))
    check(tech.research("efficient_production"),"Efficient Production researches")
    check(int(state.get_value("economy","cash",0))==start_cash-2500,"Research consumes money")
    check(int(state.get_value("technology","research_points",0))==start_points-10,"Research consumes research points")
    check(int(state.get_value("player","day",0))==start_day+2,"Research consumes time")
    check(tech.is_unlocked("efficient_production"),"Technology is unlocked in GameState")
    check(tech.production_multiplier()>1.0,"Technology changes production multiplier")
    tech.add_daily_research_points(10)
    check(tech.research("automation"),"Automation researches after prerequisite")
    check(tech.worker_reduction()==1,"Automation reduces worker requirement by one")
    check(tech.maintenance_multiplier()>1.0,"Automation increases maintenance")
    check(tech.research("smart_factory")==false,"Tier 3 cannot research without enough research points")
    tech.add_daily_research_points(3)
    check(int(state.get_value("technology","research_points",0))==8,"Daily research points are awarded")
    print("PHASE 21 RESULT: %d passed, %d failed"%[passed,failed]);quit(1 if failed>0 else 0)
