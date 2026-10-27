extends Node
## Autoload. Versioned local settings, input map setup and tiny i18n (pt_BR / en / es).

const SAVE_PATH := "user://settings.cfg"
const SAVE_VERSION := 1
const LANGS := ["pt_BR", "en", "es"]
const DEFAULTS := {
	"quality": 1, "fps_limit": 60, "shadows": true, "volume": 0.8,
	"look_sens": 0.5, "touch_sens": 0.5, "language": "pt_BR",
	"vibration": true, "ui_scale": 1.0,
}
# "pt|en|es"
const TEXT := {
	"play": "JOGAR|PLAY|JUGAR", "config": "CONFIG|CONFIG|CONFIG", "quit": "SAIR|QUIT|SALIR",
	"back": "VOLTAR|BACK|VOLVER", "loading": "Carregando...|Loading...|Cargando...",
	"resume": "CONTINUAR|RESUME|CONTINUAR", "restart": "REINICIAR|RESTART|REINICIAR",
	"menu": "MENU PRINCIPAL|MAIN MENU|MENÚ PRINCIPAL", "jump": "PULAR|JUMP|SALTAR",
	"run": "CORRER|RUN|CORRER", "noise": "RUÍDO|NOISE|RUIDO", "cam": "CÂM|CAM|CÁM",
	"npc_limit": "Limite de NPCs atingido|NPC limit reached|Límite de NPCs alcanzado",
	"s_quality": "Qualidade gráfica|Graphics quality|Calidad gráfica",
	"q_levels": "Baixa/Média/Alta|Low/Medium/High|Baja/Media/Alta",
	"s_fps": "Limite de FPS|FPS limit|Límite de FPS", "s_shadows": "Sombras|Shadows|Sombras",
	"s_volume": "Volume|Volume|Volumen", "s_look": "Sensib. câmera (mouse)|Camera sens. (mouse)|Sensib. cámara (ratón)",
	"s_touch": "Sensib. toque|Touch sensitivity|Sensib. táctil", "s_lang": "Idioma|Language|Idioma",
	"s_vib": "Vibração|Vibration|Vibración", "s_ui": "Escala da UI|UI scale|Escala de UI",
}
var data: Dictionary = {}

func _ready() -> void:
	_setup_input()
	load_settings()
	apply()

func load_settings() -> void:
	data = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return # first run or unreadable file -> safe defaults
	if int(cfg.get_value("meta", "version", 0)) != SAVE_VERSION:
		return # unknown version -> defaults (add migrations here later)
	for k in DEFAULTS:
		var v = cfg.get_value("settings", k, DEFAULTS[k])
		if typeof(v) == typeof(DEFAULTS[k]):
			data[k] = v

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	for k in data:
		cfg.set_value("settings", k, data[k])
	cfg.save(SAVE_PATH)

func apply() -> void:
	Engine.max_fps = int(data.fps_limit)
	var win := get_tree().root
	win.scaling_3d_scale = [0.6, 0.8, 1.0][clampi(int(data.quality), 0, 2)]
	win.content_scale_factor = float(data.ui_scale)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(0.0001, float(data.volume))))

func t(key: String) -> String:
	var parts: PackedStringArray = String(TEXT.get(key, key)).split("|")
	var i: int = LANGS.find(data.get("language", "pt_BR"))
	return parts[i] if i >= 0 and i < parts.size() else parts[0]

func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "pause": [KEY_ESCAPE],
		"spawn_npc": [KEY_N], "noise": [KEY_G], "knockout": [KEY_K],
		"camera": [KEY_C], "reset": [KEY_R],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
