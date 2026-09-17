extends SceneTree
const Rules = preload("res://scripts/round_rules.gd")
var failures: Array[String] = []
var exit_count: int = 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func press(scene: Control, echo: bool = false, code: Key = KEY_SPACE) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	key.echo = echo
	scene._input(key)

func pick(scene: Control, kind: StringName, x: float = 484.0) -> void:
	var item = scene._spawn_ingredient(kind)
	item.position.x = x
	press(scene)

func _run() -> void:
	for recipe in [[&"orange", &"soda"], [&"soda", &"orange"]]:
		var model = Rules.new()
		check(model.select(recipe[0]) == Rules.Selection.CORRECT, "First correct ingredient")
		check(not model.finished, "One correct selection keeps playing")
		model.select(recipe[1])
		check(model.is_success(), "Both recipe orders succeed")
	var model = Rules.new()
	check(model.select(&"unknown") == Rules.Selection.IGNORED, "Unknown kinds ignored")
	model.select(&"orange")
	check(model.select(&"orange") == Rules.Selection.MISTAKE, "Duplicate is a mistake immediately")
	check(model.mistakes == 1 and model.selected.size() == 1 and not model.finished, "First mistake does not fill the cup or finish")
	model.select(&"soda")
	check(model.is_success(), "Can complete after the first mistake")
	model.start_cup()
	check(model.mistakes == 1 and model.selected.is_empty(), "Mistake persists after a successful cup")
	check(model.select(&"cherry") == Rules.Selection.GAME_OVER, "Second wrong item ends session")
	model.start_cup()
	check(model.game_over and model.finished and model.mistakes == 2, "Cannot bypass game over")
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	scene.quit_on_game_over = false
	scene.exit_requested.connect(func(): exit_count += 1)
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	check(scene.get_node("CustomerWindow/Customer").texture.resource_path == "res://icon.svg", "Customer uses Godot logo")
	check(scene.get_node("Track/Rail") is ColorRect and scene.hit_zone.color.g > scene.hit_zone.color.r, "Separate gray rail and green zone")
	check(scene.get_node("Cup").size == Vector2(60, 90), "Rectangle cup keeps 60x90 dimensions")
	scene._clear_ingredients()
	var item = scene._spawn_ingredient(&"orange")
	item.position.x = 451.9
	press(scene)
	check(scene.rules.selected.is_empty() and scene.rules.mistakes == 0, "Timing miss is not a wrong-item strike")
	item.position.x = 452.0
	press(scene, true)
	press(scene, false, KEY_ENTER)
	check(scene.rules.selected.is_empty(), "Held key and Enter cannot select")
	press(scene)
	check(scene.rules.selected.size() == 1 and scene.fruit_container.get_child_count() == 1, "Space accepts left boundary and puts circle inside cup")
	pick(scene, &"cherry")
	check(scene.rules.mistakes == 1 and not scene.rules.finished and exit_count == 0, "First wrong item does not quit")
	check(scene.get_node_or_null("Feedback") == null and scene.get_node_or_null("Mistakes") == null, "No action feedback or error-count text")
	pick(scene, &"soda", 516.0)
	check(scene.rules.is_success() and scene.result_panel.visible and scene.liquid.visible, "Right boundary completes cup automatically")
	scene.restart_delay = 0.0
	press(scene, true)
	check(scene.rules.finished, "Holding Space cannot restart")
	press(scene)
	check(not scene.rules.finished and scene.rules.mistakes == 1, "Same key starts next cup with mistakes preserved")
	check(scene.fruit_container.get_child_count() == 0 and not scene.liquid.visible, "Next cup clears its contents")
	scene.elapsed = scene.round_duration - 0.01
	scene._process(0.02)
	check(scene.rules.timed_out and scene.rules.mistakes == 1, "Timeout does not add or reset mistakes")
	scene.restart_delay = 0.0
	press(scene)
	scene._clear_ingredients()
	pick(scene, &"cherry")
	check(scene.rules.game_over and exit_count == 1, "Second wrong selection requests exit immediately")
	press(scene)
	check(scene.rules.game_over and exit_count == 1, "No restart or repeat exit after game over")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("ALPHA_SMOKE_PASS: simple placeholders, one-key input, boundaries, cup, first mistake, persistent second-mistake exit")
		quit(0)
	else:
		quit(1)
