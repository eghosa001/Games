extends SceneTree

## Meta-test for the test suite itself. This catches tests that can silently
## report success because assertions are compiled out, exit successfully after
## failures, or retry random behavior until a pass occurs.

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
        # This file intentionally contains the word split below so it does not
        # match its own forbidden-pattern scan.
        if path == "res://tests/test_test_quality_integrity.gd":
            continue
        scanned += 1
        var source := FileAccess.get_file_as_string(path)
        check(not source.is_empty(), "Test source is readable: " + path)

        var assert_token := "ass" + "ert("
        check(not source.contains(assert_token), "No assert()-only test assertions: " + path)
        check(not source.contains("quit()"), "No unconditional bare quit(): " + path)
        check(not source.contains("for attempt in range(20)"), "No 20-attempt retry masking randomness: " + path)

        if source.contains("extends SceneTree"):
            check(source.contains("quit(1 if failed > 0 else 0)"), "SceneTree test has failure-aware exit status: " + path)
            check(source.contains("failed += 1"), "SceneTree test records failures explicitly: " + path)

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
