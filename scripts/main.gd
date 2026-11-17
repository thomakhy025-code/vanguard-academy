extends Node3D

const StudentScript := preload("res://scripts/student.gd")
const FoeScript := preload("res://scripts/foe.gd")

var stage: Node3D
var fx: Node3D
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D
var student
var hall_running := false
var hall_time := 0.0
var hall_token := 0
var stood_floor := -999
var cam_yaw := 0.0
var cam_pitch := 0.42
var trial_on := false
var trial_cursor := 0
var trial_need := 0
var trial_time := 0.0
var trial_pattern := 0
var trial_played := 0
var pattern_pick := {}
var trial_mode := ""
var guard_wait := 0.0
var guard_left := 0
var answer_ready := false
var gate_step := 0
var posts: Array = []

func _ready() -> void:
	_world()
	student = StudentScript.new()
	student.name = "LocalStudent"
	add_child(student)
	student.setup(camera, true)
	student.global_position = Vector3(0, 2.2, 8)
	_snap_camera()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var hud := Control.new()
	hud.set_script(load("res://scripts/hud.gd"))
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	Game.traveled.connect(rebuild)
	Online.peer_joined.connect(_on_peer_joined)
	Online.peer_left.connect(_on_peer_left)
	Online.multiplayer.connected_to_server.connect(_claim_local_authority)
	rebuild(Game.place)

func _world() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("85c1e0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff3dd")
	environment.ambient_light_energy = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color("d5eef8")
	environment.fog_density = 0.008
	environment.fog_aerial_perspective = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.light_color = Color("fff4e0")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 52
	camera.current = true
	add_child(camera)
	stage = Node3D.new()
	stage.name = "Stage"
	add_child(stage)
	fx = Node3D.new()
	fx.name = "FX"
	add_child(fx)
	var net := Node.new()
	net.name = "Net"
	net.set_script(load("res://scripts/net.gd"))
	add_child(net)

func _snap_camera() -> void:
	_follow_camera()

func _follow_camera() -> void:
	# The character stays in the middle. Moving does not turn this view. Only a drag on empty screen does.
	if student == null or camera == null:
		return
	var pivot: Vector3 = student.global_position + Vector3.UP * 1.2
	var flat := cos(cam_pitch) * 8.0
	var lift := sin(cam_pitch) * 8.0
	var behind := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
	camera.global_position = pivot + Vector3.UP * lift + behind * flat
	if camera.global_position.distance_squared_to(pivot) > 0.01:
		camera.look_at(pivot)

func _spark_wipe() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var veil := ColorRect.new()
	veil.color = Color("f4e3a8")
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(veil)
	var title := Label.new()
	title.text = Game.place_name(Game.place)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("2e4048"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title)
	var fade := create_tween()
	fade.tween_property(veil, "modulate:a", 0.0, 0.42)
	fade.parallel().tween_property(title, "modulate:a", 0.0, 0.42)
	fade.finished.connect(layer.queue_free)

func _process(delta: float) -> void:
	if hall_running:
		hall_time += delta
	if student:
		_follow_camera()
	if Game.place == Game.Place.YARD and student:
		var band := int(floor(student.global_position.y / 3.2 + 0.2))
		if band != stood_floor:
			stood_floor = band
			if student.has_method("_apply_ribbon"):
				student._apply_ribbon()
	if trial_on:
		trial_time += delta
		if trial_mode == "guard" or (trial_mode == "answer" and not answer_ready):
			_guard_arm(delta)
		elif trial_mode == "gates":
			_gate_pass()

func pan_camera(screen_delta: Vector2) -> void:
	# Dragging empty screen looks around the character. It does not happen because they walked.
	if camera == null or screen_delta == Vector2.ZERO:
		return
	cam_yaw -= screen_delta.x * 0.005
	cam_pitch = clampf(cam_pitch + screen_delta.y * 0.003, 0.2, 1.05)
	_follow_camera()

func rebuild(id: int) -> void:
	hall_running = false
	for child in stage.get_children():
		child.free()
	for child in fx.get_children():
		child.free()
	_tint(id)
	match id:
		Game.Place.YARD:
			_build_yard()
		Game.Place.OUTSIDE:
			_build_outside()
		Game.Place.GARDEN:
			_build_garden()
		Game.Place.UNDERCROFT:
			_build_undercroft()
		Game.Place.WASTES:
			_build_wastes()
		Game.Place.COURT:
			_build_court()
		Game.Place.HALL:
			_build_hall()
		Game.Place.CLASSROOM:
			_build_classroom()
		Game.Place.LIBRARY:
			_build_library()
		Game.Place.CUT, Game.Place.GUARD, Game.Place.STRENGTH, Game.Place.AGILITY, Game.Place.NEEDLE, Game.Place.ANSWER, Game.Place.SPARK, Game.Place.SPELLCUT, Game.Place.GUARDCAST, Game.Place.LANTERN, Game.Place.INK:
			_build_skill_room(id)
	trial_on = false
	trial_pattern = int(pattern_pick.get(Game.skill_for_place(id), 0))
	if student:
		if Game.use_arrive:
			student.global_position = Game.arrive
			Game.use_arrive = false
		elif id == Game.Place.YARD and Game.use_return:
			student.global_position = Game.yard_return
		else:
			student.global_position = Vector3(0, 2.4, 8)
		student.velocity = Vector3.ZERO
		stood_floor = int(floor(student.global_position.y / 3.2 + 0.2))
		_snap_camera()
		if student.has_method("_apply_ribbon"):
			student._apply_ribbon()
	_spark_wipe()

func snap_to_student() -> void:
	if student == null:
		return
	stood_floor = int(floor(student.global_position.y / 3.2 + 0.2))
	_snap_camera()
	if student.has_method("_apply_ribbon"):
		student._apply_ribbon()

func _tint(id: int) -> void:
	environment.background_color = Color("85c1e0")
	environment.ambient_light_color = Color("fff3dd")
	environment.ambient_light_energy = 0.72
	environment.fog_density = 0.008
	environment.fog_light_color = Color("d5eef8")
	if sun:
		sun.light_color = Color("fff4e0")
		sun.light_energy = 1.15
		sun.rotation_degrees = Vector3(-48, 32, 0)
	match id:
		Game.Place.UNDERCROFT:
			environment.background_color = Color("6f8ea3")
			environment.fog_density = 0.02
			environment.fog_light_color = Color("b7c9d4")
			environment.ambient_light_energy = 0.55
		Game.Place.WASTES:
			environment.background_color = Color("9ecfbe")
			environment.fog_light_color = Color("d5eef8")
			environment.fog_density = 0.012
			if sun:
				sun.light_color = Color("fff4e0")
				sun.light_energy = 0.95
				sun.rotation_degrees = Vector3(-42, 24, 0)
		Game.Place.COURT:
			environment.background_color = Color("85c1e0")
			environment.fog_density = 0.008
			environment.ambient_light_energy = 0.72
			if sun:
				sun.light_energy = 1.15
				sun.light_color = Color("fff4e0")
		Game.Place.HALL:
			environment.background_color = Color("cbbfa8")
			environment.fog_density = 0.01
		Game.Place.LIBRARY:
			environment.background_color = Color("e7d3a8")
			environment.ambient_light_color = Color("ffe6c4")
		Game.Place.CLASSROOM:
			environment.background_color = Color("d5eef8")

func _build_yard() -> void:
	_ground(Color("7ec48a"), 52.0)
	_path_cross()
	_cloister()
	var bell := _tower(Vector3(-8, 0, -2))
	_forge()
	_mark(Vector3(-4.8, 0.9, 0.55), "anvil", "to", 0)
	_crystal(Vector3(4.5, 0, -1))
	_spawn_foe(FoeScript.Kind.DUMMY, Vector3(2.2, 1, -3.2))
	_person(Vector3(-3.2, 0, 2), Color("8d5a3c"), "Captain Ross to the %s\nThe vote keeps sword and spell together." % Game.address())
	_person(Vector3(4.2, 0, 3.5), Color("3e5f86"), "Yard herald to the %s\n%s" % [Game.address(), Game.herald_line()])
	_ring_if_needed(bell)
	_build_towers()
	_school_doors()
	_school_gate()
	_east_gate(Vector3(22, 0, -8))

