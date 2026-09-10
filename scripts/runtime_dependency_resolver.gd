extends RefCounted
class_name RenewRuntimeDependencyResolver

## Resolves runtime services without allowing a failed scene lookup to create a
## second authority. True autoloads are preferred; scene-owned domain services
## are resolved through RenewServices; direct scene paths remain a compatibility
## fallback for explicitly composed nodes that are not registry services.
static func resolve(autoload_name: String, scene_path: String = "") -> Node:
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null:
        return null
    var root := tree.root
    if root == null:
        return null

    var node := root.get_node_or_null(autoload_name)
    if node != null and is_instance_valid(node):
        return node

    var services := root.get_node_or_null("RenewServices")
    if services != null and is_instance_valid(services) and services.has_method("get_service"):
        node = services.get_service(autoload_name)
        if node != null and is_instance_valid(node):
            return node

    var scene := tree.current_scene
    if scene != null and scene_path != "":
        node = scene.get_node_or_null(scene_path)
        if node != null and is_instance_valid(node):
            return node

    return null

static func resolve_autoload_or_scene(autoload_name: String, scene_path: String = "") -> Node:
    return resolve(autoload_name, scene_path)
