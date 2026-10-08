extends Control

const GAME_SCENE_PATH: String = "res://scenes/main.tscn"
var starting_game: bool = false
var prompt_tween: Tween

@onready var prompt: TextureRect = $PressSpacePrompt

func _ready() -> void:
	prompt.modulate.a = 1.0
	prompt_tween = create_tween().set_loops()
	prompt_tween.set_trans(Tween.TRANS_SINE)
	prompt_tween.set_ease(Tween.EASE_IN_OUT)
	prompt_tween.tween_property(prompt, "modulate:a", 0.0, 0.65)
	prompt_tween.tween_interval(0.12)
	prompt_tween.tween_property(prompt, "modulate:a", 1.0, 0.65)
	prompt_tween.tween_interval(0.12)

func _input(event: InputEvent) -> void:
	if starting_game or not event.is_action_pressed(&"add_ingredient"):
		return
	if event is InputEventKey and event.echo:
		return
	starting_game = true
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