func _path_cross() -> void:
	for i in range(-8, 9):
		_box_at(Vector3(i * 1.6, 0.08, 0), Vector3(1.4, 0.08, 2.2), Color("cbbe9e"), 0.0, false)
		_box_at(Vector3(0, 0.08, i * 1.6), Vector3(2.2, 0.08, 1.4), Color("cbbe9e"), 0.0, false)

func _cloister() -> void:
	for x in [-24, 24]:
		_box_at(Vector3(x, 1.6, -4), Vector3(1.2, 3.2, 16), Color("efe6d4"), 0.0, true)
		_sphere(Vector3(x, 3.6, -4), 1.4, Color("c5764b"), 0.0, 0.45)
	_sign(Vector3(0, 3.2, 8), "Bell Court", 64)

func _build_towers() -> void:
	for i in Game.landing_count():
		var at: Vector3 = Game.landing_at(i)
		var skill := String(Game.LANDING_SKILLS[i])
		var room := Game._room_for_landing(i)
		_box_at(at + Vector3(0, -0.15, 0), Vector3(8.0, 0.3, 7.0), Color("efe6d4"), 0.0, true)
		_box_at(at + Vector3(0, 1.4, -3.2), Vector3(6.4, 2.4, 0.35), Color("efe6d4"), 0.0, true)
		var pane := _box_at(at + Vector3(0, 1.6, -3.0), Vector3(2.2, 1.1, 0.12), Game.tier_window(skill), 0.35, false)
		pane.material_override = _shiny(Game.tier_window(skill), 0.45)
		_sign(at + Vector3(0, 2.5, 1.2), Game.landing_name(i), 40)
		var inward := -1.0 if at.x > 0.0 else 1.0
		_portal(at + Vector3(inward * 1.6, 0, -2.2), Game.place_name(room), room, at)
		if i < 5 or (i >= 6 and i < 10):
			_tower_stair(at, Game.landing_at(i + 1), i == 0 or i == 6)
	_sphere(Game.landing_at(5) + Vector3(0, 3.2, 0), 2.2, Color("c5764b"), 0.0, 0.55)
	_sphere(Game.landing_at(10) + Vector3(0, 3.2, 0), 2.2, Color("e2c56a"), 0.15, 0.55)
	_portal(Game.landing_at(0) + Vector3(-3.0, 0, 0.4), "Classroom", Game.Place.CLASSROOM, Game.landing_at(0) + Vector3(-1.2, 0, 0))

func _school_doors() -> void:
	_portal(Vector3(0, 0, -14), "Library", Game.Place.LIBRARY, Vector3(0, 0.45, -11))
	_portal(Vector3(0, 0, 16), "Arena", Game.Place.COURT, Vector3(0, 0.45, 13))
	_portal(Vector3(-6, 0, 20), "School Forest", Game.Place.GARDEN, Vector3(-6, 0.45, 17))
	_portal(Vector3(6, 0, 20), "Deep Wood", Game.Place.WASTES, Vector3(6, 0.45, 17))
	_portal(Vector3(-10, 0, 12), "Proving Hall", Game.Place.HALL, Vector3(-10, 0.45, 9))
	_portal(Vector3(10, 0, 12), "Undercroft", Game.Place.UNDERCROFT, Vector3(10, 0.45, 9))
	_library_shell()
	_arena_shell()
	for i in 5:
		_tree(Vector3(-10 + i * 2.2, 0, 24), 2.4 + float(i % 2))

func _library_shell() -> void:
	var center := Vector3(0, 0, -20)
	for i in 14:
		var angle := TAU * float(i) / 14.0
		var pos := center + Vector3(sin(angle) * 5.2, 2.0, cos(angle) * 5.2)
		if pos.z > -16.5:
			continue
		_box_at(pos, Vector3(2.2, 4.0, 0.7), Color("efe6d4"), 0.0, true, angle)
		_box_at(pos + Vector3(0, 0.4, 0), Vector3(0.7, 0.9, 0.2), Color("e2c56a"), 0.35, false, angle)
	_cylinder_mesh(center + Vector3(0, 5.2, 0), 0.4, 5.4, 2.6, Color("c5764b"), 0.0)

func _arena_shell() -> void:
	_box_at(Vector3(-7, 1.3, 21), Vector3(6.0, 2.6, 2.4), Color("efe6d4"), 0.0, true)
	_box_at(Vector3(7, 1.3, 21), Vector3(6.0, 2.6, 2.4), Color("efe6d4"), 0.0, true)
	_box_at(Vector3(0, 2.6, 22.2), Vector3(8.0, 0.4, 2.4), Color("c5764b"), 0.0, true)

func _build_outside() -> void:
	_ground(Color("57af70"), 46.0)
	for i in range(-2, 10):
		_box_at(Vector3(0, 0.08, float(i) * 1.5), Vector3(2.6, 0.08, 1.35), Color("cbbe9e"), 0.0, false)
	_box_at(Vector3(-4.4, 2.3, -1.4), Vector3(5.4, 4.6, 1.5), Color("efe6d4"), 0.0, true)
	_box_at(Vector3(4.4, 2.3, -1.4), Vector3(5.4, 4.6, 1.5), Color("efe6d4"), 0.0, true)
	_box_at(Vector3(0, 4.8, -1.4), Vector3(3.4, 0.8, 1.5), Color("efe6d4"), 0.0, true)
	_cylinder_mesh(Vector3(0, 6.4, -1.4), 0.35, 6.8, 2.4, Color("c5764b"), 0.0)
	_box_at(Vector3(-1.7, 2.5, -0.55), Vector3(0.85, 1.15, 0.12), Color("e2c56a"), 0.4, false)
	_box_at(Vector3(1.7, 2.5, -0.55), Vector3(0.85, 1.15, 0.12), Color("e2c56a"), 0.4, false)
	_sign(Vector3(0, 3.6, 2.4), "School", 56)
	_prompt_door(Vector3(0, 0, 1.5), "Enter the school", Game.Place.YARD, Vector3(-16, 0.45, 16.5))
	for i in 8:
		var angle := TAU * float(i) / 8.0
		_tree(Vector3(sin(angle) * 16.0, 0, 10.0 + cos(angle) * 8.0), 3.1)

func _school_gate() -> void:
	_box_at(Vector3(-19.2, 1.8, 22), Vector3(1.2, 3.6, 5.4), Color("efe6d4"), 0.0, true)
	_box_at(Vector3(-12.8, 1.8, 22), Vector3(1.2, 3.6, 5.4), Color("efe6d4"), 0.0, true)
	_box_at(Vector3(-16, 3.7, 22), Vector3(6.4, 0.7, 5.4), Color("c5764b"), 0.0, true)
	_sign(Vector3(-16, 3.2, 18.6), "School door", 40)
	_prompt_door(Vector3(-16, 0, 18.8), "Leave the school", Game.Place.OUTSIDE, Vector3(0, 0.45, 4.4))

func _prompt_door(at: Vector3, button: String, place_id: int, arrive_at: Vector3) -> void:
	_box_at(at + Vector3(1.15, 1.35, 0), Vector3(0.4, 2.7, 0.4), Color("efe6d4"), 0.0, true)
	_box_at(at + Vector3(-1.15, 1.35, 0), Vector3(0.4, 2.7, 0.4), Color("efe6d4"), 0.0, true)
	_box_at(at + Vector3(0, 2.55, 0), Vector3(2.6, 0.35, 0.4), Color("e2c56a"), 0.2, true)
	var mark := Marker3D.new()
	mark.position = at
	mark.set_meta("prompt", true)
	mark.set_meta("label", button)
	mark.set_meta("to", place_id)
	mark.set_meta("arrive", arrive_at)
	mark.add_to_group("door")
	stage.add_child(mark)

