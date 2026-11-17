extends Node3D

const StudentScript := preload("res://scripts/student.gd")
const FoeScript := preload("res://scripts/foe.gd")

var stage: Node3D
var fx: Node3D
var camera: Camera3D
var environment: Environment
var student
var hall_running := false
var hall_time := 0.0
var hall_token := 0

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
	var sun := DirectionalLight3D.new()
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
	if student == null or camera == null:
		return
	var behind: Vector3 = student.global_transform.basis.z
	camera.global_position = student.global_position + Vector3.UP * 5.6 + behind * 8.0
	camera.look_at(student.global_position + Vector3.UP * 1.25)

func _spark_wipe() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var veil := ColorRect.new()
	veil.color = Color("f4e3a8")
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(veil)
	var fade := create_tween()
	fade.tween_property(veil, "modulate:a", 0.0, 0.32)
	fade.finished.connect(layer.queue_free)

func _process(delta: float) -> void:
	if hall_running:
		hall_time += delta
	if student == null:
		return
	var behind: Vector3 = student.global_transform.basis.z
	var wish: Vector3 = student.global_position + Vector3.UP * 5.6 + behind * 8.0
	camera.global_position = camera.global_position.lerp(wish, 1.0 - exp(-4.5 * delta))
	camera.look_at(student.global_position + Vector3.UP * 1.25)

func rebuild(id: int) -> void:
	hall_running = false
	for child in stage.get_children():
		child.free()
	for child in fx.get_children():
		child.free()
	_tint(id)
	match id:
		Game.Place.YARD:
			_ground(Color("7ec48a"), 46.0)
			_scatter_blobs(Color("8ed39a"), 10, 8.0, 18.0, 0.7)
			_forge()
			_tower(Vector3(0, 0, -16))
			_spawn_foe(FoeScript.Kind.DUMMY, Vector3(0, 1, -3))
		Game.Place.GARDEN:
			_ground(Color("57af70"), 58.0)
			_scatter_blobs(Color("3f9a62"), 16, 6.0, 24.0, 0.55)
			_wall_ring(Color("cbbe9e"), 22.0)
			_ore_nodes(6, 14.0)
			_pack(FoeScript.Kind.BEAST, 4, 10.0)
		Game.Place.UNDERCROFT:
			_ground(Color("6d7c88"), 36.0)
			environment.background_color = Color("6f8ea3")
			environment.fog_density = 0.02
			_arches()
			_pack(FoeScript.Kind.ELITE, 3, 8.0)
			_ore_nodes(4, 9.0)
		Game.Place.WASTES:
			_ground(Color("d2a15a"), 90.0)
			environment.background_color = Color("f0b27a")
			_scatter_blobs(Color("c5764b"), 12, 12.0, 34.0, 0.4)
			_pack(FoeScript.Kind.BEAST, 5, 14.0)
			_spawn_foe(FoeScript.Kind.BOSS, Vector3(0, 1, -18))
		Game.Place.COURT:
			_ground(Color("8d6a45"), 34.0)
			_ring(Vector3(-5, 0.08, 0), Color("d5dbe0"), 4.2)
			_ring(Vector3(5, 0.08, 0), Color("e2c56a"), 4.2)
			environment.background_color = Color("6e5848")
		Game.Place.HALL:
			_ground(Color("b7aa96"), 32.0)
			_stair()
			_plaque()
		Game.Place.CLASSROOM:
			_ground(Color("f0e2c4"), 30.0)
			_desk(Vector3(0, 0, -6))
			_board(Vector3(0, 2.2, -10))
		Game.Place.LIBRARY:
			_ground(Color("c8b48a"), 32.0)
			_shelves()
			_glow_book(Vector3(0, 1.1, -4))
	if student:
		student.global_position = Vector3(0, 2.4, 8)
		student.velocity = Vector3.ZERO
		_snap_camera()
	_spark_wipe()

func _tint(id: int) -> void:
	environment.background_color = Color("85c1e0")
	environment.fog_density = 0.008
	environment.fog_light_color = Color("d5eef8")
	if id == Game.Place.WASTES:
		environment.fog_light_color = Color("f6d7b0")

