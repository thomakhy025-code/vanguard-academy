class_name Student
extends CharacterBody3D

const SPEED := 7.4
const ACCEL := 40.0

var hp := 100.0
var max_hp := 100.0
var local_player := true
var iframes := 0.0
var sword_cd := 0.0
var spell_cd := 0.0
var dodge_cd := 0.0
var swing := 0.0
var spark := 0.0
var guard := 0.0
var riposte := 0.0
var door_lock := 0.0
var door_prompt := ""
var prompt_to := 0
var prompt_arrive := Vector3.ZERO
var step_serial := 0
var near_id := 0
var camera: Camera3D
var weapon_root: Node3D
var guard_disc: MeshInstance3D
var ribbon_mesh: MeshInstance3D
var ribbon_mat: StandardMaterial3D
var spark_hand: MeshInstance3D
var spark_mat: StandardMaterial3D
var lit_mats: Array = []
var built_key := ""
var net_position := Vector3.ZERO
var net_yaw := 0.0
var net_ready := false

func setup(follow_camera: Camera3D, is_local: bool) -> void:
	camera = follow_camera
	local_player = is_local
	set_meta("local", is_local)
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	_build_body()
	if is_local:
		Game.changed.connect(refresh_weapon)
		Game.traveled.connect(func(_id) -> void:
			hp = max_hp
			door_lock = 1.0
			near_id = 0
		)
	refresh_weapon()

func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.5
	shape.shape = capsule
	shape.position = Vector3(0, 0.78, 0)
	add_child(shape)
	var tunic := Color("3e5f86") if local_player else Color("c5764b")
	_orb(Vector3(0, 0.42, 0), 0.34, tunic, 0.0)
	var torso := CapsuleMesh.new()
	torso.radius = 0.32
	torso.height = 0.78
	_mesh(torso, Vector3(0, 0.92, 0), tunic, 0.0, 0.0)
	_mesh(_box(Vector3(0.46, 0.42, 0.18)), Vector3(0, 0.78, 0.2), Color("2e4048"), 0.0, 0.0)
	_orb(Vector3(0, 0.78, 0.3), 0.07, Color("e2c56a"), 0.2)
	_orb(Vector3(0, 1.42, 0), 0.3, Color("f0c7a4"), 0.0)
	_orb(Vector3(0, 1.62, 0), 0.22, Color("2e4048"), 0.0)
	spark_hand = _orb(Vector3(-0.42, 0.95, 0.08), 0.11, Color("9fd6ff"), 0.35)
	spark_mat = spark_hand.material_override as StandardMaterial3D
	weapon_root = Node3D.new()
	weapon_root.position = Vector3(0.46, 0.92, 0.02)
	add_child(weapon_root)
	guard_disc = _mesh(_cylinder(0.95, 0.95, 0.08), Vector3(0, 0.16, 0), Color("f4e3a8"), 0.8, 0.0)
	guard_disc.visible = false
	ribbon_mesh = _mesh(_box(Vector3(0.72, 0.12, 0.34)), Vector3(0, 1.02, 0.16), Color("e2c56a"), 0.15, 0.4)
	ribbon_mat = ribbon_mesh.material_override as StandardMaterial3D
	ribbon_mesh.visible = false

