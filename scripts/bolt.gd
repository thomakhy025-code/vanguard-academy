extends Node3D

var direction := Vector3.FORWARD
var life := 1.15
var speed := 16.0
var hit_radius := 1.15
var owner_path: NodePath

func _ready() -> void:
	var radius := 0.22
	if Game.shape_active() and Game.weapon == "lantern":
		radius = 0.34
		hit_radius = 1.7
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	mesh.mesh = ball
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9fd6ff")
	material.emission_enabled = true
	material.emission = Color("b9e4ff")
	material.emission_energy_multiplier = 1.4
	material.roughness = 0.35
	mesh.material_override = material
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color("9fd6ff")
	light.light_energy = 1.2
	light.omni_range = 3.2 if radius > 0.3 else 3.0
	light.shadow_enabled = false
	add_child(light)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var amount := Game.outgoing(false)
	for node in get_tree().get_nodes_in_group("foe"):
		if node.global_position.distance_to(global_position) < hit_radius:
			var hit := amount
			var foe_kind = node.kind
			if foe_kind == Foe.Kind.BEAST or foe_kind == Foe.Kind.ELITE or foe_kind == Foe.Kind.BOSS or foe_kind == Foe.Kind.SPIRIT:
				hit = Game.spirit_against_monsters(amount)
			node.take_hit(hit, "spell")
			queue_free()
			return
	if Online.active:
		var link := get_node_or_null("/root/Main/Net")
		if link:
			for node in get_tree().get_nodes_in_group("player"):
				if str(node.get_path()) == str(owner_path):
					continue
				if node.global_position.distance_to(global_position) < hit_radius:
					link.send_hit(str(node.name), amount)
					queue_free()
					return
