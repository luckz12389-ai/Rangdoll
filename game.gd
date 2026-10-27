extends Node3D
## Sandbox test map + glue between player, touch UI, NPC spawning and pause menu.

const PlayerScript := preload("res://player.gd")
const NpcScript := preload("res://npc.gd")
const TouchScript := preload("res://touch_controls.gd")
const MAX_NPCS := 12
const ARENA := 45.0

var player
var _hud: Label
var _toast: Label
var _toast_t := 0.0
var _hud_t := 0.0
var _pause: CanvasLayer

func _ready() -> void:
	_build_world()
	player = PlayerScript.new()
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	_build_ui()
	if not _is_touch():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _is_touch() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

# ---------- world ----------
func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = bool(GameSettings.data.shadows) and int(GameSettings.data.quality) > 0
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var L := ARENA * 2.0 + 10.0
	_static_box(Vector3(L, 1, L), Vector3(0, -0.5, 0), Color(0.25, 0.3, 0.28))
	_static_box(Vector3(L, 4, 1), Vector3(0, 2, ARENA + 2), Color(0.4, 0.4, 0.45))
	_static_box(Vector3(L, 4, 1), Vector3(0, 2, -ARENA - 2), Color(0.4, 0.4, 0.45))
	_static_box(Vector3(1, 4, L), Vector3(ARENA + 2, 2, 0), Color(0.4, 0.4, 0.45))
	_static_box(Vector3(1, 4, L), Vector3(-ARENA - 2, 2, 0), Color(0.4, 0.4, 0.45))
	_static_box(Vector3(6, 1, 10), Vector3(15, 0.5, 5), Color(0.5, 0.35, 0.25))
	_static_box(Vector3(10, 2, 4), Vector3(-15, 1, -8), Color(0.35, 0.35, 0.5))
	for i in 12: # physics props
		var rb := RigidBody3D.new()
		rb.mass = 5.0
		rb.collision_mask = 15
		rb.position = Vector3(randf_range(-12, 12), 1.0 + i * 0.2, randf_range(-12, 12))
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.8, 0.8, 0.8)
		cs.shape = sh
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sh.size
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.from_hsv(randf(), 0.6, 0.9)
		mi.material_override = m
		rb.add_child(mi)
		add_child(rb)

func _static_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	b.add_child(mi)
	add_child(b)

# ---------- UI ----------
func _build_ui() -> void:
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)
	_hud = Label.new()
	_hud.position = Vector2(30, 20)
	hud_layer.add_child(_hud)
	_toast = Label.new()
	_toast.position = Vector2(30, 70)
	_toast.add_theme_font_size_override("font_size", 28)
	hud_layer.add_child(_toast)
	if _is_touch():
		var touch := TouchScript.new()
		add_child(touch)
		player.touch = touch
		touch.jump_pressed.connect(Callable(player, "request_jump"))
		touch.sprint_toggled.connect(func(on: bool): player.running = on)
		touch.camera_pressed.connect(Callable(player, "toggle_camera"))
		touch.spawn_npc_pressed.connect(spawn_npc)
		touch.noise_pressed.connect(make_noise)
		touch.knockout_pressed.connect(knock_out_nearest)
		touch.pause_pressed.connect(func(): _set_pause(true))
	else:
		_say("WASD move · Shift run · Space jump · C camera · N spawn NPC · G noise · K knock out · R reset · Esc pause")
	_build_pause()

func _build_pause() -> void:
	_pause = CanvasLayer.new()
	_pause.layer = 20
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.visible = false
	add_child(_pause)
	var root := Control.new()
	var th := Theme.new()
	th.set_default_font_size(30)
	root.theme = th
	_pause.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var c := CenterContainer.new()
	root.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	c.add_child(vb)
	_pbtn(vb, GameSettings.t("resume"), func(): _set_pause(false))
	_pbtn(vb, GameSettings.t("restart"), func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	_pbtn(vb, GameSettings.t("menu"), func():
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://main_menu.tscn"))

func _pbtn(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(440, 90)
	b.pressed.connect(cb)
	parent.add_child(b)

func _set_pause(on: bool) -> void:
	get_tree().paused = on
	_pause.visible = on
	if not _is_touch():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED

func _say(msg: String) -> void:
	_toast.text = msg
	_toast_t = 4.0

# ---------- sandbox actions ----------
func spawn_npc() -> void:
	if get_tree().get_nodes_in_group("npc").size() >= MAX_NPCS:
		_say(GameSettings.t("npc_limit"))
		return
	var fwd: Vector3 = -player.model.global_transform.basis.z
	var side := Vector3(fwd.z, 0, -fwd.x) * randf_range(-1.5, 1.5)
	var pos: Vector3 = player.global_position + fwd * 3.5 + side
	pos.x = clampf(pos.x, -40, 40)
	pos.z = clampf(pos.z, -40, 40)
	pos.y = 0.1
	var n = NpcScript.new()
	n.position = pos
	n.home = pos
	add_child(n)

func make_noise() -> void:
	get_tree().call_group("npc", "hear_event", player.global_position, 0.9, 25.0)
	if GameSettings.data.vibration:
		Input.vibrate_handheld(80)

func knock_out_nearest() -> void:
	var best = null
	var best_d := 10.0
	for n in get_tree().get_nodes_in_group("npc"):
		if n.unconscious:
			continue
		var d: float = n.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best:
		var fwd: Vector3 = -player.model.global_transform.basis.z
		best.knock_out(6.0, fwd * 250.0)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("spawn_npc"): spawn_npc()
	if Input.is_action_just_pressed("noise"): make_noise()
	if Input.is_action_just_pressed("knockout"): knock_out_nearest()
	if Input.is_action_just_pressed("pause"): _set_pause(true)
	if Input.is_action_just_pressed("reset"): player.reset_to_spawn()
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.25
		_hud.text = "FPS %d  |  NPCs %d/%d" % [Engine.get_frames_per_second(), get_tree().get_nodes_in_group("npc").size(), MAX_NPCS]
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
