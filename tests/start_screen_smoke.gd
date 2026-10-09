extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/start_screen.tscn", "Start screen is the project entry scene")
	check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280, "Project viewport width is 1280")
	check(ProjectSettings.get_setting("display/window/size/viewport_height") == 720, "Project viewport height is 720")
	var screen: Control = load("res://scenes/start_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	check(screen.size == Vector2(1280, 720), "Start screen uses the native 1280x720 canvas")
	check(screen.get_node("Background").size == Vector2(1280, 720), "Start artwork is displayed at native size")
	check(screen.get_node("Background").texture.resource_path == "res://art/start_screen/start_screen.png", "Start artwork is assigned")
	check(screen.get_node("PressSpacePrompt").texture.resource_path == "res://art/start_screen/press_space_to_start.png", "Space prompt artwork is assigned")
	check(screen.prompt_tween != null and screen.prompt_tween.is_valid(), "Space prompt has a looping fade animation")
	var initial_prompt_alpha: float = screen.get_node("PressSpacePrompt").modulate.a
	await create_timer(0.2).timeout
	check(screen.get_node("PressSpacePrompt").modulate.a < initial_prompt_alpha, "Space prompt begins fading slowly")
	await create_timer(0.5).timeout
	check(screen.get_node("PressSpacePrompt").modulate.a <= 0.02, "Space prompt completely disappears between fades")
	await create_timer(0.35).timeout
	check(screen.get_node("PressSpacePrompt").modulate.a > 0.05, "Space prompt fades back in")
	var held_space := InputEventKey.new()
	held_space.physical_keycode = KEY_SPACE
	held_space.pressed = true
	held_space.echo = true
	screen._input(held_space)
	check(not screen.starting_game, "Held Space does not start the game")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	screen._input(space)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.name == "Main", "Space opens the gameplay scene")
	check(current_scene != null and current_scene.scale == Vector2(2, 2), "Existing 640x360 gameplay fills the 1280x720 viewport")
	if current_scene != null:
		current_scene.free()
	if failures.is_empty():
		print("START_SCREEN_SMOKE_PASS: artwork, input, and gameplay transition")
		quit(0)
	else:
		quit(1)
