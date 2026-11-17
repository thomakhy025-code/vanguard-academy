extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var game = root.get_node("Game")
	if not game.is_locked(game.Place.GATE):
		push_error("East Gate should be locked")
		quit(1)
		return
	if game.is_locked(game.Place.WASTES) or game.is_locked(game.Place.YARD):
		push_error("A field is locked")
		quit(1)
		return
	game.place = game.Place.YARD
	game.court_mode = "even"
	game.hunt_rank = 4
	var hunt: float = game.outgoing(true)
	game.title = "Gold Ring"
	game.even_title = "Silver Ring"
	game.ribbon = "e2c56a"
	game.pose = "raised"
	game.open_wins = 9
	if not is_equal_approx(game.outgoing(true), hunt):
		push_error("A title changed hunt damage")
		quit(1)
		return
	if not is_equal_approx(game.hunt_damage(), 20.0):
		push_error("Hunt rank 4 should hit for 20")
		quit(1)
		return
	game.place = game.Place.COURT
	game.court_mode = "even"
	if not game.normalized() or not is_equal_approx(game.outgoing(true), 12.0):
		push_error("Even Match did not normalize")
		quit(1)
		return
	if not is_equal_approx(game.spirit_against_monsters(10.0), 10.0):
		push_error("Even Match kept a spirit bonus")
		quit(1)
		return
	game.court_mode = "open"
	if game.normalized() or not is_equal_approx(game.outgoing(true), 20.0):
		push_error("Open Match ignored hunt rank")
		quit(1)
		return
	var spirit: float = game.spirit_against_monsters(10.0)
	if spirit <= 10.0:
		push_error("Open spirit trick did not scale")
		quit(1)
		return
	game.even_wins = 0
	if game.rival_name("even") != "Nia Pell":
		push_error("Even rival was %s" % game.rival_name("even"))
		quit(1)
		return
	game.stamps["guard"] = false
	game.books["needle"] = false
	game._sync_flags()
	game.read_book("needle")
	if game.has_book("needle"):
		push_error("Glass Needle opened without the Guard stamp")
		quit(1)
		return
	game.stamp("guard")
	game.read_book("needle")
	if not game.has_book("needle") or game.weapon != "needle":
		push_error("Glass Needle did not unlock after the stamp")
		quit(1)
		return
	var stayed: int = game.place
	game.travel(game.Place.GATE)
	if game.place != stayed:
		push_error("East Gate opened")
		quit(1)
		return
	game.travel(game.Place.WASTES)
	if game.place != game.Place.WASTES:
		push_error("Story closed the Wastes")
		quit(1)
		return
	main.start_hall(0)
	for _i in 6:
		await process_frame
	var hall := 0
	for node in get_nodes_in_group("hall"):
		if is_instance_valid(node):
			hall += 1
	if hall != 3:
		push_error("First Landing spawned %d" % hall)
		quit(1)
		return
	main.start_hall(2)
	for _i in 6:
		await process_frame
	hall = 0
	for node in get_nodes_in_group("hall"):
		if is_instance_valid(node):
			hall += 1
	if hall != 4:
		push_error("Outer Landing spawned %d" % hall)
		quit(1)
		return
	var music = root.get_node("Music")
	if music.school.stream == null or music.battle.stream == null:
		push_error("A theme failed to load")
		quit(1)
		return
	print("PLAN_OK")
	quit(0)