func _box(box_size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return mesh

func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return mesh

func _orb(at: Vector3, radius: float, color: Color, glow: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _mesh(mesh, at, color, glow, 0.0)

func _mesh(mesh: Mesh, at: Vector3, color: Color, glow: float, metal: float) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.material_override = _skin(color, glow, metal)
	add_child(inst)
	return inst

func _skin(color: Color, glow: float, metal: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78 if metal < 0.2 else 0.34
	material.metallic = metal
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

func refresh_weapon() -> void:
	var key := "%s:%d" % [Game.weapon, _tier()]
	if key != built_key:
		built_key = key
		_rebuild_weapon()
	_apply_glow()
	_apply_ribbon()

func _tier() -> int:
	if Game.hunt_rank >= 8:
		return 8
	if Game.hunt_rank >= 5:
		return 5
	if Game.hunt_rank >= 3:
		return 3
	return 1

func _rebuild_weapon() -> void:
	if weapon_root == null:
		return
	for child in weapon_root.get_children():
		child.free()
	lit_mats.clear()
	var blend := clampf(float(Game.hunt_rank - 1) / 8.0, 0.0, 1.0)
	weapon_root.scale = Vector3.ONE * lerpf(1.12, 1.62, blend)
	match Game.weapon:
		"needle":
			_part(_cylinder(0.02, 0.035, 1.85), Vector3(0, 1.05, 0), true)
			_part(_box(Vector3(0.28, 0.05, 0.08)), Vector3(0, 0.16, 0), false)
			_part(_cylinder(0.04, 0.04, 0.24), Vector3(0, 0.0, 0), false)
		"hammer":
			_part(_cylinder(0.05, 0.05, 0.72), Vector3(0, 0.32, 0), false)
			_part(_box(Vector3(0.62, 0.42, 0.42)), Vector3(0, 0.78, 0), true)
			_part(_box(Vector3(0.72, 0.08, 0.08)), Vector3(0, 0.78, 0.22), false)
		"lantern":
			_part(_box(Vector3(0.2, 1.45, 0.06)), Vector3(0, 0.95, 0), true)
			_part(_box(Vector3(0.5, 0.07, 0.1)), Vector3(0, 0.2, 0), false)
			_part(_cylinder(0.045, 0.045, 0.26), Vector3(0, 0.02, 0), false)
		"ink":
			_part(_box(Vector3(0.14, 1.4, 0.07)), Vector3(0, 0.92, 0), true)
			_part(_box(Vector3(0.04, 1.22, 0.03)), Vector3(0.1, 0.9, 0), true)
			_part(_box(Vector3(0.42, 0.06, 0.1)), Vector3(0, 0.18, 0), false)
		_:
			_part(_cylinder(0.045, 0.045, 0.28), Vector3(0, 0.0, 0), false)
			_part(_box(Vector3(0.5, 0.07, 0.12)), Vector3(0, 0.2, 0), false)
			_part(_cylinder(0.025, 0.08, 1.42), Vector3(0, 0.98, 0), true)
			_part(_orb_mesh(0.08), Vector3(0, -0.2, 0), false)
	if _tier() >= 3:
		_part(_orb_mesh(0.07), Vector3(0, 0.2, 0.1), true)
	if _tier() >= 5:
		_part(_box(Vector3(0.22, 0.08, 0.16)), Vector3(0.34, 0.2, 0), false)
		_part(_box(Vector3(0.22, 0.08, 0.16)), Vector3(-0.34, 0.2, 0), false)

func _orb_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh

func _part(mesh: Mesh, at: Vector3, lit: bool) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	var material := StandardMaterial3D.new()
	material.metallic = 0.72
	material.roughness = 0.28
	material.emission_enabled = true
	inst.material_override = material
	inst.set_meta("lit", lit)
	weapon_root.add_child(inst)
	if lit:
		lit_mats.append(material)
	else:
		var trim := Color("e2c56a")
		if mesh is CylinderMesh:
			var pole := mesh as CylinderMesh
			if pole.height < 0.85 and pole.top_radius < 0.06:
				trim = Color("2e4048")
		material.albedo_color = trim
		material.emission = trim
		material.emission_energy_multiplier = 0.18

func _apply_glow() -> void:
	var color := Game.weapon_color()
	var blend := clampf(float(Game.hunt_rank - 1) / 8.0, 0.0, 1.0)
	var energy := lerpf(0.35, 1.8, blend)
	if _tier() >= 8:
		energy += 0.45
	for material in lit_mats:
		if material == null:
			continue
		material.albedo_color = color
		material.emission = color
		material.emission_energy_multiplier = energy

func _apply_ribbon() -> void:
	if ribbon_mesh == null or ribbon_mat == null:
		return
	var color_name := Game.ribbon
	if color_name == "":
		color_name = Game.floor_ribbon(global_position)
	if color_name == "":
		ribbon_mesh.visible = false
		return
	ribbon_mesh.visible = true
	var color := Color(color_name)
	ribbon_mat.albedo_color = color
	ribbon_mat.emission = color

func _rest_angle() -> float:
	match Game.pose:
		"raised":
			return 46.0
		"low":
			return 98.0
		_:
			return 72.0

func _physics_process(delta: float) -> void:
	iframes = maxf(iframes - delta, 0.0)
	sword_cd = maxf(sword_cd - delta, 0.0)
	spell_cd = maxf(spell_cd - delta, 0.0)
	dodge_cd = maxf(dodge_cd - delta, 0.0)
	spark = maxf(spark - delta, 0.0)
	riposte = maxf(riposte - delta, 0.0)
	door_lock = maxf(door_lock - delta, 0.0)
	if swing > 0.0:
		swing = maxf(swing - delta, 0.0)
		if swing == 0.0:
			guard = Game.guard_hold()
	elif guard > 0.0:
		guard = maxf(guard - delta, 0.0)
	if weapon_root:
		var rest := _rest_angle()
		if swing > 0.0:
			weapon_root.rotation_degrees.x = lerpf(rest - 110.0, rest, 1.0 - swing / 0.22)
		else:
			weapon_root.rotation_degrees.x = rest
	if guard_disc:
		guard_disc.visible = guard > 0.0
	if spark_mat:
		spark_mat.emission_energy_multiplier = 1.8 if spark > 0.0 else 0.35
	if not local_player:
		if net_ready:
			global_position = global_position.lerp(net_position, 1.0 - exp(-14.0 * delta))
			rotation.y = lerp_angle(rotation.y, net_yaw, 1.0 - exp(-14.0 * delta))
		return
	_steer(delta)
	if not Game.opening:
		_collect_nodes("ore")
		_collect_nodes("shard")
		_touch_places()
		_touch_circuit()
		if Input.is_action_just_pressed("cut"):
			cut()
		if Input.is_action_just_pressed("spark"):
			cast_spark()
		if Input.is_action_just_pressed("step"):
			step_aside()
	if Online.active:
		var link := get_node_or_null("/root/Main/Net")
		if link:
			link.broadcast_state(global_position, rotation.y, hp)

func _steer(delta: float) -> void:
	var input := Vector2.ZERO
	if not Game.opening:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Game.stick.length() > 0.12:
			input = Game.stick
	var direction := Vector3.ZERO
	if camera and input.length() > 0.05:
		var basis := camera.global_transform.basis
		var forward := -basis.z
		forward.y = 0
		forward = forward.normalized()
		var right := basis.x
		right.y = 0
		right = right.normalized()
		direction = (right * input.x + forward * -input.y).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-12.0 * delta))
	var wish := direction * SPEED
	velocity.x = move_toward(velocity.x, wish.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, wish.z, ACCEL * delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -1.0
	move_and_slide()

func cut() -> void:
	if Game.opening or sword_cd > 0.0:
		return
	sword_cd = Game.cut_wait()
	swing = 0.22
	var reach := 2.35
	var arc := 0.25
	var reply := false
	if Game.shape_active():
		reach = Game.weapon_reach()
		arc = Game.weapon_arc()
	if riposte > 0.0 and Game.book_active("answer"):
		reach += 0.6
		riposte = 0.0
		reply = true
	var amount := Game.outgoing(true)
	var kind := "answer" if reply else "sword"
	if Game.spellcut and spark > 0.0 and not reply:
		amount *= 1.65
		spark = 0.0
		kind = "empower"
	elif Game.spellcut and spark > 0.0:
		amount *= 1.65
		spark = 0.0
	_strike(reach, amount, kind, arc)
	if Game.book_active("ink") and Game.weapon == "ink":
		_ink_follow(reach, arc)

func _ink_follow(reach: float, arc: float) -> void:
	await get_tree().create_timer(0.16).timeout
	if is_inside_tree():
		_strike(reach + Game.ink_bonus(), Game.outgoing(false), "ink", arc)

func cast_spark() -> void:
	if Game.opening or spell_cd > 0.0:
		return
	if guard > 0.0:
		_guardcast()
		return
	spark = Game.spark_window() if Game.spellcut else 0.0
	if Game.bias == "caster" and spark > 0.0:
		spark = Game.spark_window()
	spell_cd = Game.spark_wait()
	var bolt := Node3D.new()
	bolt.set_script(load("res://scripts/bolt.gd"))
	get_tree().current_scene.get_node("FX").add_child(bolt)
	bolt.direction = -global_transform.basis.z
	bolt.direction.y = 0
	if bolt.direction.length() < 0.1:
		bolt.direction = Vector3(0, 0, -1)
	bolt.direction = bolt.direction.normalized()
	bolt.owner_path = get_path()
	bolt.global_position = global_position + Vector3(0, 1.05, 0) + bolt.direction * 0.8

func _guardcast() -> void:
	spell_cd = 0.48
	guard = 0.0
	spark = 0.0
	var amount := Game.outgoing(false)
	var origin := global_position
	_burst_visual()
	for node in get_tree().get_nodes_in_group("foe"):
		if origin.distance_to(node.global_position) > Game.burst_radius():
			continue
		var hit := amount
		var foe_kind = node.kind
		if foe_kind == Foe.Kind.BEAST or foe_kind == Foe.Kind.ELITE or foe_kind == Foe.Kind.BOSS or foe_kind == Foe.Kind.SPIRIT:
			hit = Game.spirit_against_monsters(amount)
		node.take_hit(hit, "guardcast")
	for node in get_tree().get_nodes_in_group("mark"):
		if origin.distance_to(node.global_position) > Game.burst_radius():
			continue
		if node.has_method("take_hit"):
			node.take_hit(amount, "guardcast")
	if Online.active:
		var link := get_node_or_null("/root/Main/Net")
		if link:
			for node in get_tree().get_nodes_in_group("player"):
				if node == self:
					continue
				if origin.distance_to(node.global_position) <= 2.4:
					link.send_hit(str(node.name), amount)

func _burst_visual() -> void:
	var host := get_tree().current_scene.get_node_or_null("FX")
	if host == null:
		return
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.45
	ball.height = 0.9
	mesh.mesh = ball
	mesh.global_position = global_position + Vector3(0, 0.8, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f4e3a8")
	material.emission_enabled = true
	material.emission = Color("ffe08a")
	material.emission_energy_multiplier = 1.6
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.45
	mesh.material_override = material
	host.add_child(mesh)
	var fade := create_tween()
	fade.tween_property(mesh, "scale", Vector3(3.2, 3.2, 3.2), 0.18)
	fade.parallel().tween_property(material, "albedo_color:a", 0.0, 0.18)
	fade.finished.connect(mesh.queue_free)

func step_aside() -> void:
	if Game.opening or dodge_cd > 0.0:
		return
	dodge_cd = Game.step_wait()
	step_serial += 1
	iframes = 0.38
	var hop := -global_transform.basis.z
	hop.y = 0
	if hop.length() < 0.1:
		hop = Vector3(0, 0, -1)
	velocity += hop.normalized() * 11.0
	if Game.book_active("sparrow"):
		_strike(2.1, Game.outgoing(true) * 0.8, "sword")

func _strike(reach: float, amount: float, kind: String, arc := 0.25) -> void:
	var forward := -global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	for node in get_tree().get_nodes_in_group("foe"):
		if _faces(node.global_position, forward, reach, arc):
			node.take_hit(amount, kind)
	for node in get_tree().get_nodes_in_group("mark"):
		if _faces(node.global_position, forward, reach, arc) and node.has_method("take_hit"):
			node.take_hit(amount, kind)
	for node in get_tree().get_nodes_in_group("anvil"):
		if _faces(node.global_position, forward, reach, arc):
			Game.anvil_strike()
	if Online.active:
		var link := get_node_or_null("/root/Main/Net")
		if link:
			for node in get_tree().get_nodes_in_group("player"):
				if node == self:
					continue
				if _faces(node.global_position, forward, reach, arc):
					link.send_hit(str(node.name), amount)

func _faces(point: Vector3, forward: Vector3, reach: float, arc: float) -> bool:
	var to := point - global_position
	to.y = 0
	if to.length() > reach or to.length() < 0.05:
		return false
	return forward.dot(to.normalized()) > arc

func hurt(amount: float) -> void:
	if not local_player or iframes > 0.0:
		return
	if guard > 0.0:
		amount *= 0.3
		Game.note_guard()
		if Game.book_active("answer"):
			riposte = Game.answer_time()
	hp = maxf(hp - amount, 0.0)
	iframes = 0.18
	if hp <= 0.0:
		hp = max_hp
		global_position = Vector3(0, 2.0, 8)
		velocity = Vector3.ZERO
		if Game.place == Game.Place.COURT:
			Game.toast.emit("The match goes to Mira. Sword and spell, try the pair again.")
		else:
			Game.toast.emit("You were knocked down. The academy patches you up.")

func _collect_nodes(group: String) -> void:
	for node in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(node) or not node.visible:
			continue
		if global_position.distance_to(node.global_position) < 1.55:
			node.visible = false
			var amount := int(node.get_meta("amount", 1))
			if group == "shard":
				Game.grant_shard(amount, true)
			else:
				Game.grant_ore(amount, true)
			_restore_node(node)

func _restore_node(node: Node) -> void:
	await get_tree().create_timer(8.0).timeout
	if is_instance_valid(node) and is_inside_tree():
		node.visible = true

func _touch_places() -> void:
	door_prompt = ""
	if door_lock > 0.0:
		return
	var action := ""
	var arg = ""
	var nid := 0
	if Game.place == Game.Place.YARD:
		for forge_node in get_tree().get_nodes_in_group("forge"):
			if _near(forge_node, 2.1):
				action = "forge"
				nid = forge_node.get_instance_id()
				break
	for door in get_tree().get_nodes_in_group("door"):
		if action != "":
			break
		if _near(door, 2.3):
			if bool(door.get_meta("prompt", false)):
				door_prompt = str(door.get_meta("label", "Enter the school"))
				prompt_to = int(door.get_meta("to"))
				var spot: Vector3 = door.get_meta("arrive", Vector3(0, 0.45, 6))
				prompt_arrive = spot
				continue
			action = "door"
			arg = [door.get_meta("to"), door.get_meta("back", Vector3(0, 0.45, 6))]
			nid = door.get_instance_id()
			break
	if action == "" and Game.place == Game.Place.COURT:
		for ring in get_tree().get_nodes_in_group("duel"):
			if _near(ring, 2.2):
				action = "ring"
				arg = ring.get_meta("mode")
				nid = ring.get_instance_id()
				break
	if action == "":
		for book in get_tree().get_nodes_in_group("book"):
			if _near(book, 1.45):
				action = "book"
				arg = book.get_meta("book")
				nid = book.get_instance_id()
				break
	if action == "":
		for desk in get_tree().get_nodes_in_group("desk"):
			if _near(desk, 1.6):
				action = "desk"
				arg = desk.get_meta("bias")
				nid = desk.get_instance_id()
				break
	if action == "":
		for course in get_tree().get_nodes_in_group("course"):
			if _near(course, 1.8):
				action = "course"
				arg = course.get_meta("course")
				nid = course.get_instance_id()
				break
	if action == "":
		near_id = 0
		return
	if nid == near_id:
		return
	near_id = nid
	call_deferred("_do_touch", action, arg)

func _do_touch(action: String, arg) -> void:
	match action:
		"door":
			var place_id := int(arg[0]) if arg is Array else int(arg)
			var back: Vector3 = arg[1] if arg is Array else Vector3(0, 0.45, 6)
			Game.open_door(place_id, back)
		"forge":
			Game.ask_forge.emit()
		"ring":
			var scene := get_tree().current_scene
			if scene and scene.has_method("start_court"):
				scene.start_court(str(arg))
		"book":
			Game.read_book(str(arg))
		"desk":
			Game.choose_bias(str(arg))
		"course":
			var hall := get_tree().current_scene
			if hall and hall.has_method("start_hall"):
				hall.start_hall(int(arg))

func _touch_circuit() -> void:
	for node in get_tree().get_nodes_in_group("circuit"):
		if not is_instance_valid(node) or not node.visible:
			continue
		if _near(node, 1.45):
			Game.touch_circuit(int(node.get_meta("index")))
			node.visible = false

func _near(node: Node3D, reach: float) -> bool:
	return global_position.distance_to(node.global_position) < reach

func apply_net(pos: Vector3, yaw: float, life: float) -> void:
	net_position = pos
	net_yaw = yaw
	net_ready = true
	hp = life
