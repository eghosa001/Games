extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
    if ok:passed+=1;print("PASS: "+label)
    else:failed += 1;push_error("FAIL: "+label)
func _init()->void:call_deferred("run")
func run()->void:
    var State=load("res://scripts/game_state.gd");var Progression=load("res://scripts/progression_system.gd")
    check(State!=null,"GameState script loads");check(Progression!=null,"ProgressionSystem script loads")
    if State==null or Progression==null:quit(1);return
    var state=root.get_node_or_null("RenewGameState")
    if state==null:
        state=State.new();state.name="RenewGameState";root.add_child(state);await process_frame
    elif state.has_method("clear"):
        state.clear();await process_frame
    var progression=Progression.new();root.add_child(progression);await process_frame
    check(progression.get_level()==1,"Company starts at Level 1")
    check(progression.get_xp()==0,"Company starts at 0 XP")
    check(progression.has_unlock("restoration"),"Level 1 exposes restoration")
    check(progression.has_unlock("core_operations"),"Level 1 exposes core operations")
    check(not progression.has_unlock("acquisitions"),"Late-game acquisitions are not part of the opening progression")
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
    check(progression.has_unlock("company_level_2"),"Generic level unlock remains recorded for save compatibility")
    for feature in ["employees","contracts","finance"]:
        check(progression.has_unlock(feature),"Level 2 unlocks %s" % feature)
    check(not progression.has_unlock("regions"),"Regions remain a later milestone at Level 2")
    check(progression.get_features_for_level(3).has("regions"),"Level 3 progression contract includes regions")
    check(progression.get_features_for_level(6).has("infrastructure"),"Level 6 progression contract includes infrastructure")
    check(progression.get_features_for_level(7).has("acquisitions"),"Level 7 progression contract includes acquisitions")
    check(progression.get_features_for_level(9).has("legacy"),"Level 9 progression contract includes legacy")
    check(progression.get_features_for_level(10).has("endgame"),"Level 10 progression contract includes endgame")
    var before: int = progression.get_xp();progression.award_action("unknown_button")
    check(progression.get_xp()==before,"Unknown or non-meaningful actions award no XP")

    # Old saves only knew generic company levels. Semantic feature IDs must be
    # recoverable without wiping progress.
    state.set_value("progression","xp",1400)
    state.set_value("progression","level",6)
    state.set_value("progression","unlocks",["company_level_2","company_level_3","company_level_4","company_level_5","company_level_6"])
    progression._backfill_semantic_unlocks()
    check(progression.has_unlock("employees"),"Old save backfill restores early semantic unlocks")
    check(progression.has_unlock("diplomacy"),"Old save backfill restores diplomacy milestone")
    check(progression.has_unlock("infrastructure") and progression.has_unlock("technology"),"Old save backfill restores Level 6 strategic systems")

    state.set_value("progression","xp",0);state.set_value("progression","level",1);state.set_value("progression","unlocks",[])
    progression._backfill_semantic_unlocks()
    progression.sync_tracking()
    state.set_value("properties","restoration",25);state.set_value("properties","stage","Abandoned");progression._process(0.0)
    check(progression.get_xp()==10,"Restoration state change is tracked")
    print("PHASE 22 RESULT: %d passed, %d failed"%[passed,failed]);quit(1 if failed > 0 else 0)
