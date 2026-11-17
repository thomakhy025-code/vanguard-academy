extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame
	var game = root.get_node("Game")
	var places: Array[int] = [1, 2, 3, 4, 5, 6, 7, 0]
	for id in places:
		game.travel(id)
		for _i in 4:
			await process_frame
		if game.place != id:
			push_error("Travel failed for %s" % game.place_name(id))
			quit(1)
			return
	var stayed: int = game.place
	game.travel(8)
	if game.place != stayed:
		push_error("East Gate should stay closed")
		quit(1)
		return
	main.start_court("even")
	for _i in 8:
		await process_frame
	main.start_hall()
	for _i in 8:
		await process_frame
	var hall := 0
	for node in get_nodes_in_group("hall"):
		if is_instance_valid(node):
			hall += 1
	if hall != 3:
		push_error("Hall course spawned %d constructs" % hall)
		quit(1)
		return
	var music = root.get_node("Music")
	if music.school.stream == null or music.battle.stream == null:
		push_error("A theme failed to load")
		quit(1)
		return
	var local_count := 0
	for node in get_nodes_in_group("player"):
		if node.get_meta("local", false):
			local_count += 1
	if local_count != 1:
		push_error("Expected one local student, found %d" % local_count)
		quit(1)
		return
	print("SMOKE_OK")
	quit(0)