func start_court(mode: String) -> void:
	if Online.active:
		Game.toast.emit("Leave the online court before a practice match.")
		return
	Game.court_mode = mode
	Game.travel(Game.Place.COURT)
	_spawn_foe(FoeScript.Kind.DUELIST, Vector3(0, 1, -4))

func start_hall() -> void:
	Game.travel(Game.Place.HALL)
	for i in 3:
		var foe = _spawn_foe(FoeScript.Kind.CONSTRUCT, Vector3(-4.5 + i * 4.5, 1, -6))
		foe.died.connect(_on_construct_died)
	hall_token += 1
	hall_time = 0.0
	hall_running = true
	Game.toast.emit("Course started. Drop all three constructs.")

func host_match(mode: String) -> void:
	Game.court_mode = mode
	if not Online.host(mode):
		return
	_rename_local()
	Game.travel(Game.Place.COURT)
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
	var named := get_node_or_null("Peer%d" % id)
	return named

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

func _spawn_foe(kind: FoeScript.Kind, at: Vector3):
	var foe = FoeScript.new()
	stage.add_child(foe)
	foe.setup(kind, at)
	foe.died.connect(_on_foe_died)
	return foe

func _on_foe_died(foe) -> void:
	if foe.kind == FoeScript.Kind.DUELIST:
		Game.note_court(Game.court_mode == "open")
		return
	if foe.kind == FoeScript.Kind.DUMMY or foe.kind == FoeScript.Kind.CONSTRUCT:
		return
	var amount := 2
	if foe.kind == FoeScript.Kind.ELITE:
		amount = 4
	elif foe.kind == FoeScript.Kind.BOSS:
		amount = 8
	Game.grant_ore(amount, true)
	var kind = foe.kind
	var at: Vector3 = foe.home
	var here: int = Game.place
	_respawn(kind, at, here)

func _respawn(kind, at: Vector3, here: int) -> void:
	await get_tree().create_timer(5.0).timeout
	if Game.place != here:
		return
	_spawn_foe(kind, at)

func _pack(kind, count: int, radius: float) -> void:
	for i in count:
		var angle := TAU * float(i) / float(count)
		_spawn_foe(kind, Vector3(sin(angle) * radius, 1, -6.0 + cos(angle) * radius * 0.65))

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

func _scatter_blobs(color: Color, count: int, inner: float, outer: float, flat: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1408 + Game.place
	for i in count:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(inner, outer)
		var radius := rng.randf_range(0.8, 1.8)
		var mesh := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = radius
		ball.height = radius * 2.0 * flat
		mesh.mesh = ball
		mesh.position = Vector3(sin(angle) * dist, radius * flat * 0.35, cos(angle) * dist)
		mesh.material_override = _mat(color, 0.0)
		stage.add_child(mesh)

func _forge() -> void:
	_block(Vector3(-6, 0.7, -2), Vector3(2.4, 1.4, 1.4), Color("4d4038"), true)
	var mouth := MeshInstance3D.new()
	var glow := BoxMesh.new()
	glow.size = Vector3(1.1, 0.7, 0.3)
	mouth.mesh = glow
	mouth.position = Vector3(-6, 0.9, -1.2)
	mouth.material_override = _mat(Color("ffb15a"), 1.6)
	stage.add_child(mouth)
	var light := OmniLight3D.new()
	light.position = Vector3(-6, 1.6, -1.0)
	light.light_color = Color("ffb15a")
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.shadow_enabled = false
	stage.add_child(light)
	for i in 4:
		_block(Vector3(-3.2, 0.7, -1.2 + i * 0.7), Vector3(0.12, 1.3, 0.12), Color("d4a054"), false)

func _tower(at: Vector3) -> void:
	_block(at + Vector3(0, 3.2, 0), Vector3(2.2, 6.4, 2.2), Color("efe6d4"), true)
	var cap := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 1.5
	dome.height = 2.0
	cap.mesh = dome
	cap.position = at + Vector3(0, 6.8, 0)
	cap.material_override = _mat(Color("c5764b"), 0.0)
	stage.add_child(cap)
	var bell := MeshInstance3D.new()
	var bell_mesh := SphereMesh.new()
	bell_mesh.radius = 0.28
	bell_mesh.height = 0.4
	bell.mesh = bell_mesh
	bell.position = at + Vector3(0, 4.6, 1.15)
	bell.material_override = _mat(Color("f0d78c"), 0.4)
	stage.add_child(bell)

func _wall_ring(color: Color, radius: float) -> void:
	for i in 10:
		var angle := TAU * float(i) / 10.0
		if absf(angle - PI * 0.5) < 0.4:
			continue
		var pos := Vector3(sin(angle) * radius, 1.1, cos(angle) * radius)
		_block(pos, Vector3(3.2, 2.2, 0.8), color, true)

func _arches() -> void:
	for i in 4:
		_block(Vector3(-6 + i * 4, 1.6, -8), Vector3(0.7, 3.2, 0.7), Color("d9d3c7"), true)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-6 + i * 4, 2.8, -6)
		lamp.light_color = Color("ffd2a0")
		lamp.light_energy = 1.1
		lamp.omni_range = 5.0
		lamp.shadow_enabled = false
		stage.add_child(lamp)

