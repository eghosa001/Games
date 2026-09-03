extends SceneTree

## Function-level release gate.
## Every declared function is discovered and verified as a callable method.
## Functions with no required arguments are also smoke-invoked where safe.
var passed := 0
var failed := 0
var scripts_checked := 0
var functions_checked := 0
var smoke_checked := 0
var failures: Array[String] = []

func _init() -> void:
    call_deferred("run")

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
    else:
        failed += 1
        failures.append(label)
        push_error("FAIL: " + label)

func run() -> void:
    var paths: Array[String] = []
    _collect_gd_scripts("res://scripts", paths)
    paths.sort()
    check(not paths.is_empty(), "GDScript source set discovered")

    for path in paths:
        scripts_checked += 1
        var source := FileAccess.get_file_as_string(path)
        check(not source.is_empty(), "source readable: " + path)
        var script = load(path)
        check(script != null, "script parses: " + path)
        if script == null:
            continue
        var declared := _declared_functions(source)
        var instance = null
        if script.has_method("new"):
            instance = script.new()
        for signature in declared:
            functions_checked += 1
            var method_name: String = signature.name
            check(instance != null and instance.has_method(method_name), "callable: %s::%s" % [path, method_name])
            if instance == null:
                continue
            if signature.required_args == 0 and _safe_zero_arg_smoke(method_name):
                smoke_checked += 1
                var result = instance.call(method_name)
                check(result != null or method_name in ["_ready", "_process", "_physics_process", "_init"], "smoke call: %s::%s" % [path, method_name])
        if instance is Node:
            instance.free()

    print("RENEW FUNCTION COVERAGE: %d passed, %d failed" % [passed, failed])
    print("Scripts: %d | Functions: %d | Zero-arg smoke calls: %d" % [scripts_checked, functions_checked, smoke_checked])
    for failure in failures:
        print("FAILED: " + failure)
    quit(1 if failed > 0 else 0)

func _safe_zero_arg_smoke(method_name: String) -> bool:
    # Lifecycle and mutating engine callbacks require an owning SceneTree/node context.
    return not ["_init", "_ready", "_enter_tree", "_exit_tree", "_process", "_physics_process", "_input", "_unhandled_input", "_notification", "_draw"].has(method_name)

func _collect_gd_scripts(path: String, result: Array[String]) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        if entry == "." or entry == "..":
            entry = dir.get_next()
            continue
        var full := path.path_join(entry)
        if dir.current_is_dir():
            _collect_gd_scripts(full, result)
        elif entry.ends_with(".gd") and not full.ends_with("test_function_coverage.gd"):
            result.append(full)
        entry = dir.get_next()
    dir.list_dir_end()

func _declared_functions(source: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for line in source.split("\n"):
        var stripped := line.strip_edges()
        if not stripped.begins_with("func "):
            continue
        var open := stripped.find("(")
        var close := stripped.rfind(")")
        if open <= 5 or close <= open:
            continue
        var name := stripped.substr(5, open - 5).strip_edges()
        if name.is_empty():
            continue
        var args_text := stripped.substr(open + 1, close - open - 1).strip_edges()
        var required := 0
        if not args_text.is_empty():
            for argument in args_text.split(","):
                if not argument.strip_edges().contains("="):
                    required += 1
        var duplicate := false
        for existing in result:
            if str(existing.name) == name:
                duplicate = true
                break
        if not duplicate:
            result.append({"name": name, "required_args": required})
    return result
