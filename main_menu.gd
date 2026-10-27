extends Control
## Main menu: PLAY (threaded loading screen), CONFIG (saved settings), QUIT.

const GAME_SCENE := "res://game.tscn"
var _loading := false
var _bar: ProgressBar
var _center: Control
var _loadbox: Control
var _settings: Control
var _main: Control

func _ready() -> void:
	_build_ui(false)

func _build_ui(open_settings: bool) -> void:
	for c in get_children():
		c.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.set_default_font_size(30)
	theme = th
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_center = CenterContainer.new()
	add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 22)
	_center.add_child(_main)
	var title := Label.new()
	title.text = "RAGDOLL SANDBOX"
	title.add_theme_font_size_override("font_size", 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(title)
	_mkbtn(_main, GameSettings.t("play"), _on_play)
	_mkbtn(_main, GameSettings.t("config"), func(): _center.hide(); _settings.show())
	_mkbtn(_main, GameSettings.t("quit"), func(): get_tree().quit())

	_loadbox = VBoxContainer.new()
	_loadbox.visible = false
	_center.add_child(_loadbox)
	var ll := Label.new()
	ll.text = GameSettings.t("loading")
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loadbox.add_child(ll)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(600, 40)
	_loadbox.add_child(_bar)

	_settings = _build_settings()
	_settings.visible = open_settings
	_center.visible = not open_settings
	_main.modulate.a = 0.0
	create_tween().tween_property(_main, "modulate:a", 1.0, 0.6)

func _mkbtn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(440, 96)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _on_play() -> void:
	_main.hide()
	_loadbox.show()
	ResourceLoader.load_threaded_request(GAME_SCENE)
	_loading = true

func _process(_d: float) -> void:
	if not _loading:
		return
	var prog := []
	var st := ResourceLoader.load_threaded_get_status(GAME_SCENE, prog)
	if prog.size() > 0:
		_bar.value = prog[0] * 100.0
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		_loading = false
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(GAME_SCENE))
	elif st == ResourceLoader.THREAD_LOAD_FAILED:
		_loading = false
		_build_ui(false)

# ---------- settings panel ----------
func _build_settings() -> Control:
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 30)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	sc.add_child(list)
	_opt(list, "quality", "s_quality", GameSettings.t("q_levels").split("/"), [0, 1, 2])
	_opt(list, "fps_limit", "s_fps", ["30", "60", "90", "120"], [30, 60, 90, 120])
	_check(list, "shadows", "s_shadows")
	_slider(list, "volume", "s_volume", 0.0, 1.0, 0.05)
	_slider(list, "look_sens", "s_look", 0.0, 1.0, 0.05)
	_slider(list, "touch_sens", "s_touch", 0.0, 1.0, 0.05)
	_slider(list, "ui_scale", "s_ui", 0.75, 1.5, 0.05)
	_check(list, "vibration", "s_vib")
	_opt(list, "language", "s_lang", ["Português (BR)", "English", "Español"], ["pt_BR", "en", "es"])
	var back := Button.new()
	back.text = GameSettings.t("back")
	back.custom_minimum_size = Vector2(0, 90)
	back.pressed.connect(func():
		GameSettings.save_settings()
		_build_ui(false))
	vb.add_child(back)
	return panel

func _row(list: Control, key: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = GameSettings.t(key)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	list.add_child(h)
	return h

func _opt(list: Control, key: String, label: String, items: Array, values: Array) -> void:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(380, 70)
	for it in items:
		o.add_item(str(it))
	o.select(maxi(0, values.find(GameSettings.data[key])))
	o.item_selected.connect(func(i: int):
		GameSettings.data[key] = values[i]
		GameSettings.apply()
		if key == "language":
			GameSettings.save_settings()
			_build_ui.call_deferred(true))
	_row(list, label).add_child(o)

func _check(list: Control, key: String, label: String) -> void:
	var c := CheckButton.new()
	c.button_pressed = GameSettings.data[key]
	c.toggled.connect(func(on: bool): GameSettings.data[key] = on)
	_row(list, label).add_child(c)

func _slider(list: Control, key: String, label: String, lo: float, hi: float, step: float) -> void:
	var s := HSlider.new()
	s.custom_minimum_size = Vector2(380, 60)
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(GameSettings.data[key])
	s.value_changed.connect(func(v: float):
		GameSettings.data[key] = v
		GameSettings.apply())
	_row(list, label).add_child(s)