func _portal(at: Vector3, label: String, place_id: int, back: Vector3) -> void:
	_box_at(at + Vector3(1.15, 1.35, 0), Vector3(0.4, 2.7, 0.4), Color("efe6d4"), 0.0, true)
	_box_at(at + Vector3(-1.15, 1.35, 0), Vector3(0.4, 2.7, 0.4), Color("efe6d4"), 0.0, true)
	_box_at(at + Vector3(0, 2.55, 0), Vector3(2.6, 0.35, 0.4), Color("c5764b"), 0.0, true)
	_sign(at + Vector3(0, 3.15, 0), label, 36)
	var mark := Marker3D.new()
	mark.position = at
	mark.set_meta("to", place_id)
	mark.set_meta("back", back)
	mark.add_to_group("door")
	stage.add_child(mark)

func _tower_stair(lower: Vector3, upper: Vector3, from_ground: bool) -> void:
	# A wide flight in front of the tower. It finishes level with the next floor, so the front edge is not a wall.
	var outward := 1.0 if lower.x > 0.0 else -1.0
	var foot := 0.0 if from_ground else lower.y
	var far_z := lower.z + 18.0
	var toe := Vector3(lower.x, foot, far_z)
	var lip := Vector3(lower.x, upper.y, lower.z + 4.4)
	var pad := Vector3(lower.x, upper.y, lower.z + 1.8)
	if not from_ground:
		var side_x := lower.x - outward * 6.8
		var deck_z := far_z + 2.2
		_flat_span(Vector3(lower.x - outward * 2.6, lower.y, lower.z + 2.2), Vector3(side_x, lower.y, lower.z + 5.2), 3.0)
		_flat_span(Vector3(side_x, lower.y, lower.z + 5.2), Vector3(side_x, lower.y, deck_z), 3.0)
		_flat_span(Vector3(side_x, lower.y, deck_z), Vector3(lower.x, lower.y, deck_z), 4.4)
	_ramp_between(toe, lip, 8.0)
	_ramp_between(lip, pad, 7.4)

func _flat_span(a: Vector3, b: Vector3, width: float) -> void:
	var delta := b - a
	var span := Vector2(delta.x, delta.z).length()
	if span < 0.2:
		return
	var yaw := atan2(delta.x, delta.z)
	_box_at((a + b) * 0.5 + Vector3(0, -0.16, 0), Vector3(width, 0.32, span), Color("cbbe9e"), 0.0, true, yaw)

func _ramp_between(a: Vector3, b: Vector3, width: float = 4.8) -> void:
	var delta := b - a
	var flat := Vector2(delta.x, delta.z).length()
	if flat < 0.2:
		return
	var yaw := atan2(delta.x, delta.z)
	var pitch := atan2(delta.y, flat)
	var basis := Basis.from_euler(Vector3(-pitch, yaw, 0.0))
	var thickness := 0.42
	var length := flat
	# The slab runs from a to b. Nothing hangs past the high end into the walker.
	var mid := b - basis.z * (length * 0.5) - basis.y * (thickness * 0.5)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = Transform3D(basis, mid)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, thickness, length)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = box.size
	mesh.mesh = slab
	mesh.material_override = _mat(Color("cbbe9e"), 0.0)
	body.add_child(mesh)
	var tread_count := int(flat / 0.62)
	for i in tread_count:
		var tread := MeshInstance3D.new()
		var tread_mesh := BoxMesh.new()
		tread_mesh.size = Vector3(width * 0.94, 0.045, 0.2)
		tread.mesh = tread_mesh
		var along := length * 0.5 - flat + (float(i) + 0.5) * flat / float(tread_count)
		tread.position = Vector3(0, thickness * 0.5 + 0.02, along)
		tread.material_override = _mat(Color("efe6d4"), 0.0)
		body.add_child(tread)
	stage.add_child(body)

func _tree(at: Vector3, height: float) -> void:
	_cylinder_mesh(at + Vector3(0, height * 0.35, 0), 0.18, 0.28, height * 0.7, Color("6b422c"), 0.0)
	_sphere(at + Vector3(0, height * 0.85, 0), height * 0.38, Color("3f9a62"), 0.0, 0.85)

func _build_skill_room(id: int) -> void:
	_ground(Color("efe6d4"), 28.0)
	_walls(12.0, Color("efe6d4"), 3.4)
	_sign(Vector3(0, 2.8, 2), Game.place_name(id), 52)
	_sign(Vector3(0, 2.1, 4.2), Game.place_blurb(id), 36)
	_portal(Vector3(0, 0, 13), "School", Game.Place.YARD, Game.door_back(id))
	if id == Game.Place.INK:
		_box_at(Vector3(0, 0.7, -4.2), Vector3(0.42, 1.35, 0.42), Color("2e4048"), 0.0, false)
		_sign(Vector3(0, 2.2, -2.2), "The dark post waits for Night Ink.", 32)
	elif id == Game.Place.LANTERN:
		_box_at(Vector3(-1.8, 0.7, -5.2), Vector3(0.42, 1.35, 0.42), Color("ffe08a"), 0.15, false)
		_box_at(Vector3(1.8, 0.7, -5.2), Vector3(0.42, 1.35, 0.42), Color("ffe08a"), 0.15, false)
		_sign(Vector3(0, 2.2, -2.2), "Wide lamps. The Lantern Saber opens them.", 32)
	_lamp(Vector3(0, 4.2, 0), Game.tier_window(Game.skill_for_place(id)), 1.2, 10.0)

func _build_garden() -> void:
	Game.begin_circuit()
	_ground(Color("57af70"), 58.0)
	_path(11.0)
	for i in 18:
		var angle := TAU * float(i) / 18.0
		var dist := 8.0 + float(i % 3) * 6.0
		_tree(Vector3(sin(angle) * dist, 0, cos(angle) * dist - 4.0), 2.6 + float(i % 2) * 0.8)
	for i in 8:
		var angle := TAU * float(i) / 8.0 + 0.35
		_circuit_post(i, Vector3(sin(angle) * 14.0, 0, cos(angle) * 14.0))
	for i in 6:
		var angle := TAU * float(i) / 6.0 + 1.2
		_pickup(Vector3(sin(angle) * 16.0, 0, cos(angle) * 16.0), "ore", 1, Color("e2c56a"), 0.35)
	_pickup(Vector3(-6, 0, -14), "shard", 1, Color("d7f1ff"), 0.55)
	_pickup(Vector3(7, 0, -15), "shard", 1, Color("d7f1ff"), 0.55)
	_sign(Vector3(0, 2.2, 4), "School Forest", 48)
	_portal(Vector3(0, 0, 13), "School", Game.Place.YARD, Game.door_back(Game.Place.GARDEN))
	_spawn_foe(FoeScript.Kind.BEAST, Vector3(-3, 1, -9))
	_spawn_foe(FoeScript.Kind.BEAST, Vector3(3.5, 1, -10))
	_spawn_foe(FoeScript.Kind.BEAST, Vector3(0, 1, -14))
	_spawn_foe(FoeScript.Kind.BEAST, Vector3(-6, 1, -13))

func _build_undercroft() -> void:
	_ground(Color("7d8b96"), 30.0)
	_walls(16.0, Color("8aa0ad"), 3.2)
	for i in 4:
		var x := -6.0 + i * 4.0
		_arch(Vector3(x, 0, -10))
		_lamp(Vector3(x, 2.8, -8.2), Color("ffd2a0"), 1.1, 5.0)
		_sphere(Vector3(x, 2.7, -8.4), 0.16, Color("ffd2a0"), 0.9, 1.0)
	_crack(Vector3(-2, 0.08, -4))
	_crack(Vector3(3, 0.08, -8))
	_crack(Vector3(0.5, 0.08, -2))
	for i in 4:
		var angle := PI + TAU * float(i) / 4.0
		_pickup(Vector3(sin(angle) * 8.0, 0, cos(angle) * 8.0), "ore", 2, Color("e2c56a"), 0.4)
		_pickup(Vector3(sin(angle + 0.4) * 6.0, 0, cos(angle + 0.4) * 6.0), "shard", 1, Color("d7f1ff"), 0.6)
	_spawn_foe(FoeScript.Kind.ELITE, Vector3(-5, 1, -7))
	_spawn_foe(FoeScript.Kind.ELITE, Vector3(5, 1, -7))
	_spawn_foe(FoeScript.Kind.ELITE, Vector3(0, 1, -12))
	_sign(Vector3(0, 2.4, -1), "Old vault", 42)
	_portal(Vector3(0, 0, 13), "School", Game.Place.YARD, Game.door_back(Game.Place.UNDERCROFT))

