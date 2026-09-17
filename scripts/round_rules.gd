extends RefCounted
## Mistakes last for the entire session, even after serving a drink.
enum Selection { IGNORED, CORRECT, MISTAKE, GAME_OVER }
const CAPACITY: int = 2
const MAX_MISTAKES: int = 2
const RECIPE: Array[StringName] = [&"orange", &"soda"]
const VALID_KINDS: Array[StringName] = [&"orange", &"soda", &"cherry"]
var selected: Array[StringName] = []
var mistakes: int = 0
var finished: bool = false
var timed_out: bool = false
var game_over: bool = false

func start_cup() -> void:
	if game_over:
		return
	selected.clear()
	finished = false
	timed_out = false

func select(kind: StringName) -> Selection:
	if finished or game_over or not VALID_KINDS.has(kind):
		return Selection.IGNORED
	if not RECIPE.has(kind) or selected.has(kind):
		mistakes += 1
		if mistakes >= MAX_MISTAKES:
			game_over = true
			finished = true
			return Selection.GAME_OVER
		return Selection.MISTAKE
	selected.append(kind)
	finished = selected.size() == CAPACITY
	return Selection.CORRECT

func expire() -> void:
	if not finished:
		timed_out = true
		finished = true

func is_success() -> bool:
	return finished and not timed_out and not game_over and selected.size() == CAPACITY
