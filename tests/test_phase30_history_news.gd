extends SceneTree

func _init() -> void:
    var history=get_root().get_node_or_null("RenewHistorySystem")
    var news=get_root().get_node_or_null("RenewNewsSystem")
    assert(history!=null,"HistorySystem autoload missing")
    assert(news!=null,"NewsSystem autoload missing")
    assert(history.has_signal("gameplay_event_recorded"),"History event bus signal missing")
    assert(history.has_method("record"),"HistorySystem record() missing")
    assert(news.has_method("get_current_issue"),"NewsSystem issue API missing")
    var received:Dictionary={}
    var callable:=func(event:Dictionary):received=event
    history.gameplay_event_recorded.connect(callable)
    var day:=1
    var before:=news.get_current_issue()
    history.record("employee_promotion",day,"James Carter promoted to Factory Manager",{"employee_name":"James Carter","new_role":"Factory Manager"},"employee|emp_001|promotion")
    assert(not received.is_empty(),"History event was not emitted")
    await process_frame
    var issue:=news.get_current_issue()
    var found:=false
    for story in issue.get("stories",[]):
        if str(story.get("source_key",""))=="history|%s"%str(received.get("id","")):
            found=true
            assert(str(story.get("section",""))=="People","Promotion did not enter PEOPLE section")
            assert(str(story.get("body",""))=="James Carter has been promoted to Factory Manager.","Promotion copy is incorrect")
    assert(found,"NewsSystem did not receive the HistorySystem event")
    assert(bool(issue.get("verified_only",false)),"News issue is not verified-only")
    print("PHASE 30 HISTORY -> NEWS TESTS PASSED")
    quit()
