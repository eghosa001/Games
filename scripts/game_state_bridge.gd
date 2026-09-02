extends Node2D

# Transitional compatibility bridge. Persistence is owned exclusively by
# RenewSaveSystem/GameState. This node must never write a second save file.
var parent: Node
var last_day := 0

func _ready() -> void:
    parent = get_parent()
    if parent != null:
        last_day = int(parent.get("day"))

func _process(_delta: float) -> void:
    if parent == null:
        return
    var current_day := int(parent.get("day"))
    if current_day != last_day:
        last_day = current_day
        var game_state = _game_state()
        if game_state != null:
            game_state.mark_dirty()

func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_F5:
            if parent != null and parent.has_method("save_game"):
                parent.call("save_game")
        KEY_F9:
            if parent != null and parent.has_method("load_game"):
                parent.call("load_game")

func snapshot() -> Dictionary:
    var game_state = _game_state()
    if game_state == null or not game_state.has_state():
        return {}
    return game_state.data.duplicate(true)

func _game_state():
    var tree = Engine.get_main_loop()
    if tree == null:
        return null
    var root = tree.get_root()
    if root == null:
        return null
    return root.get_node_or_null("RenewGameState")
