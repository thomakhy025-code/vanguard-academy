extends Node

func broadcast_state(pos: Vector3, yaw: float, life: float) -> void:
	if not Online.active:
		return
	relay.rpc(pos, yaw, life)

func send_hit(target_name: String, amount: float) -> void:
	if not Online.active:
		return
	strike.rpc(target_name, amount)

@rpc("any_peer", "unreliable")
func relay(pos: Vector3, yaw: float, life: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var ghost := get_parent().get_node_or_null("Peer%d" % sender)
	if ghost and ghost.has_method("apply_net") and not ghost.get_meta("local", false):
		ghost.apply_net(pos, yaw, life)

@rpc("any_peer", "reliable")
func strike(target_name: String, amount: float) -> void:
	var node := get_parent().get_node_or_null(target_name)
	if node and node.get_meta("local", false) and node.has_method("hurt"):
		node.hurt(amount)
