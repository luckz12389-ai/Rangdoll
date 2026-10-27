extends CharacterBody3D
## NPC with a finite-state machine: emotion (CALM / ANXIOUS / FEARFUL) driven by a
## continuous `fear` value, plus an independent `unconscious` physical condition.
## Ragdoll here is a PLACEHOLDER single-capsule RigidBody3D (see README, Phase 2).

enum Emotion { CALM, ANXIOUS, FEARFUL }
const NAMES := ["CALM", "ANXIOUS", "FEARFUL"]
const COLORS := [Color(0.3, 0.8, 0.4), Color(0.95, 0.8, 0.2), Color(0.9, 0.25, 0.25)]
const LIMIT := 42.0

var emotion: int = Emotion.CALM
var unconscious := false
var fear := 0.0
var home := Vector3.ZERO
var target := Vector3.ZERO
var threat_pos := Vector3.ZERO
var moving := false
var _timer := 0.0
var _ko_time := 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _label: Label3D
var _col: CollisionShape3D
var _ragdoll: RigidBody3D

func _ready() -> void:
	add_to_group("npc")
	collision_layer = 4
	collision_mask = 1 | 2
	_col = CollisionShape3D.new()
	_col.shape = _capsule()
	_col.position.y = 0.9
	add_child(_col)
	_mesh = MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.8
	_mesh.mesh = cm
	_mesh.position.y = 0.9
	_mat = StandardMaterial3D.new()
	_mesh.material_override = _mat
	add_child(_mesh)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.005
	_label.font_size = 48
	_label.position.y = 2.3
	add_child(_label)
	_refresh_visuals()

func _capsule() -> CapsuleShape3D:
	var c := CapsuleShape3D.new()
	c.radius = 0.35
	c.height = 1.8
	return c

# ---------- events ----------
## Called by game via call_group("npc", "hear_event", pos, loudness, radius).
func hear_event(pos: Vector3, loudness: float, radius: float) -> void:
	if unconscious:
		return
	var d := global_position.distance_to(pos)
	if d > radius:
		return
	fear = minf(1.0, fear + loudness * (1.0 - d / radius) + 0.15)
	threat_pos = pos
	_timer = 0.0

func knock_out(duration := 6.0, impulse := Vector3.ZERO) -> void:
	if unconscious:
		return
	unconscious = true
	_ko_time = duration
	_ragdoll = RigidBody3D.new()
	_ragdoll.collision_layer = 8
	_ragdoll.collision_mask = 1 | 8
	_ragdoll.mass = 70.0
	_ragdoll.linear_damp = 0.4
	_ragdoll.angular_damp = 1.5
	_ragdoll.continuous_cd = true
	var cs := CollisionShape3D.new()
	cs.shape = _capsule()
	_ragdoll.add_child(cs)
	get_parent().add_child(_ragdoll)
	_ragdoll.global_transform = Transform3D(global_transform.basis, global_position + Vector3(0, 0.9, 0))
	_mesh.reparent(_ragdoll, true)
	_col.set_deferred("disabled", true)
	_ragdoll.apply_central_impulse(impulse + Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1)))
	_ragdoll.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	_refresh_visuals()
	# nearby NPCs witness it
	get_tree().call_group("npc", "hear_event", global_position, 0.5, 12.0)

func _recover() -> void:
	var p := _ragdoll.global_position
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -5, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var gy: float = hit.position.y if hit else 0.0
	_mesh.reparent(self, false)
	_mesh.transform = Transform3D(Basis(), Vector3(0, 0.9, 0))
	_ragdoll.queue_free()
	_ragdoll = null
	global_position = Vector3(p.x, gy + 0.05, p.z) # raycast placement avoids floor clipping
	rotation = Vector3(0, rotation.y, 0)
	velocity = Vector3.ZERO
	_col.set_deferred("disabled", false)
	unconscious = false
	fear = 0.5 # wakes up shaken
	_timer = 0.0
	_refresh_visuals()

# ---------- FSM ----------
func _update_emotion() -> void:
	var old := emotion
	match emotion:
		Emotion.CALM:
			if fear >= 0.6: emotion = Emotion.FEARFUL
			elif fear >= 0.25: emotion = Emotion.ANXIOUS
		Emotion.ANXIOUS:
			if fear >= 0.6: emotion = Emotion.FEARFUL
			elif fear < 0.12: emotion = Emotion.CALM
		Emotion.FEARFUL:
			if fear < 0.4: emotion = Emotion.ANXIOUS
	if old != emotion:
		_timer = 0.0
		_refresh_visuals()

func _refresh_visuals() -> void:
	if unconscious:
		_mat.albedo_color = Color(0.5, 0.5, 0.55)
		_label.text = "KO"
	else:
		_mat.albedo_color = COLORS[emotion]
		_label.text = NAMES[emotion]

func _think(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var pos := global_position
	match emotion:
		Emotion.CALM:
			moving = randf() < 0.7
			target = home + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
			_timer = randf_range(2.5, 6.0)
		Emotion.ANXIOUS:
			moving = randf() < 0.6
			target = pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			_timer = randf_range(0.7, 1.6)
		Emotion.FEARFUL:
			var away := Vector3(pos.x - threat_pos.x, 0, pos.z - threat_pos.z)
			if away.length() < 0.1:
				away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			target = pos + away.normalized() * 12.0
			moving = true
			_timer = 1.0
	target.x = clampf(target.x, -LIMIT, LIMIT)
	target.z = clampf(target.z, -LIMIT, LIMIT)

func _speed() -> float:
	return [1.4, 2.0, 5.0][emotion]

func _physics_process(delta: float) -> void:
	if unconscious:
		global_position = _ragdoll.global_position - Vector3(0, 0.9, 0)
		_ko_time -= delta
		var settled := _ragdoll.linear_velocity.length() < 0.8 and _ragdoll.angular_velocity.length() < 1.5
		if (_ko_time <= 0.0 and settled) or _ko_time < -8.0:
			_recover()
		return
	fear = maxf(0.0, fear - delta * 0.08)
	_update_emotion()
	_think(delta)
	var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var dir := Vector3.ZERO
	if moving and flat.length() > 0.4:
		dir = flat.normalized()
	velocity.x = dir.x * _speed()
	velocity.z = dir.z * _speed()
	velocity.y = 0.0 if is_on_floor() else velocity.y - 22.0 * delta
	move_and_slide()
	if dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
	elif emotion == Emotion.ANXIOUS: # nervous scanning
		rotation.y += sin(Time.get_ticks_msec() * 0.004 + float(get_instance_id() % 7)) * delta * 2.5
