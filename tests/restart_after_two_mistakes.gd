extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._clear_ingredients()
	var first = scene._spawn_ingredient(&"cherry")
	first.position.x = 484.0
	scene.select_ingredient()
	if scene.rules.mistakes != 1 or scene.rules.finished:
		quit(1)
		return
	print("RESTART_CHECK_FIRST_MISTAKE_CONTINUES")
	var second = scene._spawn_ingredient(&"cherry")
	second.position.x = 484.0
	scene.select_ingredient()
	if not scene.rules.game_over or not scene.result_panel.visible:
		push_error("Second mistake did not show the restart state")
		quit(1)
		return
	if scene.result_title.text != "Two mistakes!" or scene.result_retry.text != "SPACE: try again":
		push_error("Restart prompt text is incorrect")
		quit(1)
		return
	scene.restart_delay = 0.0
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	scene._input(space)
	if scene.rules.game_over or scene.rules.finished or scene.rules.mistakes != 0:
		push_error("Space did not restart the game")
		quit(1)
		return
	print("RESTART_CHECK_PASS: second mistake waits for Space and restarts")
	quit(0)
