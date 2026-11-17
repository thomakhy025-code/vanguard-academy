class_name Foe
extends CharacterBody3D

enum Kind { BEAST, ELITE, BOSS, CONSTRUCT, DUMMY, DUELIST, SPIRIT }

signal died(foe: Foe)

var kind := Kind.BEAST
var hp := 30.0
var max_hp := 30.0
var attack_damage := 6.0
var speed := 3.3
var leash := 10.0
var tough := 1.0
var alive := true
var home := Vector3.ZERO
var attack_wait := 0.6
var bar: MeshInstance3D
var body_mat: StandardMaterial3D

func setup(next_kind: Kind, at: Vector3, next_tough := 1.0) -> void:
	kind = next_kind
	tough = next_tough
	home = at
	global_position = at
	collision_layer = 4
	collision_mask = 1
	_stats()
	hp *= tough
	max_hp = hp
	_build()
	add_to_group("foe")
	if kind == Kind.CONSTRUCT:
		add_to_group("hall")

func _stats() -> void:
	match kind:
		Kind.SPIRIT:
			hp = 14
			speed = 3.0
			attack_damage = 4
			leash = 7.0
		Kind.BEAST:
			hp = 30
			speed = 3.4
			attack_damage = 6
			leash = 9.0
		Kind.ELITE:
			hp = 58
			speed = 3.1
			attack_damage = 9
			leash = 11.0
		Kind.BOSS:
			hp = 150
			speed = 2.6
			attack_damage = 12
			leash = 18.0
		Kind.CONSTRUCT:
			hp = 42
			speed = 3.6
			attack_damage = 8
			leash = 30.0
		Kind.DUMMY:
			hp = 1
			speed = 0
			attack_damage = 0
			leash = 0.4
		Kind.DUELIST:
			hp = 96
			speed = 4.4
			attack_damage = 12.0 if Game.court_mode != "open" else 16.0
			leash = 40.0
	max_hp = hp

func _build() -> void:
	var color := Color("57af70")
	var radius := 0.42
	var tall := 1.2
	match kind:
		Kind.SPIRIT:
			color = Color("9dca8c")
			radius = 0.3
			tall = 0.85
		Kind.ELITE:
			color = Color("6f8fbf")
			tall = 1.45
			radius = 0.5
		Kind.BOSS:
			color = Color("c5764b")
			radius = 0.95
			tall = 2.4
		Kind.CONSTRUCT:
			color = Color("cbbe9e")
			tall = 1.35
			radius = 0.46
		Kind.DUMMY:
			color = Color("b08968")
			tall = 1.55
			radius = 0.32
		Kind.DUELIST:
			color = Color("3e5f86")
			tall = 1.15
			radius = 0.34
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = tall
	shape.shape = capsule
	shape.position = Vector3(0, tall * 0.45, 0)
	add_child(shape)
	if kind == Kind.CONSTRUCT:
		_box(Vector3(radius * 1.5, tall * 0.7, radius * 1.2), Vector3(0, tall * 0.55, 0), color)
		_orb(Vector3(0, tall * 0.95, 0), radius * 0.55, color.lightened(0.12))
		_box(Vector3(radius * 1.8, 0.08, 0.08), Vector3(0, tall * 0.7, radius * 0.4), Color("e2c56a"))
	elif kind == Kind.DUELIST:
		_orb(Vector3(0, 0.4, 0), 0.32, color)
		_capsule(0.28, 0.7, Vector3(0, 0.85, 0), color)
		_orb(Vector3(0, 1.35, 0), 0.26, Color("f0c7a4"))
		_orb(Vector3(0, 1.52, 0), 0.18, Color("2e4048"))
		var blade_color := Color("d5dbe0") if Game.court_mode != "open" else Color("e2c56a")
		_box(Vector3(0.08, 0.9, 0.08), Vector3(0.42, 0.95, 0.1), blade_color)
	elif kind == Kind.BOSS:
		_orb(Vector3(0, 0.7, 0), radius * 0.85, color)
		_capsule(radius * 0.75, tall, Vector3(0, tall * 0.55, 0), color)
		_orb(Vector3(0, tall + 0.15, 0), radius * 0.7, color.lightened(0.1))
		_orb(Vector3(-0.45, tall + 0.55, 0), 0.22, Color("2e4048"))
		_orb(Vector3(0.45, tall + 0.55, 0), 0.22, Color("2e4048"))
		_box(Vector3(0.12, 2.4, 0.12), Vector3(0, tall + 1.3, -0.2), Color("2e4048"))
		_box(Vector3(0.7, 0.45, 0.08), Vector3(0.35, tall + 2.3, -0.2), Color("e2c56a"))
	else:
		_orb(Vector3(0, radius * 0.7, 0), radius, color)
		_capsule(radius * 0.85, tall, Vector3(0, tall * 0.55, 0), color)
		_orb(Vector3(0, tall + radius * 0.15, 0), radius * 0.75, color.lightened(0.12))
		_orb(Vector3(-radius * 0.55, tall + radius * 0.45, 0), radius * 0.22, color.darkened(0.1))
		_orb(Vector3(radius * 0.55, tall + radius * 0.45, 0), radius * 0.22, color.darkened(0.1))
		if kind == Kind.ELITE:
			_orb(Vector3(0, tall + radius * 0.7, 0), 0.16, Color("e2c56a"))
		if kind == Kind.DUMMY:
			_box(Vector3(0.12, 0.8, 0.12), Vector3(0.28, 1.15, 0), Color("d4a054"))
	if kind == Kind.DUELIST or kind == Kind.BOSS or kind == Kind.CONSTRUCT or kind == Kind.DUMMY:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 64 if kind == Kind.BOSS else 42
		label.position = Vector3(0, tall + radius + 0.7, 0)
		label.modulate = Color("2e4048")
		label.outline_modulate = Color("f4efe4")
		label.outline_size = 8
		label.no_depth_test = true
		if kind == Kind.DUELIST:
			label.text = "Mira\nEven crest" if Game.court_mode != "open" else "Mira\nOpen stand-in"
		elif kind == Kind.BOSS:
			label.text = "Wood Warden"
		elif kind == Kind.DUMMY:
			label.text = "Practice post"
		else:
			label.text = "Construct"
		add_child(label)
	bar = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.15, 0.12)
	bar.mesh = quad
	bar.position = Vector3(0, tall + radius + 0.2, 0)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_mat.albedo_color = Color("57af70")
	bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar.material_override = bar_mat
	add_child(bar)
	if kind == Kind.DUMMY:
		bar.visible = false

