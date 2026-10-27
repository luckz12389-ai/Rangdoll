extends CharacterBody3D
## Player: walk/run/jump, third/first person camera, touch + keyboard/mouse input.
## Collision layers: 1 world/props, 2 player, 4 NPC, 8 ragdoll.

const GRAVITY := 22.0
var touch = null # set by game.gd on touch devices
var running := false
var first_person := false
var yaw := 0.0
var pitch := -0.25
var model: Node3D
var spawn_point := Vector3(0, 0.1, 0)
var _pivot: Node3D
var _spring: SpringArm3D
var _jump_req := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	model = Node3D.new()
	add_child(model)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.8
	body.mesh = cm
	body.position.y = 0.9
	body.material_override = _mat(Color(0.2, 0.45, 0.9))
	model.add_child(body)
	var nose := MeshInstance3D.new() # placeholder: shows facing direction
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.2, 0.3)
	nose.mesh = bm
	nose.position = Vector3(0, 1.5, -0.35)
	nose.material_override = _mat(Color(1, 1, 1))
	model.add_child(nose)
	_pivot = Node3D.new()
	_pivot.position.y = 1.6
	add_child(_pivot)
	_spring = SpringArm3D.new()
	_spring.spring_length = 4.0
	_spring.margin = 0.3
	_spring.add_excluded_object(get_rid())
	_pivot.add_child(_spring)
	var cam := Camera3D.new()
	_spring.add_child(cam)
	cam.current = true

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func request_jump() -> void:
	_jump_req = true

func toggle_camera() -> void:
	first_person = not first_person
	_spring.spring_length = 0.0 if first_person else 4.0
	model.visible = not first_person

func reset_to_spawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO

func _look(rel: Vector2, base: float) -> void:
	yaw -= rel.x * base
	pitch = clampf(pitch - rel.y * base, -1.2, 0.7)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(e.relative, 0.003 * (0.4 + 1.2 * float(GameSettings.data.look_sens)))
	elif e.is_action_pressed("camera"):
		toggle_camera()

func _physics_process(delta: float) -> void:
	if touch:
		_look(touch.consume_look(), 0.004 * (0.4 + 1.2 * float(GameSettings.data.touch_sens)))
	_pivot.rotation = Vector3(pitch, yaw, 0.0)
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch and touch.move_vec != Vector2.ZERO:
		inp = touch.move_vec
	var dir := Basis(Vector3.UP, yaw) * Vector3(inp.x, 0.0, inp.y)
	var speed := 7.5 if (running or Input.is_action_pressed("sprint")) else 4.0
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = 0.0
		if _jump_req or Input.is_action_just_pressed("jump"):
			velocity.y = 6.5
	else:
		velocity.y -= GRAVITY * delta
	_jump_req = false
	if dir.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	move_and_slide()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var rb := c.get_collider() as RigidBody3D
		if rb:
			rb.apply_central_impulse(-c.get_normal() * 1.5)
	if global_position.y < -10.0:
		reset_to_spawn()