func _build_wastes() -> void:
	_ground(Color("3f9a62"), 90.0)
	for i in 16:
		var angle := TAU * float(i) / 16.0
		_tree(Vector3(sin(angle) * 20.0, 0, cos(angle) * 16.0 - 10.0), 4.2)
		_tree(Vector3(sin(angle + 0.2) * 32.0, 0, cos(angle) * 24.0 - 8.0), 5.4)
	_stone_ring(14.0, 18, Color("efe6d4"))
	_stone_ring(24.0, 24, Color("e2c56a"))
	_stone_ring(36.0, 28, Color("c5764b"))
	_sign(Vector3(0, 1.8, -12), "Inner ring", 48)
	_sign(Vector3(0, 1.8, -22), "Rank 3 ring", 48)
	_sign(Vector3(0, 2.0, -34), "Rank 6 ring", 48)
	_shrine(Vector3(-16, 0, -18))
	_shrine(Vector3(18, 0, -28))
	_shrine(Vector3(-6, 0, -34))
	_camp(Vector3(9, 0, -10), FoeScript.Kind.BEAST, 3, 1.0)
	_camp(Vector3(-14, 0, -20), FoeScript.Kind.ELITE, 2, 1.25)
	_camp(Vector3(12, 0, -32), FoeScript.Kind.ELITE, 2, 1.6)
	_spawn_foe(FoeScript.Kind.BOSS, Vector3(0, 1, -18), 1.0)
	for blob in [Vector3(-20, 0.2, -8), Vector3(22, 0.2, -14), Vector3(-18, 0.2, -30), Vector3(8, 0.2, 6)]:
		_tree(blob, 4.8)
	_portal(Vector3(0, 0, 13), "School", Game.Place.YARD, Game.door_back(Game.Place.WASTES))

func _build_court() -> void:
	_ground(Color("57af70"), 36.0)
	_walls(14.0, Color("efe6d4"), 2.6)
	_tiles(2, 2.4, Color("cbbe9e"))
	_duel_ring(Vector3(-5, 0, 0), Color("d5dbe0"), 4.2, "even", "Even")
	_duel_ring(Vector3(5, 0, 0), Color("e2c56a"), 4.2, "open", "Open")
	var gem := _sphere(Vector3(0, 5.4, -1), 0.55, Color("d7f1ff"), 1.1, 1.2)
	gem.material_override = _shiny(Color("d7f1ff"), 1.2)
	_lamp(Vector3(0, 5.2, -1), Color("fff6dd"), 1.6, 10.0)
	for i in 8:
		var angle := PI * 0.45 + PI * 1.1 * float(i) / 7.0
		var pos := Vector3(sin(angle) * 11.0, 0, cos(angle) * 11.0)
		var cloth := Color("3e5f86") if i % 2 == 0 else Color("8d5a3c")
		_person(pos, cloth, "")
	_sign(Vector3(0, 2.6, 3.5), "Choose a ring", 48)
	for spot in [Vector3(-11, 0.4, 2), Vector3(11, 0.4, 2), Vector3(-11, 0.4, -7), Vector3(11, 0.4, -7)]:
		_box_at(spot, Vector3(2.6, 0.8, 6.5), Color("efe6d4"), 0.0, true)
	_portal(Vector3(0, 0, 13), "School", Game.Place.YARD, Game.door_back(Game.Place.COURT))

func _build_hall() -> void:
	_ground(Color("b7aa96"), 34.0)
	_walls(15.0, Color("efe6d4"), 4.2)
	_stair()
	_shaft(Vector3(0, 6.2, -5))
	_course_plaque(Vector3(5.2, 1.3, -3.2), 0)
	_course_plaque(Vector3(5.2, 1.7, -6.4), 1)
	_course_plaque(Vector3(5.2, 2.1, -9.6), 2)
	_sign(Vector3(0, 3.4, -2), "Crest\n%s" % Game.rival_line("hall", Game.hall_course), 40)
	_portal(Vector3(0, 0, 13), "School", Game.Place.YARD, Game.door_back(Game.Place.HALL))

func _build_classroom() -> void:
	_ground(Color("f0e2c4"), 32.0)
	_walls(14.0, Color("efe6d4"), 3.6)
	_window(Vector3(-6, 2.0, -12.5))
	_window(Vector3(0, 2.0, -12.5))
	_window(Vector3(6, 2.0, -12.5))
	_lesson_board(Vector3(0, 1.8, -11.2))
	_desk(Vector3(-3.4, 0, -2.5), "Soldier desk", "soldier")
	_desk(Vector3(3.4, 0, -2.5), "Caster desk", "caster")
	for row in 3:
		for seat in 4:
			_box_at(Vector3(-3.6 + seat * 2.4, 0.45, 1.5 + row * 1.6), Vector3(1.1, 0.7, 0.6), Color("8d5a3c"), 0.0, true)
	_person(Vector3(-5.5, 0, -7), Color("4d6a8a"), "Professor Hen to the %s\nBoth desks. Both arts." % Game.address())
	_portal(Vector3(0, 0, 13), "School", Game.Place.YARD, Game.door_back(Game.Place.CLASSROOM))

func _build_library() -> void:
	_ground(Color("c8b48a"), 34.0)
	_walls(15.0, Color("6b422c"), 4.6)
	for i in 10:
		var angle := TAU * float(i) / 10.0
		var pos := Vector3(sin(angle) * 8.0, 0, cos(angle) * 8.0 - 1.0)
		_box_at(pos + Vector3(0, 1.5, 0), Vector3(2.2, 3.0, 0.55), Color("6b422c"), 0.0, true, angle)
		for book in 6:
			var spine := Color("c5764b")
			if book % 3 == 1:
				spine = Color("e2c56a")
			elif book % 3 == 2:
				spine = Color("2e4048")
			_box_at(pos + Vector3(0, 0.45 + book * 0.38, 0.32), Vector3(0.22, 0.32, 0.12), spine, 0.0, false, angle)
		_lamp(pos + Vector3(0, 2.4, 0), Color("ffd2a0"), 0.45, 3.0)
	for i in 12:
		var angle := TAU * float(i) / 12.0 + 0.2
		var pos := Vector3(sin(angle) * 5.4, 3.3, cos(angle) * 5.4 - 1.0)
		_box_at(pos, Vector3(1.4, 1.6, 0.4), Color("6b422c"), 0.0, true, angle)
		for book in 4:
			var spine := Color("efe6d4") if book % 2 == 0 else Color("c5764b")
			_box_at(pos + Vector3(0, -0.45 + book * 0.28, 0.24), Vector3(0.16, 0.24, 0.08), spine, 0.0, false, angle)
	_box_at(Vector3(0, 2.8, -1), Vector3(7.0, 0.2, 7.0), Color("8d5a3c"), 0.0, true)
	_box_at(Vector3(0, 0.7, -4.2), Vector3(2.8, 0.9, 1.3), Color("8d5a3c"), 0.0, true)
	_person(Vector3(2.4, 0, -3.2), Color("6b422c"), "Archivist Quill to the %s\nA book opens after its stamp." % Game.address())
	var titles := ["Sparrow", "Needle", "Hammer", "Lantern", "Answer", "Night Ink"]
	var ids := ["sparrow", "needle", "hammer", "lantern", "answer", "ink"]
	for i in ids.size():
		_tome(Vector3(-4.2 + i * 1.7, 1.15, -8.6), ids[i], titles[i])
	_portal(Vector3(0, 0, 13), "School", Game.Place.YARD, Game.door_back(Game.Place.LIBRARY))