func _capsule(radius: float, tall: float, at: Vector3, color: Color) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = tall
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	body_mat = _matte(color)
	inst.material_override = body_mat
	add_child(inst)

func _orb(at: Vector3, radius: float, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	var material := _matte(color)
	inst.material_override = material
	if body_mat == null:
		body_mat = material
	add_child(inst)

func _box(box_size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	var material := _matte(color)
	if color == Color("e2c56a") or color == Color("d4a054") or color == Color("d5dbe0"):
		material.metallic = 0.6
		material.roughness = 0.35
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.25
	inst.material_override = material
	if body_mat == null:
		body_mat = material
	add_child(inst)

func _matte(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	return material

func _physics_process(delta: float) -> void:
	if not alive or kind == Kind.DUMMY:
		return
	attack_wait = maxf(attack_wait - delta, 0.0)
	var target := _local_student()
	var velocity_flat := Vector3.ZERO
	var dest := Vector3.ZERO
	var chasing := false
	if target:
		var to: Vector3 = target.global_position - global_position
		to.y = 0
		var reach := 12.0
		if kind == Kind.DUELIST:
			reach = 40.0
		elif kind == Kind.BOSS:
			reach = 24.0
		elif kind == Kind.SPIRIT:
			reach = 9.0
		if to.length() <= 1.5:
			_try_attack(target)
		elif to.length() < reach and (global_position.distance_to(home) < leash or to.length() < 7.0):
			dest = to.normalized()
			chasing = true
	if not chasing:
		if kind == Kind.BOSS:
			var wander := Time.get_ticks_msec() * 0.001
			var roam := home + Vector3(sin(wander * 0.25) * 5.0, 0, cos(wander * 0.25) * 5.0)
			var back: Vector3 = roam - global_position
			back.y = 0
			if back.length() > 0.45:
				dest = back.normalized()
				chasing = true
		elif global_position.distance_to(home) > 1.3:
			var back_home: Vector3 = home - global_position
			back_home.y = 0
			if back_home.length() > 0.2:
				dest = back_home.normalized()
				chasing = true
	if chasing and dest.length() > 0.1:
		velocity_flat = dest * speed
		look_at(global_position + dest, Vector3.UP)
	velocity.x = velocity_flat.x
	velocity.z = velocity_flat.z
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -1.0
	move_and_slide()

func _try_attack(target: Node3D) -> void:
	if attack_wait > 0.0:
		return
	attack_wait = 0.95 if kind != Kind.BOSS else 1.2
	if target.has_method("hurt"):
		target.hurt(attack_damage)

func take_hit(amount: float, kind_name: String) -> void:
	if not alive:
		return
	if kind == Kind.DUMMY:
		_flash()
		Game.note_dummy_hit(kind_name)
		return
	Game.note_fight(kind_name)
	hp = maxf(hp - amount, 0.0)
	_flash()
	var ratio := hp / max_hp
	bar.scale = Vector3(maxf(ratio, 0.05), 1, 1)
	if hp <= 0.0:
		alive = false
		died.emit(self)
		queue_free()

func _flash() -> void:
	if body_mat:
		body_mat.emission_enabled = true
		body_mat.emission = Color("fff4d2")
		body_mat.emission_energy_multiplier = 0.8
		var timer := get_tree().create_timer(0.12)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(body_mat):
				body_mat.emission_enabled = false
		)

func _local_student() -> Node3D:
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_meta("local", false):
			return node as Node3D
	return null
