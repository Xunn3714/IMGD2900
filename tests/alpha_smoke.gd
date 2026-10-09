extends SceneTree
const Rules = preload("res://scripts/round_rules.gd")
var failures: Array[String] = []

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
	for fruit in Rules.FRUIT_KINDS:
		for recipe in [[fruit, &"soda"], [&"soda", fruit]]:
			var flavor_model = Rules.new()
			flavor_model.start_cup(fruit)
			check(flavor_model.select(recipe[0]) == Rules.Selection.CORRECT, "First ingredient accepted for %s" % fruit)
			flavor_model.select(recipe[1])
			check(flavor_model.is_success(), "%s soda works in both orders" % fruit)
	for recipe in [[&"orange", &"soda"], [&"soda", &"orange"]]:
		var model = Rules.new()
		check(model.select(recipe[0]) == Rules.Selection.CORRECT, "First correct ingredient")
		check(not model.finished, "One correct selection keeps playing")
		model.select(recipe[1])
		check(model.is_success(), "Both recipe orders succeed")
	var wrong_flavor_model = Rules.new()
	wrong_flavor_model.start_cup(&"blueberry")
	check(wrong_flavor_model.select(&"orange") == Rules.Selection.MISTAKE, "A fruit from another order is a mistake")
	var model = Rules.new()
	check(model.select(&"unknown") == Rules.Selection.IGNORED, "Unknown kinds ignored")
	model.select(&"orange")
	check(model.select(&"orange") == Rules.Selection.MISTAKE, "Duplicate is a mistake immediately")
	check(model.mistakes == 1 and model.selected.size() == 1 and not model.finished, "First mistake does not fill the cup or finish")
	model.select(&"soda")
	check(model.is_success(), "Can complete after the first mistake")
	model.start_cup()
	check(model.mistakes == 0 and model.selected.is_empty(), "A new drink resets its mistake count")
	check(model.select(&"cherry") == Rules.Selection.MISTAKE, "First wrong item in a new drink continues")
	check(model.select(&"cherry") == Rules.Selection.GAME_OVER, "Second wrong item in the same drink ends session")
	model.start_cup()
	check(model.game_over and model.finished and model.mistakes == 2, "Cannot bypass game over")
	model.restart_game()
	check(not model.game_over and not model.finished and model.mistakes == 0, "Restart clears the game-over state")
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	check(scene.get_node("CustomerWindow/Customer").texture.resource_path == "res://art/customers/blue_bear.png", "Default customer uses Blue Bear")
	check(scene.get_node("Track/Rail") is ColorRect and scene.hit_zone.color.g > scene.hit_zone.color.r, "Separate gray rail and green zone")
	check(scene.get_node("Cup").size == Vector2(60, 90), "Empty cup artwork keeps 60x90 dimensions")
	check(scene.get_node("Cup/EmptyCup") is TextureRect and scene.get_node("Cup/EmptyCup").texture == scene.empty_cup_art, "Empty cup artwork replaces the rectangle placeholder")
	check(scene.selection_slots[0].size == Vector2(44, 66) and scene.selection_slots[2].position == Vector2(526, 270), "Cup-side selections use the larger three-slot layout")
	var first_order: StringName = scene.current_fruit
	check(scene.order_fruits.has(first_order), "First order randomly chooses a supported fruit")
	check(scene.order_image.texture == scene.finished_drinks[first_order], "Thinking bubble matches the random order")
	check(scene.current_ingredient_speed == scene.ingredient_speed, "First drink uses the base ingredient speed")
	check(scene._ingredient_speed_for_round(1000) == scene.max_ingredient_speed, "Ingredient speed stops at its configured maximum")
	check(scene.ingredient_container.get_child_count() == 1 and scene.bag.size() == 9, "First ingredient is drawn from the shuffled spawn bag")
	scene.bag.clear()
	scene.non_soda_spawn_streak = 0
	var generated_kinds: Array[StringName] = []
	var longest_non_soda_streak: int = 0
	var current_non_soda_streak: int = 0
	for index in 12:
		var generated_kind: StringName = scene._next_kind()
		generated_kinds.append(generated_kind)
		if generated_kind == &"soda":
			current_non_soda_streak = 0
		else:
			current_non_soda_streak += 1
			longest_non_soda_streak = maxi(longest_non_soda_streak, current_non_soda_streak)
	check(generated_kinds.count(&"soda") >= 4, "Soda has a higher spawn weight")
	check(longest_non_soda_streak <= 2, "At most two non-soda ingredients spawn between sodas")
	scene.bag.clear()
	scene.non_soda_spawn_streak = 0
	scene._clear_ingredients()
	var item = scene._spawn_ingredient(first_order)
	var visual: Sprite2D = item.get_node("Visual")
	var visual_size: Vector2 = Vector2(visual.texture.get_width(), visual.texture.get_height()) * visual.scale
	var expected_visual_size: float = 68.0 if first_order == &"grape" else 56.0
	check(is_equal_approx(maxf(visual_size.x, visual_size.y), expected_visual_size), "QTE fruit artwork uses its tuned display size")
	var ingredient_half_width: float = visual.texture.get_width() * absf(visual.scale.x) * 0.5
	var left_hit_boundary: float = scene.hit_center - scene.hit_width * 0.5 - scene.hit_tolerance - ingredient_half_width
	item.position.x = left_hit_boundary - 0.1
	press(scene)
	check(scene.rules.selected.is_empty() and scene.rules.mistakes == 0, "Timing miss is not a wrong-item strike")
	item.position.x = left_hit_boundary
	press(scene, true)
	press(scene, false, KEY_ENTER)
	check(scene.rules.selected.is_empty(), "Held key and Enter cannot select")
	press(scene)
	check(scene.rules.selected.size() == 1 and scene.fruit_container.get_child_count() == 0 and not scene.drink.visible, "Visible fruit overlap is accepted and fruit-first leaves the cup empty")
	check(scene.selection_slots[0].visible and scene.selection_slots[0].texture == scene.selection_icons[first_order], "Selected fruit shows its syrup beside the cup")
	pick(scene, &"cherry")
	check(scene.rules.mistakes == 1 and not scene.rules.finished, "First wrong item keeps the current drink active")
	check(scene.angry_overlay.visible and scene.angry_overlay.texture == scene.angry1_art and scene.angry_overlay.position == Vector2(75, 32) and scene.angry_overlay.size == Vector2(90, 84), "First mistake shows the enlarged Angry1 on the customer's face")
	var original_customer_texture: Texture2D = scene.customer_image.texture
	scene.customer_image.texture = load("res://art/customers/froish.png")
	scene._show_anger(1)
	check(scene.angry_overlay.position == Vector2(67, 32), "Frog moves Angry1 slightly left to align with its face")
	scene._show_anger(2)
	check(scene.angry_overlay.position == Vector2(122, 32), "Frog keeps Angry2 in the shared head position")
	scene.customer_image.texture = original_customer_texture
	scene._show_anger(1)
	check(scene.selection_slots[1].visible and scene.selection_slots[1].texture == scene.cherry_syrup_art, "Wrong fruit also leaves its syrup beside the cup")
	check(scene.get_node_or_null("Feedback") == null and scene.get_node_or_null("Mistakes") == null, "No action feedback or error-count text")
	pick(scene, &"soda", 516.0)
	check(scene.rules.is_success() and scene.result_panel.visible and scene.drink.visible, "Right boundary completes cup with matching soda art")
	check(scene.drink.texture == scene.finished_drinks[first_order], "Finished cup matches the random order")
	check(scene.selection_slots[2].visible and scene.selection_slots[2].texture == scene.soda_art, "Selected soda shows after the wrong selection")
	check(scene.get_node("Cup").position.x < 454.0 and scene.selection_slots[0].position.x > scene.get_node("Cup").position.x + scene.get_node("Cup").size.x, "Cup moves left to make room for three selection icons")
	scene.restart_delay = 0.0
	press(scene, true)
	check(scene.rules.finished, "Holding Space cannot restart")
	press(scene)
	check(not scene.rules.finished and scene.rules.mistakes == 0, "Same key starts next cup with mistakes reset")
	check(scene.current_ingredient_speed == minf(scene.ingredient_speed + scene.speed_increase_per_round, scene.max_ingredient_speed), "Next drink increases ingredient speed")
	var second_order: StringName = scene.current_fruit
	check(scene.order_fruits.has(second_order) and second_order != first_order, "Next order is random without an immediate repeat")
	check(scene.order_image.texture == scene.finished_drinks[second_order], "Next thinking bubble matches its order")
	check(scene.fruit_container.get_child_count() == 0 and not scene.drink.visible, "Next cup clears its contents")
	check(not scene.selection_slots[0].visible and not scene.selection_slots[1].visible and not scene.selection_slots[2].visible and scene.displayed_choice_count == 0, "Next cup clears all three selection icons")
	scene._clear_ingredients()
	pick(scene, second_order)
	pick(scene, &"soda")
	check(scene.rules.is_success() and scene.drink.texture == scene.finished_drinks[second_order], "Second random order uses matching finished art")
	scene.restart_delay = 0.0
	press(scene)
	check(scene.current_fruit != second_order, "Third random order also avoids an immediate repeat")
	scene.elapsed = scene.round_duration - 0.01
	scene._process(0.02)
	check(scene.rules.timed_out and scene.rules.mistakes == 0, "Timeout does not add a mistake")
	scene.restart_delay = 0.0
	press(scene)
	scene._clear_ingredients()
	pick(scene, &"cherry")
	check(not scene.rules.game_over and scene.rules.mistakes == 1, "First mistake in this drink still continues")
	pick(scene, &"cherry")
	check(scene.rules.game_over and scene.rules.finished, "Second mistake pauses the game")
	check(scene.angry_overlay.visible and scene.angry_overlay.texture == scene.angry2_art and scene.angry_overlay.position == Vector2(122, 32) and scene.angry_overlay.size == Vector2(40, 40), "Second mistake replaces Angry1 with the smaller Angry2 above the customer's head")
	check(scene.result_panel.visible and scene.result_title.text == "Two mistakes!" and scene.result_retry.text == "SPACE: try again", "Game over shows the restart prompt in the lower-left result panel")
	var failed_order: StringName = scene.current_fruit
	scene.restart_delay = 0.0
	press(scene)
	check(not scene.rules.game_over and not scene.rules.finished and scene.rules.mistakes == 0, "Space restarts after two mistakes")
	check(scene.rounds_started == 1 and scene.current_ingredient_speed == scene.ingredient_speed, "Restart resets the difficulty progression")
	check(scene.current_fruit != failed_order and not scene.result_panel.visible and not scene.angry_overlay.visible, "Restart creates a fresh order and clears the failure UI")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("ALPHA_SMOKE_PASS: rising speed, frequent soda, per-drink mistakes, recipes, art, input, restart")
		quit(0)
	else:
		quit(1)