func start_court(mode: String) -> void:
	if Online.active:
		Game.toast.emit("Leave the online court before a practice match.")
		return
	Game.court_mode = mode
	Game.travel(Game.Place.COURT)
	if Game.place != Game.Place.COURT:
		return
	Game.court_live = true
	Game.changed.emit()
	_spawn_foe(FoeScript.Kind.DUELIST, Vector3(0, 1, -4))

func start_hall(course: int = 0) -> void:
	course = clampi(course, 0, 2)
	Game.travel(Game.Place.HALL)
	if Game.place != Game.Place.HALL:
		return
	Game.hall_course = course
	Game.note_attempt(course)
	var counts: Array[int] = [3, 3, 4]
	var count: int = counts[course]
	for i in count:
		var x := 0.0
		if count > 1:
			x = lerpf(-6.0, 6.0, float(i) / float(count - 1))
		var foe = _spawn_foe(FoeScript.Kind.CONSTRUCT, Vector3(x, 1, -6.5))
		foe.died.connect(_on_construct_died)
	hall_token += 1
	hall_time = 0.0
	hall_running = true
	Game.toast.emit("%s. Clear every construct. Only a faster run replaces the best." % Game.HALL_TITLES[course])

func host_match(mode: String) -> void:
	Game.court_mode = mode
	if not Online.host(mode):
		return
	_rename_local()
	Game.travel(Game.Place.COURT)
	if Game.place != Game.Place.COURT:
		return
	Game.court_live = true
	Game.changed.emit()
	Game.toast.emit("Waiting at the court. IP: %s  port %d. If Windows Firewall asks, allow it." % [Online.local_ips(), Online.PORT])

func join_match(ip: String, mode: String) -> void:
	Game.court_mode = mode
	if Online.join_ip(ip, mode):
		_rename_local()

func _rename_local() -> void:
	if student == null or not Online.active:
		return
	var id := multiplayer.get_unique_id()
	if id <= 0:
		return
	student.name = "Peer%d" % id
	student.set_multiplayer_authority(id)

func leave_online() -> void:
	_clear_remotes()
	Online.stop()
	Game.court_live = false
	Game.changed.emit()
	Game.toast.emit("You left the online court.")

func _on_peer_joined(id: int) -> void:
	if id <= 0 or id == multiplayer.get_unique_id():
		return
	if student and student.name == "Peer%d" % id:
		return
	if _find_player(id):
		return
	var ghost = StudentScript.new()
	ghost.name = "Peer%d" % id
	add_child(ghost)
	ghost.set_multiplayer_authority(id)
	ghost.setup(camera, false)
	ghost.global_position = Vector3(-2.2, 2.2, 4)

func _on_peer_left(id: int) -> void:
	var node := _find_player(id)
	if node:
		node.queue_free()

func _claim_local_authority() -> void:
	_rename_local()

func _find_player(id: int) -> Node:
	return get_node_or_null("Peer%d" % id)

func _clear_remotes() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if not node.get_meta("local", false):
			node.queue_free()

func _on_construct_died(_foe) -> void:
	if not hall_running:
		return
	for node in get_tree().get_nodes_in_group("hall"):
		if is_instance_valid(node) and node.alive:
			return
	hall_running = false
	Game.note_hall(hall_time)

func _spawn_foe(kind: FoeScript.Kind, at: Vector3, tough := 1.0):
	var foe = FoeScript.new()
	stage.add_child(foe)
	foe.setup(kind, at, tough)
	foe.died.connect(_on_foe_died)
	return foe

func _on_foe_died(foe) -> void:
	if foe.kind == FoeScript.Kind.DUELIST:
		Game.note_court(Game.court_mode == "open")
		return
	if foe.kind == FoeScript.Kind.DUMMY or foe.kind == FoeScript.Kind.CONSTRUCT:
		return
	var ore_n := 2
	var shard_n := 0
	match foe.kind:
		FoeScript.Kind.SPIRIT:
			ore_n = 1
		FoeScript.Kind.BEAST:
			ore_n = 2
		FoeScript.Kind.ELITE:
			ore_n = 4
			shard_n = 1
		FoeScript.Kind.BOSS:
			ore_n = 8
			shard_n = 3
	Game.grant_loot(ore_n, shard_n)
	_respawn(foe.kind, foe.home, Game.place, foe.tough)

func _respawn(kind, at: Vector3, here: int, tough: float) -> void:
	await get_tree().create_timer(5.0).timeout
	if Game.place != here:
		return
	_spawn_foe(kind, at, tough)

func _ring_if_needed(bell: MeshInstance3D) -> void:
	if not Game.bell_pending or bell == null:
		return
	Game.bell_pending = false
	Game.bell_rung_once = true
	Game.toast.emit("The bell rings for the %s." % Game.address())
	Game.changed.emit()
	Game._save()
	var tw := create_tween()
	tw.tween_property(bell, "scale", Vector3(1.45, 1.45, 1.45), 0.16)
	tw.tween_property(bell, "scale", Vector3.ONE, 0.24)
	bell.tree_exiting.connect(tw.kill)