func _ring(at: Vector3, color: Color, radius: float) -> void:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.28
	mesh.mesh = torus
	mesh.position = at
	mesh.material_override = _mat(color, 0.15)
	stage.add_child(mesh)

func _stair() -> void:
	for i in 5:
		_block(Vector3(0, 0.25 + i * 0.15, -2.0 - i * 1.5), Vector3(6.0 - i * 0.4, 0.35, 1.3), Color("efe6d4"), true)

func _plaque() -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 56
	label.modulate = Color("2e4048")
	label.position = Vector3(0, 3.2, -8)
	if Game.best_hall_time < 0.0:
		label.text = "The stair is waiting"
	else:
		label.text = "Best  %.1fs" % Game.best_hall_time
	stage.add_child(label)
	var shaft := OmniLight3D.new()
	shaft.position = Vector3(0, 6, -4)
	shaft.light_color = Color("fff6dd")
	shaft.light_energy = 1.4
	shaft.omni_range = 10.0
	shaft.shadow_enabled = false
	stage.add_child(shaft)

func _desk(at: Vector3) -> void:
	_block(at + Vector3(0, 0.7, 0), Vector3(3.2, 0.3, 1.2), Color("8d5a3c"), true)
	_block(at + Vector3(0, 0.35, 0), Vector3(0.3, 0.7, 0.8), Color("6b422c"), true)

func _board(at: Vector3) -> void:
	_block(at, Vector3(4.5, 2.2, 0.2), Color("24343b"), true)
	var mark := Label3D.new()
	mark.text = "Cut  +  Spark"
	mark.font_size = 64
	mark.position = at + Vector3(0, 0, 0.2)
	mark.modulate = Color("f4efe4")
	stage.add_child(mark)

func _shelves() -> void:
	for i in 5:
		_block(Vector3(-8 + i * 3.2, 1.6, -9), Vector3(2.2, 3.2, 0.6), Color("6b422c"), true)

func _glow_book(at: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.2, 0.9)
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = _mat(Color("f0d78c"), 1.2)
	stage.add_child(mesh)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 0.4, 0)
	light.light_color = Color("f0d78c")
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.shadow_enabled = false
	stage.add_child(light)

func _ore_nodes(count: int, radius: float) -> void:
	for i in count:
		var angle := TAU * float(i) / float(count) + 0.4
		var mesh := MeshInstance3D.new()
		var rock := SphereMesh.new()
		rock.radius = 0.28
		rock.height = 0.4
		mesh.mesh = rock
		mesh.position = Vector3(sin(angle) * radius, 0.35, cos(angle) * radius)
		mesh.material_override = _mat(Color("e2c56a"), 0.35)
		mesh.add_to_group("ore")
		stage.add_child(mesh)

func _block(at: Vector3, box_size: Vector3, color: Color, solid: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = _mat(color, 0.0)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = at
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box_size
		shape.shape = box_shape
		body.add_child(shape)
		mesh.position = Vector3.ZERO
		body.add_child(mesh)
		stage.add_child(body)
	else:
		stage.add_child(mesh)

func _mat(color: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material
