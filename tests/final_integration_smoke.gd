extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	check(scene.scale == Vector2(2, 2), "Gameplay scales to fill the 1280x720 viewport")
	check(not scene.has_node("InstructionsBox"), "Instruction box is removed")
	check(not scene.has_node("LegendOrange") and not scene.has_node("LegendCherry"), "Ingredient legend is removed")
	check(scene.get_node("CustomerWindow").position == Vector2(32, 12) and scene.get_node("CustomerWindow").size == Vector2(448, 156), "Customer window leaves room for the recipe book")
	check(scene.get_node("CustomerWindow/Customer").size == Vector2(110, 115), "Customer is smaller and moved toward the center")
	check(scene.get_node("CustomerWindow/OrderBubble").size == Vector2(200, 140), "Thought bubble is resized and repositioned")
	check(scene.order_image.size == Vector2(52, 82), "Requested drink fits inside the thought bubble")
	check(scene.get_node("RecipeBook").position == Vector2(500, 28) and scene.get_node("RecipeBook").size == Vector2(120, 120), "Recipe book fills the right-side space")
	check(scene.angry1_art != null and scene.angry2_art != null and not scene.angry_overlay.visible, "Angry artwork is loaded and starts hidden")
	check(scene.round_duration == 45.0, "Final branch keeps its 45 second round")
	check(scene.correct_pick_sound != null and scene.wrong_pick_sound != null and scene.pick_sound_player != null, "Correct and wrong sounds are loaded")
	var item: Node2D = scene._spawn_ingredient(&"orange")
	var visual: Sprite2D = item.get_node("Visual")
	item.advance(0.2)
	check(absf(visual.position.y) > 0.01 or absf(visual.rotation) > 0.001, "Ingredient bob and tilt animation is active")
	scene._clear_ingredients()
	scene.elapsed = scene.round_duration * 0.25
	scene._process(0.0)
	check(scene.hit_width < 40.0, "Hit zone shrinks during the round")
	scene._randomize_hit_zone_speed()
	check(scene.hit_zone_speed >= 255.0 and scene.hit_zone_speed <= 355.0, "Hit zone uses the faster progressive speed range")
	var correct: Node2D = scene._spawn_ingredient(scene.current_fruit)
	correct.position.x = scene.hit_center
	scene.select_ingredient()
	check(scene.pick_sound_player.stream == scene.correct_pick_sound, "Correct selection uses the correct sound")
	var wrong: Node2D = scene._spawn_ingredient(&"cherry")
	wrong.position.x = scene.hit_center
	scene.select_ingredient()
	check(scene.pick_sound_player.stream == scene.wrong_pick_sound, "Wrong selection uses the wrong sound")
	scene.pick_sound_player.stop()
	scene.pick_sound_player.stream = null
	scene.correct_pick_sound = null
	scene.wrong_pick_sound = null
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("FINAL_INTEGRATION_SMOKE_PASS: layout, animation, QTE, and audio")
		quit(0)
	else:
		quit(1)
