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
	print("EXIT_CHECK_FIRST_MISTAKE_CONTINUES")
	var second = scene._spawn_ingredient(&"cherry")
	second.position.x = 484.0
	scene.select_ingredient()
	# Gameplay should quit at frame end. This timeout runs only if it fails to quit.
	await create_timer(0.2).timeout
	push_error("Second mistake did not close the game")
	quit(1)