func _ground(color: Color, radius: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 1.2
	shape.shape = cylinder
	shape.position = Vector3(0, -0.6, 0)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 1.2
	mesh.mesh = disc
	mesh.position = shape.position
	mesh.material_override = _mat(color, 0.0)
	body.add_child(mesh)
	stage.add_child(body)

func _tiles(half: int, cell: float, color: Color) -> void:
	for x in range(-half, half + 1):
		for z in range(-half, half + 1):
			_box_at(Vector3(x * cell, 0.06, z * cell), Vector3(cell * 0.9, 0.1, cell * 0.9), color, 0.0, false)

func _lawn(at: Vector3) -> void:
	_sphere(at, 2.6, Color("57af70"), 0.0, 0.22)

func _walls(radius: float, color: Color, height: float) -> void:
	var count := 12
	for i in count:
		var angle := TAU * float(i) / float(count)
		if absf(angle) < 0.62 or absf(angle - TAU) < 0.62:
			continue
		var pos := Vector3(sin(angle) * radius, height * 0.5, cos(angle) * radius)
		_box_at(pos, Vector3(radius * 0.62, height, 0.7), color, 0.0, true, angle)

func _box_at(at: Vector3, box_size: Vector3, color: Color, glow: float = 0.0, solid: bool = false, yaw: float = 0.0) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = box_size
	var inst := MeshInstance3D.new()
	inst.mesh = box
	inst.material_override = _mat(color, glow)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = at
		body.rotation.y = yaw
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size
		shape_node.shape = shape
		body.add_child(shape_node)
		body.add_child(inst)
		stage.add_child(body)
	else:
		inst.position = at
		inst.rotation.y = yaw
		stage.add_child(inst)
	return inst

func _sphere(at: Vector3, radius: float, color: Color, glow: float, squash: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 * squash
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.material_override = _shiny(color, glow) if glow > 0.25 else _mat(color, glow)
	stage.add_child(inst)
	return inst

func _cylinder_mesh(at: Vector3, top: float, bottom: float, height: float, color: Color, glow: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.material_override = _shiny(color, glow)
	stage.add_child(inst)
	return inst

func _house(at: Vector3) -> void:
	_box_at(at + Vector3(0, 1.15, 0), Vector3(3.4, 2.3, 2.8), Color("efe6d4"), 0.0, true)
	_sphere(at + Vector3(0, 2.55, 0), 1.8, Color("c5764b"), 0.0, 0.62)
	_box_at(at + Vector3(0, 0.9, 1.45), Vector3(0.7, 1.2, 0.16), Color("2e4048"), 0.0, false)

func _banner(at: Vector3, color: Color) -> void:
	_box_at(at + Vector3(0, 1.7, 0), Vector3(0.12, 3.4, 0.12), Color("2e4048"), 0.0, false)
	_box_at(at + Vector3(0.5, 2.7, 0), Vector3(1.0, 0.7, 0.08), color, 0.0, false)

func _tower(at: Vector3) -> MeshInstance3D:
	_box_at(at + Vector3(0, 3.2, 0), Vector3(2.4, 6.4, 2.4), Color("efe6d4"), 0.0, true)
	_sphere(at + Vector3(0, 6.9, 0), 1.55, Color("c5764b"), 0.0, 0.85)
	var bell := _cylinder_mesh(at + Vector3(0, 4.6, 1.3), 0.28, 0.36, 0.5, Color("f0d78c"), 0.55)
	_sign(at + Vector3(0, 5.6, 1.6), Game.bell_caption(), 36)
	return bell

func _forge() -> void:
	_box_at(Vector3(-7.2, 0.85, -1.2), Vector3(3.0, 1.7, 1.7), Color("4a4038"), 0.0, true)
	_box_at(Vector3(-7.2, 2.0, -1.2), Vector3(1.3, 0.9, 1.3), Color("3a332c"), 0.0, false)
	_sphere(Vector3(-7.2, 2.7, -1.2), 0.48, Color("2e4048"), 0.0, 1.0)
	var mouth := _box_at(Vector3(-7.2, 0.95, -0.25), Vector3(1.3, 0.75, 0.28), Color("ffb15a"), 0.0, false)
	mouth.material_override = _shiny(Color("ffb15a"), 2.2)
	_lamp(Vector3(-7.2, 1.5, 0.2), Color("ffb15a"), 2.0, 8.0)
	_box_at(Vector3(-4.8, 0.5, 0.2), Vector3(1.1, 0.7, 0.7), Color("5c5148"), 0.0, true)
	_box_at(Vector3(-7.2, 0.55, 2.0), Vector3(3.4, 0.8, 0.4), Color("cbbe9e"), 0.0, true)
	for i in 4:
		_cylinder_mesh(Vector3(-8.4 + i * 0.75, 1.35, 2.0), 0.045, 0.07, 1.15, Color("e2c56a"), 0.4)
	_mark(Vector3(-5.4, 0, 1.5), "forge", "to", 0)
	_sign(Vector3(-5.6, 2.2, 1.5), "Forge bench", 40)

func _crystal(at: Vector3) -> void:
	_box_at(at + Vector3(0, 0.5, 0), Vector3(1.3, 1.0, 1.3), Color("cbbe9e"), 0.0, true)
	var gem := _sphere(at + Vector3(0, 1.75, 0), 0.55, Color("d7f1ff"), 0.2, 1.25)
	gem.material_override = _shiny(Color("d7f1ff"), 1.3)
	_lamp(at + Vector3(0, 2.2, 0), Color("d7f1ff"), 1.4, 6.0)
	_sign(at + Vector3(0, 2.9, 0), Game.exhibit_line(), 36)

func _door(at: Vector3, label: String, place_id: int) -> void:
	_box_at(at + Vector3(1.6, 1.5, 0), Vector3(0.55, 3.0, 0.55), Color("efe6d4"), 0.0, true)
	_box_at(at + Vector3(-1.6, 1.5, 0), Vector3(0.55, 3.0, 0.55), Color("efe6d4"), 0.0, true)
	_sphere(at + Vector3(0, 3.2, 0), 1.15, Color("c5764b"), 0.0, 0.55)
	_sign(at + Vector3(0, 2.2, 0), label, 40)
	_mark(at, "door", "to", place_id)

func _east_gate(at: Vector3) -> void:
	_box_at(at + Vector3(0, 1.8, 0), Vector3(0.4, 3.6, 0.4), Color("2e4048"), 0.0, true)
	_box_at(at + Vector3(2.4, 1.8, 0), Vector3(0.4, 3.6, 0.4), Color("2e4048"), 0.0, true)
	_box_at(at + Vector3(1.2, 3.45, 0), Vector3(2.8, 0.4, 0.45), Color("2e4048"), 0.0, true)
	for i in 4:
		_box_at(at + Vector3(0.45 + i * 0.5, 1.7, 0), Vector3(0.14, 2.8, 0.16), Color("3a4a52"), 0.0, true)
	_sphere(at + Vector3(2.8, 2.7, 0.35), 0.2, Color("f0d78c"), 0.2, 1.0)
	_lamp(at + Vector3(2.8, 2.7, 0.35), Color("f0d78c"), 1.3, 5.5)
	_cloud(at + Vector3(1.2, 1.3, -1.6))
	_cloud(at + Vector3(2.2, 1.6, -2.2))
	_sign(at + Vector3(-0.4, 2.4, 0.4), "East Gate is closed today.", 36)
	_mark(at + Vector3(-2.4, 0, 0), "door", "to", Game.Place.GATE)

func _arch(at: Vector3) -> void:
	_box_at(at + Vector3(-0.9, 1.4, 0), Vector3(0.5, 2.8, 0.5), Color("d9d3c7"), 0.0, true)
	_box_at(at + Vector3(0.9, 1.4, 0), Vector3(0.5, 2.8, 0.5), Color("d9d3c7"), 0.0, true)
	_sphere(at + Vector3(0, 2.9, 0), 1.05, Color("d9d3c7"), 0.0, 0.6)

func _crack(at: Vector3) -> void:
	_box_at(at, Vector3(1.5, 0.05, 0.16), Color("e2c56a"), 0.85, false)

func _shrine(at: Vector3) -> void:
	_box_at(at + Vector3(0, 0.4, 0), Vector3(2.4, 0.8, 2.2), Color("cbbe9e"), 0.0, true)
	_box_at(at + Vector3(-0.55, 1.6, 0), Vector3(0.42, 2.3, 0.42), Color("efe6d4"), 0.0, false)
	_box_at(at + Vector3(0.55, 1.05, 0), Vector3(0.42, 1.3, 0.42), Color("efe6d4"), 0.0, false)
	_sphere(at + Vector3(0, 0.95, 0.8), 0.28, Color("e2c56a"), 0.7, 1.0)

func _camp(at: Vector3, kind, count: int, tough: float) -> void:
	_sphere(at + Vector3(0, 0.85, 0), 1.35, Color("c5764b"), 0.0, 0.55)
	_box_at(at + Vector3(0, 0.25, 0), Vector3(2.6, 0.35, 2.6), Color("cbbe9e"), 0.0, false)
	_banner(at + Vector3(1.8, 0, 0), Color("e2c56a"))
	for i in count:
		var angle := TAU * float(i) / float(count)
		_spawn_foe(kind, at + Vector3(sin(angle) * 2.6, 1.0, cos(angle) * 2.6), tough)

func _stone_ring(radius: float, count: int, color: Color) -> void:
	for i in count:
		var angle := TAU * float(i) / float(count)
		_sphere(Vector3(sin(angle) * radius, 0.18, cos(angle) * radius), 0.32, color, 0.0, 0.45)

func _path(radius: float) -> void:
	for i in 18:
		var angle := TAU * float(i) / 18.0
		_box_at(Vector3(sin(angle) * radius, 0.07, cos(angle) * radius), Vector3(1.35, 0.1, 1.35), Color("efe6d4"), 0.0, false)

func _duel_ring(at: Vector3, color: Color, radius: float, mode: String, label: String) -> void:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.28
	mesh.mesh = torus
	mesh.position = at + Vector3(0, 0.08, 0)
	mesh.material_override = _shiny(color, 0.3)
	stage.add_child(mesh)
	_sign(at + Vector3(0, 1.5, 0), label, 52)
	_mark(at, "duel", "mode", mode)

func _stair() -> void:
	for i in 6:
		_box_at(Vector3(0, 0.28 + i * 0.18, -1.5 - i * 1.35), Vector3(6.2 - i * 0.3, 0.36, 1.25), Color("efe6d4"), 0.0, true)

func _shaft(at: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 1.5
	mesh.height = 8.0
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	var material := _mat(Color("fff6dd"), 0.45, 0.22)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = material
	stage.add_child(inst)
	_lamp(at, Color("fff6dd"), 1.5, 12.0)

func _course_plaque(at: Vector3, course: int) -> void:
	_box_at(at, Vector3(2.0, 1.2, 0.2), Color("2e4048"), 0.0, false)
	_box_at(at + Vector3(0, 0, 0.1), Vector3(1.55, 0.82, 0.08), Color("f0d78c"), 0.75, false)
	_sign(at + Vector3(0, 1.15, 0.2), "%s\n%s" % [Game.HALL_TITLES[course], Game.hall_line(course)], 28)
	_mark(at + Vector3(0, 0, 1.2), "course", "course", course)

func _window(at: Vector3) -> void:
	_box_at(at, Vector3(1.6, 1.2, 0.1), Color("d7f1ff"), 0.35, false)

func _lesson_board(at: Vector3) -> void:
	_box_at(at, Vector3(4.8, 2.5, 0.2), Color("24343b"), 0.0, true)
	_box_at(at + Vector3(-0.9, 0.05, 0.18), Vector3(0.12, 1.0, 0.06), Color("f4efe4"), 0.2, false)
	_sphere(at + Vector3(0.9, 0.05, 0.24), 0.32, Color("9fd6ff"), 0.8, 1.0)
	_sign(at + Vector3(0, 1.55, 0.2), "Cut  +  Spark", 48)

func _desk(at: Vector3, label: String, bias: String) -> void:
	_box_at(at + Vector3(0, 0.72, 0), Vector3(2.4, 0.28, 1.15), Color("8d5a3c"), 0.0, true)
	_box_at(at + Vector3(0, 0.34, 0), Vector3(0.28, 0.68, 0.7), Color("6b422c"), 0.0, true)
	_sign(at + Vector3(0, 1.4, 0), label, 40)
	_mark(at + Vector3(0, 0, 1.35), "desk", "bias", bias)

func _tome(at: Vector3, id: String, title: String) -> void:
	var open := Game.book_ready(id)
	var color := Color("f0d78c") if open else Color("6b422c")
	var glow := 1.15 if open else 0.0
	_box_at(at, Vector3(0.46, 0.72, 0.18), color, glow, false)
	_sign(at + Vector3(0, 0.75, 0), title, 28)
	_mark(at, "book", "book", id)
	if open:
		_lamp(at + Vector3(0, 0.4, 0.5), Color("f0d78c"), 0.7, 2.6)

func _circuit_post(index: int, at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	root.set_meta("index", index)
	root.add_to_group("circuit")
	stage.add_child(root)
	var pole := BoxMesh.new()
	pole.size = Vector3(0.16, 0.7, 0.16)
	var post := MeshInstance3D.new()
	post.mesh = pole
	post.position = Vector3(0, 0.35, 0)
	post.material_override = _mat(Color("efe6d4"), 0.0)
	root.add_child(post)
	var gem := SphereMesh.new()
	gem.radius = 0.26
	gem.height = 0.46
	var inst := MeshInstance3D.new()
	inst.mesh = gem
	inst.position = Vector3(0, 0.78, 0)
	inst.material_override = _shiny(Color("e2c56a"), 0.7)
	root.add_child(inst)

func _pickup(at: Vector3, group: String, amount: int, color: Color, glow: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.42
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at + Vector3(0, 0.28, 0)
	inst.material_override = _shiny(color, glow)
	inst.add_to_group(group)
	inst.set_meta("amount", amount)
	stage.add_child(inst)

func _person(at: Vector3, tunic: Color, lines: String) -> void:
	_sphere(at + Vector3(0, 0.4, 0), 0.34, tunic, 0.0, 1.0)
	var body := CapsuleMesh.new()
	body.radius = 0.28
	body.height = 0.72
	var inst := MeshInstance3D.new()
	inst.mesh = body
	inst.position = at + Vector3(0, 0.92, 0)
	inst.material_override = _mat(tunic, 0.0)
	stage.add_child(inst)
	_sphere(at + Vector3(0, 1.42, 0), 0.28, Color("f0c7a4"), 0.0, 1.0)
	_sphere(at + Vector3(0, 1.6, 0), 0.2, Color("2e4048"), 0.0, 0.7)
	if lines != "":
		_sign(at + Vector3(0, 2.2, 0), lines, 36)

func _sign(at: Vector3, text: String, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("2e4048")
	label.outline_modulate = Color("f7f1e4")
	label.outline_size = 8
	label.no_depth_test = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(label)

func _mark(at: Vector3, group: String, key: String, value) -> void:
	var mark := Marker3D.new()
	mark.position = at
	mark.set_meta(key, value)
	mark.add_to_group(group)
	stage.add_child(mark)

func _lamp(at: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	stage.add_child(light)

func _cloud(at: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.95
	mesh.height = 1.4
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.material_override = _mat(Color("9ec3d6"), 0.25, 0.38)
	stage.add_child(inst)

func _mat(color: Color, glow: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var tint := color
	if alpha < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.a = alpha
	material.albedo_color = tint
	material.roughness = 0.84
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

func _shiny(color: Color, glow: float) -> StandardMaterial3D:
	var material := _mat(color, glow)
	material.metallic = 0.62
	material.roughness = 0.32
	return material

func begin_shown_trial() -> void:
	var id := int(Game.place)
	if not Game.trial_allowed(id, trial_pattern):
		Game.toast.emit(Game.trial_block(id, trial_pattern))
		pattern_pick[Game.skill_for_place(id)] = (trial_pattern + 1) % 3
		trial_pattern = int(pattern_pick[Game.skill_for_place(id)])
		return
	_clear_marks()
	trial_on = true
	trial_time = 0.0
	trial_cursor = 0
	guard_left = 0
	guard_wait = 0.6
	answer_ready = false
	gate_step = 0
	var played := trial_pattern
	trial_played = played
	var skill := Game.skill_for_place(id)
	match skill:
		"guard":
			trial_mode = "guard"
			trial_need = 6
			guard_left = 6
		"agility":
			trial_mode = "gates"
			var gates := 4
			if played > 0:
				gates = 6
			trial_need = gates + (1 if played >= 2 else 0)
			_lay_gates(gates, played >= 2)
		"guardcast":
			trial_mode = "posts"
			trial_need = 6
			_lay_ring(6, 1.7 if played == 1 else 2.15)
		"spellcut":
			trial_mode = "posts"
			trial_need = 1 if trial_pattern == 0 else 3
			_lay_line(trial_need, 2.4, Color("f0d78c"))
		"ink":
			trial_mode = "posts"
			trial_need = 2
			_stance(-1.05, 1.05, 6.5)
			_spawn_post(0, Vector3(0, 0, -2.75), Color("8aa0ad"))
			_spawn_post(1, Vector3(0, 0, -3.25 - float(played) * 0.08), Color("2e4048"))
		"needle":
			trial_mode = "posts"
			trial_need = 1 if played == 0 else 3
			_stance(-1.2, 1.05, 7.0)
			_spawn_post(0, Vector3(0, 0, -2.7), Color("d5f0ff"))
			if played > 0:
				_spawn_post(1, Vector3(-0.12, 0, -3.75), Color("d5f0ff"))
				_spawn_post(2, Vector3(0.12, 0, -3.75), Color("d5f0ff"))
		"strength":
			trial_mode = "posts"
			trial_need = 3
			if played >= 2:
				_stance(-0.5, 0.72, 6.2)
				_spawn_post(0, Vector3(0, 0, -1.9), Color("c5764b"))
				_spawn_post(1, Vector3(-1.55, 0, -0.15), Color("c5764b"))
				_spawn_post(2, Vector3(1.55, 0, -0.15), Color("c5764b"))
			else:
				_lay_line(3, 1.8, Color("c5764b"))
		"answer":
			trial_mode = "answer"
			trial_need = 1 if played == 0 else 2
			guard_left = 1
			_spawn_post(0, Vector3(0, 0, -2.5), Color("e2c56a"))
			if played > 0:
				_stance(-1.15, 1.05, 6.5)
				_spawn_post(1, Vector3(0, 0, -3.45), Color("c5764b"))
		"lantern":
			trial_mode = "posts"
			trial_need = 2 if played < 2 else 3
			_spawn_post(0, Vector3(-1.55, 0, -6.0), Color("ffe08a"))
			_spawn_post(1, Vector3(1.55, 0, -6.0), Color("ffe08a"))
			if trial_need > 2:
				_spawn_post(2, Vector3(0, 0, -6.4), Color("ffe08a"))
		"spark":
			trial_mode = "posts"
			trial_need = 8 if played >= 2 else 5
			for i in trial_need:
				var side := 0.0 if played == 0 else (-1.0 if i % 2 == 0 else 1.0)
				_spawn_post(i, Vector3((float(i) - float(trial_need) * 0.5) * 2.4, 0, -5.0 + side * 0.8), Color("8ec8f0"))
		_:
			trial_mode = "posts"
			trial_need = 8
			for i in trial_need:
				var spread := 0.55 + float(trial_pattern) * 0.25
				_spawn_post(i, Vector3(sin(float(i) * 0.7) * spread * float(i), 0, -3.2 - float(i % 3) * 0.4), Color("e2c56a"))
	_light_cursor()
	Game.toast.emit("%s. The gold mark is the one that counts." % Game.pattern_label(id, played))
	pattern_pick[Game.skill_for_place(id)] = (played + 1) % 3
	trial_pattern = int(pattern_pick[Game.skill_for_place(id)])

func _lay_line(count: int, gap: float, color: Color) -> void:
	var start := -gap * float(count - 1) * 0.5
	for i in count:
		_spawn_post(i, Vector3(start + float(i) * gap, 0, -4.0), color)

func _lay_ring(count: int, radius: float) -> void:
	for i in count:
		var angle := TAU * float(i) / float(count)
		_spawn_post(i, Vector3(sin(angle) * radius, 0, cos(angle) * radius), Color("f4e3a8"))

func _lay_gates(count: int, sparrow: bool) -> void:
	for i in count:
		var gate := Marker3D.new()
		gate.position = Vector3(-4.0 + float(i) * 1.8, 0, -2.0 - float(i % 2) * 0.6)
		gate.set_meta("order", i)
		gate.add_to_group("gate")
		stage.add_child(gate)
		_cylinder_mesh(gate.position + Vector3(0, 1.2, 0), 0.62, 0.62, 0.16, Color("57af70"), 0.2)
		_rail(gate.position + Vector3(-0.85, 0, 0))
		_rail(gate.position + Vector3(0.85, 0, 0))
	if sparrow:
		_spawn_post(count, Vector3(-4.0 + float(count - 1) * 1.8, 0, -3.5), Color("e2c56a"))

func _rail(at: Vector3) -> void:
	var mark := Marker3D.new()
	mark.position = at
	mark.add_to_group("rail")
	stage.add_child(mark)
	_cylinder_mesh(at + Vector3(0, 0.7, 0), 0.16, 0.2, 1.4, Color("efe6d4"), 0.0)

func _stance(limit_z: float, half: float, length: float) -> void:
	_box_at(Vector3(0, 0.9, limit_z), Vector3(half * 2.0 + 0.5, 1.8, 0.28), Color("efe6d4"), 0.0, true)
	var mid_z := limit_z + length * 0.5
	_box_at(Vector3(-half, 0.9, mid_z), Vector3(0.28, 1.8, length), Color("efe6d4"), 0.0, true)
	_box_at(Vector3(half, 0.9, mid_z), Vector3(0.28, 1.8, length), Color("efe6d4"), 0.0, true)

func _spawn_post(index: int, at: Vector3, color: Color) -> void:
	var post := Node3D.new()
	post.set_script(load("res://scripts/post.gd"))
	stage.add_child(post)
	post.setup(index, at, color)
	posts.append(post)

func _light_cursor() -> void:
	if trial_mode == "guardcast":
		for post in posts:
			if is_instance_valid(post):
				post.light(true)
		return
	for post in posts:
		if is_instance_valid(post):
			post.light(post.order == trial_cursor)

func _clear_marks() -> void:
	posts.clear()
	for node in get_tree().get_nodes_in_group("mark"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("gate"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("rail"):
		if is_instance_valid(node):
			node.queue_free()

func trial_hit(order: int, kind_name: String, live: bool) -> void:
	if not trial_on:
		return
	if trial_mode == "gates":
		if student == null or student.dodge_cd < 0.08:
			return
		_consume(order)
		return
	var skill := Game.skill_for_place(Game.place)
	if trial_mode == "answer" and not answer_ready:
		_fail_trial("Guard the arm, then cut.")
		return
	if trial_mode == "guardcast":
		if not live:
			return
		if kind_name != "guardcast":
			_fail_trial("Spark while the guard is up.")
			return
		_consume(order)
		return
	if not live:
		_fail_trial("That mark was dark.")
		return
	if skill == "answer" and order > 0 and kind_name != "answer":
		_fail_trial("Only the reply reaches that post.")
		return
	if skill == "strength" and trial_played >= 2 and order > 0 and not _facing_center():
		_fail_trial("Face the center post. The wide arc is what reaches the sides.")
		return
	if not _kind_ok(skill, kind_name):
		_fail_trial("Use the art this room is teaching.")
		return
	_consume(order)

func _facing_center() -> bool:
	if student == null:
		return false
	var forward: Vector3 = -student.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.1:
		return false
	var to_center: Vector3 = Vector3(0, 0, -1.9) - student.global_position
	to_center.y = 0.0
	if to_center.length() < 0.2:
		return false
	return forward.normalized().dot(to_center.normalized()) > 0.72

func _kind_ok(skill: String, kind_name: String) -> bool:
	match skill:
		"spark", "lantern":
			return kind_name == "spell"
		"spellcut":
			return kind_name == "empower"
		"ink":
			if trial_cursor == 0:
				return kind_name == "sword" or kind_name == "empower"
			return kind_name == "ink"
		"answer":
			if trial_cursor > 0:
				return kind_name == "answer"
			return kind_name == "sword" or kind_name == "empower" or kind_name == "answer"
		_:
			return kind_name == "sword" or kind_name == "empower" or kind_name == "ink"

func _consume(order: int) -> void:
	if order != trial_cursor and trial_mode != "guardcast":
		_fail_trial("Not that one.")
		return
	for post in posts:
		if is_instance_valid(post) and post.order == order:
			post.light(false)
			post.live = false
	if trial_mode == "guardcast":
		trial_cursor += 1
	else:
		trial_cursor += 1
		_light_cursor()
	if trial_cursor >= trial_need:
		_finish_trial()

func _finish_trial() -> void:
	trial_on = false
	Game.note_trial(Game.skill_for_place(Game.place), trial_played, trial_time)

func _fail_trial(message: String) -> void:
	trial_on = false
	Game.toast.emit(message + " The pass ends. Nothing was lost.")

func _guard_arm(delta: float) -> void:
	guard_wait -= delta
	if guard_wait > 0.0:
		return
	guard_wait = 1.35 - float(trial_played) * 0.12
	if student and student.guard > 0.0:
		student.hurt(6.0)
		if trial_mode == "answer":
			answer_ready = true
			Game.toast.emit("The arm turned. Cut before the reply fades.")
			return
		guard_left -= 1
		Game.toast.emit("Turned. %d left." % guard_left)
		if guard_left <= 0:
			_finish_trial()
	else:
		if student:
			student.hurt(8.0)
		_fail_trial("The arm landed while the blade was down.")

func _gate_pass() -> void:
	if student == null:
		return
	for rail in get_tree().get_nodes_in_group("rail"):
		if is_instance_valid(rail) and student.global_position.distance_to(rail.global_position) < 0.48:
			_fail_trial("You touched the post.")
			return
	for gate in get_tree().get_nodes_in_group("gate"):
		if not is_instance_valid(gate):
			continue
		if int(gate.get_meta("order")) != trial_cursor:
			continue
		if student.global_position.distance_to(gate.global_position) > 1.05:
			continue
		if student.step_serial == 0 or student.step_serial == gate_step:
			continue
		gate_step = student.step_serial
		trial_cursor += 1
		gate.queue_free()
		if trial_cursor >= trial_need:
			_finish_trial()
		return

