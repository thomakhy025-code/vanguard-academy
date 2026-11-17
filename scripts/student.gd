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
var camera: Camera3D
var sword: MeshInstance3D
var sword_mat: StandardMaterial3D
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
	_build_body()
	if is_local:
		Game.changed.connect(refresh_weapon)
		Game.traveled.connect(func(_id) -> void:
			hp = max_hp
		)
	refresh_weapon()

func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.45
	shape.shape = capsule
	shape.position = Vector3(0, 0.78, 0)
	add_child(shape)
	var cloth := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.34
	body.height = 1.45
	cloth.mesh = body
	cloth.position = shape.position
	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = Color("3d6ea8") if local_player else Color("c5764b")
	cloth_mat.roughness = 0.78
	cloth.material_override = cloth_mat
	add_child(cloth)
	var head := MeshInstance3D.new()
	var skull := SphereMesh.new()
	skull.radius = 0.28
	skull.height = 0.56
	head.mesh = skull
	head.position = Vector3(0, 1.62, 0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("f0c7a4")
	skin.roughness = 0.7
	head.material_override = skin
	add_child(head)
	sword = MeshInstance3D.new()
	var blade := CylinderMesh.new()
	blade.top_radius = 0.06
	blade.bottom_radius = 0.09
	blade.height = 1.25
	sword.mesh = blade
	sword.position = Vector3(0.38, 1.05, -0.15)
	sword.rotation_degrees = Vector3(80, 0, 0)
	sword_mat = StandardMaterial3D.new()
	sword_mat.roughness = 0.28
	sword_mat.metallic = 0.55
	sword_mat.emission_enabled = true
	sword.material_override = sword_mat
	add_child(sword)

func refresh_weapon() -> void:
	if sword_mat == null:
		return
	var blend := clampf(float(Game.hunt_rank - 1) / 8.0, 0.0, 1.0)
	var color := Color("d4a054").lerp(Color("ffe08a"), blend)
	sword_mat.albedo_color = color
	sword_mat.emission = color
	sword_mat.emission_energy_multiplier = lerpf(0.25, 1.6, blend)
	if sword:
		sword.scale = Vector3.ONE * lerpf(1.0, 1.45, blend)

func _physics_process(delta: float) -> void:
	iframes = max(iframes - delta, 0.0)
	sword_cd = max(sword_cd - delta, 0.0)
	spell_cd = max(spell_cd - delta, 0.0)
	dodge_cd = max(dodge_cd - delta, 0.0)
	spark = max(spark - delta, 0.0)
	if swing > 0.0:
		swing = max(swing - delta, 0.0)
		if sword:
			sword.rotation_degrees.x = lerpf(80.0, -20.0, 1.0 - swing / 0.22)
	if not local_player:
		if net_ready:
			global_position = global_position.lerp(net_position, 1.0 - exp(-14.0 * delta))
			rotation.y = lerp_angle(rotation.y, net_yaw, 1.0 - exp(-14.0 * delta))
		return
	_steer(delta)
	_collect_ore()
	if Input.is_action_just_pressed("cut"):
		cut()
	if Input.is_action_just_pressed("spark"):
		cast_spark()
	if Input.is_action_just_pressed("step"):
		step_aside()
	if Online.active and local_player:
		var link := get_node_or_null("/root/Main/Net")
		if link:
			link.broadcast_state(global_position, rotation.y, hp)

func _steer(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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
	if sword_cd > 0.0:
		return
	sword_cd = 0.38
	swing = 0.22
	var heavy := true
	var kind := "sword"
	var amount := Game.outgoing(heavy)
	if Game.spellcut and spark > 0.0:
		amount *= 1.65
		spark = 0.0
		kind = "empower"
		Game.note_empower()
	_strike(2.35, amount, kind)

func cast_spark() -> void:
	if spell_cd > 0.0:
		return
	spell_cd = 0.48
	spark = 1.6 if Game.spellcut else 0.0
	var bolt := Node3D.new()
	bolt.set_script(load("res://scripts/bolt.gd"))
	get_tree().current_scene.get_node("FX").add_child(bolt)
	bolt.direction = -global_transform.basis.z
	bolt.direction.y = 0
	if bolt.direction.length() < 0.1:
		bolt.direction = Vector3(0, 0, -1)
	bolt.direction = bolt.direction.normalized()
	bolt.owner_path = get_path()
	bolt.global_position = global_position + Vector3(0, 1.1, 0) + bolt.direction * 0.8

func step_aside() -> void:
	if dodge_cd > 0.0:
		return
	dodge_cd = 0.62
	iframes = 0.38
	var hop := -global_transform.basis.z
	hop.y = 0
	if hop.length() < 0.1:
		hop = Vector3(0, 0, -1)
	velocity += hop.normalized() * 11.0
	if Game.hop_cut:
		_strike(2.1, Game.outgoing(true) * 0.8, "sword")

func _strike(reach: float, amount: float, kind: String) -> void:
	var forward := -global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	for node in get_tree().get_nodes_in_group("foe"):
		if _faces(node.global_position, forward, reach):
			node.take_hit(amount, kind)
	if Online.active:
		var link := get_node_or_null("/root/Main/Net")
		if link:
			for node in get_tree().get_nodes_in_group("player"):
				if node == self:
					continue
				if _faces(node.global_position, forward, reach):
					link.send_hit(str(node.name), amount)

func _faces(point: Vector3, forward: Vector3, reach: float) -> bool:
	var to := point - global_position
	to.y = 0
	if to.length() > reach or to.length() < 0.05:
		return false
	return forward.dot(to.normalized()) > 0.25

func hurt(amount: float) -> void:
	if not local_player or iframes > 0.0:
		return
	hp = max(hp - amount, 0.0)
	iframes = 0.18
	if hp <= 0.0:
		hp = max_hp
		global_position = Vector3(0, 2.0, 8)
		velocity = Vector3.ZERO
		if Game.place == Game.Place.COURT:
			Game.toast.emit("The match goes to Mira. Try the pair again.")
		else:
			Game.toast.emit("You were knocked down. The academy patches you up.")

func _collect_ore() -> void:
	for node in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(node) or not node.visible:
			continue
		if global_position.distance_to(node.global_position) < 1.55:
			node.visible = false
			Game.grant_ore(1, true)
			_restore_ore(node)

func _restore_ore(node: Node) -> void:
	await get_tree().create_timer(8.0).timeout
	if is_instance_valid(node) and is_inside_tree():
		node.visible = true

func apply_net(pos: Vector3, yaw: float, life: float) -> void:
	net_position = pos
	net_yaw = yaw
	net_ready = true
	hp = life
