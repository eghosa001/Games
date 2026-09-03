extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS: "+label)
    else:failed+=1;push_error("FAIL: "+label)
func _init()->void:call_deferred("run")
func run()->void:
    var State=load("res://scripts/game_state.gd");var Progression=load("res://scripts/progression_system.gd")
    check(State!=null,"GameState script loads");check(Progression!=null,"ProgressionSystem script loads")
    if State==null or Progression==null:quit(1);return
    var state=State.new();state.name="RenewGameState";root.add_child(state);await process_frame
    var progression=Progression.new();root.add_child(progression);await process_frame
    check(progression.get_level()==1,"Company starts at Level 1")
    check(progression.get_xp()==0,"Company starts at 0 XP")
    progression.award_action("restoration_step")
    check(progression.get_xp()==10,"Restoration earns meaningful XP")
    progression.award_action("production_run")
    check(progression.get_xp()==22,"Production earns meaningful XP")
    progression.award_profit(1000)
    check(progression.get_xp()==32,"Profit earns XP based on actual profit")
    progression.award_action("contract_signed")
    progression.award_action("employee_hired")
    progression.award_action("expansion_purchased")
    check(progression.get_xp()==107,"Contracts, employees and expansion earn XP")
    check(progression.get_level()==2,"XP crosses Company Level 2")
    check(progression.has_unlock("company_level_2"),"Level unlock is recorded")
    var before:=progression.get_xp();progression.award_action("unknown_button")
    check(progression.get_xp()==before,"Unknown or non-meaningful actions award no XP")
    state.set_value("progression","xp",0);state.set_value("progression","level",1);state.set_value("progression","unlocks",[])
    progression.sync_tracking()
    state.set_value("properties","restoration",25);state.set_value("properties","stage","Abandoned");progression._process(0.0)
    check(progression.get_xp()==10,"Restoration state change is tracked")
    print("PHASE 22 RESULT: %d passed, %d failed"%[passed,failed]);quit(1 if failed>0 else 0)
