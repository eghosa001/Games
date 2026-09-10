extends SceneTree

## Meta-test for the test suite itself. This catches tests that can silently
## report success because assertions are compiled out, exit successfully after
## failures, retry random behavior until a pass occurs, or depend on arbitrary timing.

var passed := 0
var failed := 0
var failures: Array[String] = []
var scanned := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        failures.append(label)
        push_error("FAIL: " + label)

func run() -> void:
    var files: Array[String] = []
    _collect_gd_files("res://tests", files)
    check(files.size() >= 1, "Test suite contains Godot test scripts")

    for path in files:
        if path == "res://tests/test_test_quality_integrity.gd":
            continue
        scanned += 1
        var source := FileAccess.get_file_as_string(path)
        check(not source.is_empty(), "Test source is readable: " + path)

        var assert_token := "ass" + "ert("
        var tautology_token := "check(" + "true,"
        check(not source.contains(assert_token), "No assert()-only test assertions: " + path)
        check(not source.contains("quit()"), "No unconditional bare quit(): " + path)
        check(not source.contains("for attempt in range(20)"), "No 20-attempt retry masking randomness: " + path)
        check(not source.contains(tautology_token), "No tautological check(true, ...) assertions: " + path)

        check(not source.contains("OS.delay_msec("), "No millisecond wall-clock sleeps in tests: " + path)
        check(not source.contains("OS.delay_usec("), "No microsecond wall-clock sleeps in tests: " + path)
        check(not source.contains("Thread.sleep("), "No thread sleeps in tests: " + path)
        check(not source.contains("await get_tree().create_timer("), "No arbitrary SceneTree timer waits in tests: " + path)

        if source.contains("extends SceneTree"):
            var has_failure_counter := source.contains("failed += 1")
            var has_failure_collection := source.contains("failures.append(")
            check(has_failure_counter or has_failure_collection, "SceneTree test records failures explicitly: " + path)
            var has_counter_exit := source.contains("quit(1 if failed > 0 else 0)")
            var has_collection_exit := source.contains("quit(1 if not failures.is_empty() else 0)")
            var has_failed_collection_exit := source.contains("quit(1 if failures.size() > 0 else 0)")
            check(has_counter_exit or has_collection_exit or has_failed_collection_exit, "SceneTree test has failure-aware exit status: " + path)

    print("TEST SUITE INTEGRITY RESULT: %d scanned, %d passed, %d failed" % [scanned, passed, failed])
    if not failures.is_empty():
        for item in failures:
            print("FAILED: " + item)
    quit(1 if failed > 0 else 0)

func _collect_gd_files(directory_path: String, output: Array[String]) -> void:
    var dir := DirAccess.open(directory_path)
    if dir == null:
        check(false, "Test directory can be opened: " + directory_path)
        return
    dir.list_dir_begin()
    while true:
        var entry := dir.get_next()
        if entry.is_empty():
            break
        if entry == "." or entry == "..":
            continue
        var full_path := directory_path.path_join(entry)
        if dir.current_is_dir():
            _collect_gd_files(full_path, output)
        elif entry.ends_with(".gd"):
            output.append(full_path)
    dir.list_dir_end()
