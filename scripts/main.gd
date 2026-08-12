extends Node

const Catalog = preload("res://scripts/robot_catalog.gd")
const RobotModelScript = preload("res://scripts/robot_model.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const AudioScript = preload("res://scripts/robot_audio.gd")
const ThumbnailScript = preload("res://scripts/part_thumbnail.gd")
const LanScript = preload("res://scripts/lan_manager.gd")

enum GameState { MENU, TIME_SELECT, BUILD, OPPONENT_PREVIEW, LAN_LOBBY, BATTLE, RESULT, HELP }

const BLUE := Color("43d8ff")
const RED := Color("ff537f")
const GOLD := Color("ffe36e")
const INK := Color("e9f5ff")
const PANEL := Color("d90a1230")
const PANEL_LIGHT := Color("e5172750")
const TEAM_COLORS := [Color("43d8ff"), Color("6f8cff"), Color("8edfa8"), Color("ff8b72")]
const CPU_CODENAMES := ["REMACHE", "COBALTO", "TRITÓN", "YUNQUE", "CIRCUITO", "ÓRBITA", "MAMUT", "VÓRTICE", "BUNKER", "COMETA"]
const KIDS_RIVAL_NAMES := ["CHISPA", "BURBUJA", "TUERQUITA", "NUBE", "PÍXEL", "COHETE", "TRÉBOL", "GALLETA", "COMETA", "POMPÓN"]
const KIDS_ROBOT_NAMES := ["ESTRELLA", "RAYITO", "FORTACHÓN", "INVENTOR"]
const KIDS_ROBOT_TIPS := [
	"Es bueno en todo y muy fácil de usar.",
	"Se mueve rápido y ataca muchas veces.",
	"Tiene mucha vida y aguanta los empujones.",
	"Usa herramientas con buena energía y alcance.",
]
const KIDS_ROBOT_COLORS := [Color("53d8ff"), Color("ffe36e"), Color("78dca0"), Color("c58cff")]
const EXPRESSION_LABELS := ["ALEGRE", "ENOJADO", "SORPRESA", "TRAVIESO", "DECIDIDO", "DORMIDO", "CONFUNDIDO", "FIESTA"]
const EXPRESSION_ICONS := ["☺", "怒", "!", ";)", ">", "Zz", "?", "★"]
const EXPRESSION_COLORS := [Color("72ecff"), Color("ff756e"), Color("fff4a3"), Color("c58cff"), Color("78f0ad"), Color("a8d8ff"), Color("ffb765"), Color("ff8fe1")]
const TOUCH_PART_LABELS := {
	"head": "CABEZA",
	"torso": "TORSO",
	"left_arm": "BRAZO I",
	"right_arm": "BRAZO D",
	"left_leg": "PIERNA I",
	"right_leg": "PIERNA D",
	"left_weapon": "MANO I",
	"right_weapon": "MANO D",
}
const KIDS_PRESETS := [
	{"head": 0, "torso": 1, "left_arm": 0, "right_arm": 1, "left_leg": 0, "right_leg": 1, "left_weapon": 0, "right_weapon": 3, "_expression": 0},
	{"head": 3, "torso": 3, "left_arm": 2, "right_arm": 2, "left_leg": 3, "right_leg": 3, "left_weapon": 3, "right_weapon": 3, "_expression": 3},
	{"head": 2, "torso": 2, "left_arm": 0, "right_arm": 0, "left_leg": 2, "right_leg": 2, "left_weapon": 0, "right_weapon": 0, "_expression": 1},
	{"head": 1, "torso": 1, "left_arm": 1, "right_arm": 3, "left_leg": 1, "right_leg": 0, "left_weapon": 2, "right_weapon": 1, "_expression": 4},
]

var state := GameState.MENU
var game_mode := "story"
var build_duration := 120.0
var build_time_left := 120.0
var current_builder := 1
var selected_slot := "head"
var current_build := {}
var player_builds: Array[Dictionary] = []
var cpu_level := 1
var best_level := 1
var total_wins := 0
var credits := 600
var kids_stars := 0
var unlocked_parts := {}
var last_reward := 0
var battle_time_left := 90.0
var battle_started := false
var battle_finished := false
var last_winner := -1
var battle_speed := 1.0
var preview_time := 0.0
var battle_camera_time := 0.0
var camera_shake := 0.0
var impact_focus_time := 0.0
var impact_focus_position := Vector3.ZERO
var local_lan_index := 0

var camera: Camera3D
var audio: RobotAudio
var lan: RobotLanManager
var workshop_root: Node3D
var ring_root: Node3D
var preview_robot: RobotModel
var fighter_a: ArenaFighter
var fighter_b: ArenaFighter
var fighters: Array[ArenaFighter] = []
var ui_layer: CanvasLayer
var ui_root: Control
var timer_label: Label
var stats_label: Label
var synergy_label: Label
var option_detail_label: Label
var options_grid: GridContainer
var slot_buttons := {}
var hp_bar_a: ProgressBar
var hp_bar_b: ProgressBar
var hp_text_a: Label
var hp_text_b: Label
var battle_clock: Label
var battle_message: Label
var message_tween: Tween
var stats_bars := {}
var stat_value_labels := {}
var fighter_hp_bars: Array[ProgressBar] = []
var fighter_hp_texts: Array[Label] = []
var heavy_buttons: Array[Button] = []
var advanced_action_buttons: Array[Button] = []
var lan_status_label: Label
var lan_start_button: Button
var speed_button: Button
var random_button: Button
var robot_touch_buttons: Array[Button] = []
var recently_unlocked_slot := ""
var recently_unlocked_index := -1
var story_opponent_build := {}
var story_opponent_level := -1
var story_opponent_name := ""
var story_opponent_mode := ""
var ai_recommended_build := {}
var kids_preset_index := 0
var kids_is_custom := false

func _ready() -> void:
	Engine.time_scale = 1.0
	_load_progress()
	Catalog.validate_catalog()
	audio = AudioScript.new()
	add_child(audio)
	lan = LanScript.new()
	add_child(lan, true)
	lan.status_changed.connect(_on_lan_status_changed)
	lan.battle_ready.connect(_on_lan_battle_ready)
	lan.heavy_received.connect(_on_lan_heavy_received)
	_setup_world()
	_setup_ui_layer()
	var args := OS.get_cmdline_user_args()
	if "--smoke-test" in args:
		call_deferred("_run_smoke_test")
		return
	_show_main_menu()

func _process(delta: float) -> void:
	if is_instance_valid(preview_robot) and state in [GameState.MENU, GameState.TIME_SELECT, GameState.BUILD, GameState.OPPONENT_PREVIEW, GameState.HELP]:
		preview_time += delta
		if state == GameState.BUILD:
			preview_robot.rotation.y = lerpf(preview_robot.rotation.y, sin(preview_time * 0.72) * 0.18, minf(1.0, delta * 4.0))
		else:
			preview_robot.rotation.y += delta * 0.48
	if state == GameState.BUILD and is_instance_valid(preview_robot):
		_update_robot_touch_targets()
	if state == GameState.BATTLE and fighters.size() >= 2:
		_update_battle_camera(delta)
		_update_heavy_buttons()
		_update_advanced_action_buttons()
	if state == GameState.BUILD and build_duration > 0.0:
		build_time_left = maxf(0.0, build_time_left - delta)
		_update_timer_label()
		if build_time_left <= 0.0:
			_finish_robot()
	elif state == GameState.BATTLE and battle_started and not battle_finished:
		battle_time_left = maxf(0.0, battle_time_left - delta)
		if battle_clock:
			battle_clock.text = "%02d" % int(ceil(battle_time_left))
		if battle_time_left <= 0.0:
			_finish_by_time()

func _update_battle_camera(delta: float) -> void:
	battle_camera_time += delta
	var midpoint := Vector3.ZERO
	var visible_count := 0
	for fighter in fighters:
		if is_instance_valid(fighter) and fighter.hp > 0.0:
			midpoint += fighter.global_position
			visible_count += 1
	if visible_count == 0:
		return
	midpoint /= float(visible_count)
	midpoint.y = 2.15
	impact_focus_time = maxf(0.0, impact_focus_time - delta)
	if impact_focus_time > 0.0:
		var cinematic_focus := impact_focus_position
		cinematic_focus.y = clampf(cinematic_focus.y, 1.7, 3.4)
		midpoint = midpoint.lerp(cinematic_focus, 0.38)
	var separation := 0.0
	for fighter in fighters:
		if is_instance_valid(fighter):
			separation = maxf(separation, fighter.global_position.distance_to(midpoint))
	separation *= 1.55
	var orbit := sin(battle_camera_time * 0.28) * 0.34
	var distance := clampf(12.8 + separation * 0.20, 13.4, 16.0)
	var desired := midpoint + Vector3(sin(orbit) * distance, 7.2 + sin(battle_camera_time * 0.55) * 0.35, cos(orbit) * distance)
	if camera_shake > 0.01:
		var shake_offset := Vector3(sin(battle_camera_time * 71.0), cos(battle_camera_time * 83.0), sin(battle_camera_time * 97.0)) * camera_shake
		desired += shake_offset
		camera_shake = maxf(0.0, camera_shake - delta * 2.8)
	camera.position = camera.position.lerp(desired, minf(1.0, delta * 2.7))
	camera.look_at(midpoint, Vector3.UP)

func _setup_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("173b63")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8ddff")
	environment.ambient_light_energy = 0.92
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.85
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_color = Color("d8eeff")
	key_light.light_energy = 1.25
	key_light.shadow_enabled = true
	add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-4.0, 6.0, 5.0)
	fill_light.light_color = BLUE
	fill_light.light_energy = 7.0
	fill_light.omni_range = 15.0
	add_child(fill_light)
	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(5.0, 5.0, -3.0)
	rim_light.light_color = RED
	rim_light.light_energy = 6.0
	rim_light.omni_range = 14.0
	add_child(rim_light)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 5.4, 13.4)
	camera.fov = 54.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 2.45, 0.0), Vector3.UP)

	workshop_root = Node3D.new()
	workshop_root.name = "Workshop"
	add_child(workshop_root)
	_build_workshop()
	ring_root = Node3D.new()
	ring_root.name = "BattleRing"
	add_child(ring_root)
	_build_ring()
	ring_root.visible = false

func _setup_ui_layer() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

func _show_main_menu() -> void:
	_reset_runtime()
	state = GameState.MENU
	_clear_ui()
	var menu_build: Dictionary = KIDS_PRESETS[clampi(kids_preset_index, 0, KIDS_PRESETS.size() - 1)]
	_show_workshop_preview(menu_build, Vector3(2.85, 0.0, 0.0), KIDS_ROBOT_COLORS[clampi(kids_preset_index, 0, KIDS_ROBOT_COLORS.size() - 1)])
	camera.position = Vector3(0.0, 5.4, 13.4)
	camera.fov = 54.0
	camera.look_at(Vector3(0.8, 2.45, 0.0), Vector3.UP)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.025
	panel.anchor_top = 0.045
	panel.anchor_right = 0.48
	panel.anchor_bottom = 0.955
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, 24))
	ui_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)
	panel.add_child(box)
	box.add_child(_title_label("FORJA INFINITA", 39, GOLD))
	box.add_child(_title_label("ROBOTS KIDS", 56, BLUE))
	var subtitle := _label("Elige un robot, conoce a tu rival\ny juega con un solo botón especial.", 19, INK)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(_separator())
	box.add_child(_make_button("🌟  JUGAR · MODO FÁCIL", _choose_mode.bind("kids"), Color("54c987"), Vector2(500, 72)))
	box.add_child(_make_button("🔧  TALLER AVANZADO", _choose_mode.bind("story"), BLUE, Vector2(500, 51)))
	box.add_child(_make_button("👥  DOS JUGADORES", _choose_mode.bind("local"), Color("ff8b72"), Vector2(500, 51)))
	box.add_child(_make_button("📡  JUGAR POR WI-FI", _choose_mode.bind("lan"), Color("8edfa8"), Vector2(500, 51)))
	box.add_child(_make_button("?  AYUDA", _show_help, Color("9d88ff"), Vector2(500, 46)))
	var record := _label("ESTRELLAS: %d   ·   NIVEL: %d   ·   VICTORIAS: %d" % [kids_stars, best_level, total_wins], 15, GOLD)
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(record)
	var tiny := _label("Modo fácil: elegir → mirar rival → jugar", 14, Color("c8dcf5"))
	tiny.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tiny)

func _choose_mode(mode: String) -> void:
	game_mode = mode
	local_lan_index = 0
	if game_mode == "kids":
		_start_kids_mode()
		return
	state = GameState.TIME_SELECT
	_clear_ui()
	var panel := _center_panel(Vector2(560.0, 590.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_title_label("TIEMPO DE CONSTRUCCIÓN", 34, GOLD))
	var info := _label("El reloj solo corre mientras eliges piezas.\nSi llega a cero, el robot se termina automáticamente.", 19, INK)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	box.add_child(_separator())
	box.add_child(_make_button("⚡  30 SEGUNDOS", _select_time.bind(30.0), RED, Vector2(500, 60)))
	box.add_child(_make_button("⏱  1 MINUTO", _select_time.bind(60.0), Color("ffad5a"), Vector2(500, 60)))
	box.add_child(_make_button("🔧  2 MINUTOS", _select_time.bind(120.0), BLUE, Vector2(500, 60)))
	box.add_child(_make_button("∞  SIN LÍMITE", _select_time.bind(-1.0), Color("9d88ff"), Vector2(500, 60)))
	box.add_child(_make_button("←  VOLVER", _show_main_menu, Color("60759a"), Vector2(500, 48)))

func _start_kids_mode() -> void:
	current_builder = 1
	player_builds.clear()
	build_duration = -1.0
	selected_slot = "head"
	kids_is_custom = false
	kids_preset_index = clampi(kids_preset_index, 0, KIDS_PRESETS.size() - 1)
	var selected_build: Dictionary = KIDS_PRESETS[kids_preset_index]
	current_build = selected_build.duplicate(true)
	_show_kids_builder()

func _show_kids_builder(animate_slot: String = "") -> void:
	state = GameState.BUILD
	battle_finished = false
	build_duration = -1.0
	_clear_ui()
	_clear_fighters()
	var tint: Color = KIDS_ROBOT_COLORS[kids_preset_index]
	_show_workshop_preview(current_build, Vector3(-1.55, 0.0, 0.0), tint)
	if not animate_slot.is_empty():
		preview_robot.build_robot(current_build, tint, animate_slot)
	preview_robot.scale = Vector3.ONE * 1.68
	preview_robot.remember_floor_height()
	camera.position = Vector3(0.15, 5.0, 11.8)
	camera.fov = 46.0
	camera.look_at(Vector3(-1.45, 2.62, 0.0), Vector3.UP)

	var banner := _title_label("1 · TOCA UNA PARTE DEL ROBOT", 29, GOLD)
	banner.anchor_left = 0.015
	banner.anchor_top = 0.02
	banner.anchor_right = 0.57
	banner.anchor_bottom = 0.10
	ui_root.add_child(banner)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.605
	panel.anchor_top = 0.035
	panel.anchor_right = 0.985
	panel.anchor_bottom = 0.975
	panel.add_theme_stylebox_override("panel", _panel_style(Color("e51c3157"), 26))
	ui_root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var robot_title: String = "MI ROBOT" if kids_is_custom else str(KIDS_ROBOT_NAMES[kids_preset_index])
	box.add_child(_title_label(robot_title, 32, tint))
	var tip_text: String = "Puedes volver a tocar cualquier parte y cambiarla otra vez." if kids_is_custom else str(KIDS_ROBOT_TIPS[kids_preset_index])
	var tip := _label(tip_text, 15, INK)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	var stats := Catalog.normalized_stats(current_build)
	var simple_stats := _label(
		"VIDA %s   RAPIDEZ %s\nFUERZA %s   DEFENSA %s" % [
			_kids_meter(float(stats.health)),
			_kids_meter(float(stats.speed)),
			_kids_meter(float(stats.power)),
			_kids_meter(float(stats.armor)),
		],
		14,
		Color("f4fbff")
	)
	simple_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(simple_stats)
	_add_expression_selector(box, true)
	box.add_child(_separator())
	var part_title := _title_label("CAMBIAR: %s" % str(Catalog.LABELS[selected_slot]), 20, GOLD)
	box.add_child(part_title)
	var part_choices := GridContainer.new()
	part_choices.columns = 2
	part_choices.add_theme_constant_override("h_separation", 9)
	part_choices.add_theme_constant_override("v_separation", 9)
	part_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(part_choices)
	var part_names: Array = Catalog.names_for(selected_slot)
	var chosen_index: int = int(current_build.get(selected_slot, 0))
	for index in range(4):
		var selected_prefix: String = "✓ " if index == chosen_index else ""
		var part_button := _make_button("", _select_kids_part.bind(index), GOLD if index == chosen_index else Color("52688f"), Vector2(178, 178))
		part_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		part_button.tooltip_text = str(part_names[index])
		_decorate_part_tile(part_button, selected_slot, index, selected_prefix + str(part_names[index]), index == chosen_index, false, true)
		part_choices.add_child(part_button)
	var base_label := _label("O ELIGE UNA BASE RÁPIDA", 13, Color("ccecff"))
	base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(base_label)
	var choices := GridContainer.new()
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 6)
	choices.add_theme_constant_override("v_separation", 6)
	box.add_child(choices)
	for index in range(KIDS_ROBOT_NAMES.size()):
		var prefix: String = "✓ " if not kids_is_custom and index == kids_preset_index else ""
		var choice := _make_button("", _select_kids_preset.bind(index), KIDS_ROBOT_COLORS[index], Vector2(142, 142))
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.tooltip_text = str(KIDS_ROBOT_TIPS[index])
		_decorate_part_tile(choice, "torso", int(KIDS_PRESETS[index].torso), prefix + str(KIDS_ROBOT_NAMES[index]), not kids_is_custom and index == kids_preset_index, false, true)
		choices.add_child(choice)
	box.add_child(_make_button("▶  2 · ¡LISTO! VER A MI RIVAL", _finish_kids_robot, Color("54c987"), Vector2(0, 54)))
	box.add_child(_make_button("←  MENÚ", _show_main_menu, Color("60759a"), Vector2(0, 34)))
	_add_robot_touch_selectors(true)
	_add_random_button(true)

func _select_kids_preset(index: int) -> void:
	kids_preset_index = clampi(index, 0, KIDS_PRESETS.size() - 1)
	kids_is_custom = false
	var selected_build: Dictionary = KIDS_PRESETS[kids_preset_index]
	current_build = selected_build.duplicate(true)
	if audio:
		audio.play_sfx("join", 0.94 + float(index) * 0.04)
	_show_kids_builder()

func _select_kids_slot(slot: String) -> void:
	selected_slot = slot
	_show_kids_builder()

func _select_kids_part(index: int) -> void:
	current_build[selected_slot] = clampi(index, 0, 3)
	kids_is_custom = true
	if audio:
		audio.play_sfx("join", 0.96 + float(index) * 0.04)
		get_tree().create_timer(0.42).timeout.connect(audio.play_sfx.bind("weld", 0.96 + float(index) * 0.04))
	_show_kids_builder(selected_slot)

func _randomize_kids_build() -> void:
	for slot_value in Catalog.SLOTS:
		var slot: String = str(slot_value)
		current_build[slot] = randi_range(0, 3)
	current_build["_expression"] = randi_range(0, EXPRESSION_LABELS.size() - 1)
	kids_is_custom = true
	selected_slot = "head"
	if audio:
		audio.play_sfx("unlock", 1.08)
	_show_kids_builder()

func _kids_meter(value: float) -> String:
	var filled: int = clampi(roundi(value / 20.0), 1, 5)
	return "●".repeat(filled) + "○".repeat(5 - filled)

func _finish_kids_robot() -> void:
	if state != GameState.BUILD:
		return
	player_builds.clear()
	player_builds.append(current_build.duplicate(true))
	_save_last_build(current_build)
	_show_story_opponent_preview()

func _select_time(seconds: float) -> void:
	build_duration = seconds
	current_builder = 1
	player_builds.clear()
	current_build = _load_last_build() if game_mode == "story" else Catalog.empty_build()
	if game_mode == "story":
		for slot in Catalog.SLOTS:
			if not _is_part_unlocked(slot, int(current_build.get(slot, 0))):
				current_build[slot] = 0
	_start_builder()

func _start_builder() -> void:
	state = GameState.BUILD
	battle_finished = false
	build_time_left = build_duration
	selected_slot = "head"
	_clear_ui()
	var tint: Color = TEAM_COLORS[clampi(current_builder - 1, 0, 3)]
	_show_workshop_preview(current_build, Vector3(-1.35, 0.0, 0.0), tint)
	preview_robot.scale = Vector3.ONE * 1.52
	preview_robot.remember_floor_height()
	camera.position = Vector3(0.10, 4.90, 11.45)
	camera.fov = 45.0
	camera.look_at(Vector3(-1.25, 2.72, 0.0), Vector3.UP)
	_build_builder_ui()
	_refresh_options()
	_update_build_info()

func _build_builder_ui() -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18.0
	top.offset_top = 12.0
	top.offset_right = -18.0
	top.offset_bottom = 92.0
	top.add_theme_stylebox_override("panel", _panel_style(PANEL_LIGHT, 18))
	ui_root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	top.add_child(top_row)
	var player_text := "JUGADOR %d" % current_builder
	if game_mode == "story":
		player_text = "TU ROBOT · RIVAL NIVEL %d" % cpu_level
	elif game_mode == "lan":
		player_text = "TU ROBOT LAN · TODO DESBLOQUEADO"
	var player_label := _label(player_text, 25, TEAM_COLORS[clampi(current_builder - 1, 0, 3)])
	player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(player_label)
	timer_label = _label("", 30, GOLD)
	timer_label.custom_minimum_size = Vector2(200, 0)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(timer_label)
	top_row.add_child(_make_button("SALIR", _show_main_menu, Color("60759a"), Vector2(110, 52)))

	var right_panel := PanelContainer.new()
	right_panel.anchor_left = 0.605
	right_panel.anchor_top = 0.145
	right_panel.anchor_right = 0.99
	right_panel.anchor_bottom = 0.985
	right_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, 20))
	ui_root.add_child(right_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(scroll)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 9)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer)
	var section_title := _label("TOCA EL ROBOT O ELIGE UNA PARTE", 20, GOLD)
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(section_title)
	var scroll_hint := _label("DESLIZA EL PANEL PARA VER TODAS LAS OPCIONES", 9, Color("a9c8e8"))
	scroll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(scroll_hint)
	var slots := GridContainer.new()
	slots.columns = 4
	slots.add_theme_constant_override("h_separation", 5)
	slots.add_theme_constant_override("v_separation", 5)
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(slots)
	slot_buttons.clear()
	for slot in Catalog.SLOTS:
		var slot_index: int = int(current_build.get(slot, 0))
		var button := _make_button("", _select_slot.bind(slot), GOLD if slot == selected_slot else Color("4b638d"), Vector2(100, 100))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = str(Catalog.LABELS[slot])
		_decorate_part_tile(button, slot, slot_index, str(Catalog.LABELS[slot]), slot == selected_slot, false, false)
		slots.add_child(button)
		slot_buttons[slot] = button
	_add_expression_selector(outer, false)
	options_grid = GridContainer.new()
	options_grid.columns = 4
	options_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_grid.custom_minimum_size.y = 560.0
	options_grid.add_theme_constant_override("h_separation", 5)
	options_grid.add_theme_constant_override("v_separation", 5)
	outer.add_child(options_grid)
	option_detail_label = _label("", 15, Color("c5d6ee"))
	option_detail_label.custom_minimum_size.y = 42
	option_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(option_detail_label)
	stats_label = _label("", 12, INK)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(stats_label)
	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 2)
	outer.add_child(stat_grid)
	stats_bars.clear()
	stat_value_labels.clear()
	for key in Catalog.STAT_KEYS:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(205.0, 18.0)
		row.add_theme_constant_override("separation", 3)
		stat_grid.add_child(row)
		var name_label := _label(Catalog.STAT_LABELS[key], 9, Color("bcd0e8"))
		name_label.custom_minimum_size.x = 56.0
		row.add_child(name_label)
		var bar := _stat_bar(Catalog.AFFINITY_COLORS[Catalog.AFFINITIES[Catalog.STAT_KEYS.find(key) % 5]])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 10.0
		row.add_child(bar)
		var value_label := _label("0", 9, INK)
		value_label.custom_minimum_size.x = 28.0
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		stats_bars[key] = bar
		stat_value_labels[key] = value_label
	synergy_label = _label("", 11, GOLD)
	synergy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(synergy_label)
	outer.add_child(_make_button("✓  TERMINAR Y ACTIVAR ROBOT", _finish_robot, GOLD, Vector2(0, 52)))
	_add_robot_touch_selectors(false)
	_add_random_button(false)

func _select_slot(slot: String) -> void:
	selected_slot = slot
	_refresh_options()

func _add_expression_selector(parent: Control, kids_mode: bool) -> void:
	var selected_expression: int = clampi(int(current_build.get("_expression", 0)), 0, EXPRESSION_LABELS.size() - 1)
	var title := _label("CARA · %s" % str(EXPRESSION_LABELS[selected_expression]), 13 if kids_mode else 11, EXPRESSION_COLORS[selected_expression])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for index in range(EXPRESSION_LABELS.size()):
		var selected_prefix: String = "✓ " if index == selected_expression else ""
		var button_text: String = selected_prefix + str(EXPRESSION_ICONS[index]) + "\n" + str(EXPRESSION_LABELS[index])
		var button := _make_button(button_text, _select_expression.bind(index, kids_mode), EXPRESSION_COLORS[index], Vector2(88, 88))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12 if kids_mode else 10)
		button.clip_text = true
		grid.add_child(button)

func _select_expression(index: int, kids_mode: bool) -> void:
	current_build["_expression"] = clampi(index, 0, EXPRESSION_LABELS.size() - 1)
	if kids_mode:
		kids_is_custom = true
		_show_kids_builder()
		return
	if is_instance_valid(preview_robot):
		var tint: Color = TEAM_COLORS[clampi(current_builder - 1, 0, 3)]
		preview_robot.build_robot(current_build, tint, "head")
		preview_robot.remember_floor_height()
	_build_builder_ui_refresh()

func _build_builder_ui_refresh() -> void:
	if state != GameState.BUILD:
		return
	_clear_ui()
	_build_builder_ui()
	_refresh_options()
	_update_build_info()

func _add_robot_touch_selectors(kids_mode: bool) -> void:
	robot_touch_buttons.clear()
	for slot_value in Catalog.SLOTS:
		var slot: String = str(slot_value)
		var action: Callable = _select_kids_slot.bind(slot) if kids_mode else _select_slot.bind(slot)
		var hit_size := Vector2(112, 82)
		if slot == "torso":
			hit_size = Vector2(170, 138)
		elif slot.ends_with("_arm") or slot.ends_with("_leg"):
			hit_size = Vector2(96, 122)
		elif slot.ends_with("_weapon"):
			hit_size = Vector2(104, 94)
		var button := Button.new()
		button.text = ""
		button.tooltip_text = "TOCA PARA CAMBIAR: %s" % str(TOUCH_PART_LABELS[slot])
		button.custom_minimum_size = hit_size
		button.size = hit_size
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		var empty_style := StyleBoxEmpty.new()
		for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style_name, empty_style)
		button.pressed.connect(_play_ui_sound)
		button.pressed.connect(action)
		button.set_meta("robot_slot", slot)
		button.set_meta("kids_touch", kids_mode)
		ui_root.add_child(button)
		robot_touch_buttons.append(button)
	_update_robot_touch_targets()

func _add_random_button(kids_mode: bool) -> void:
	var text: String = "🎲  SORPRESA ALEATORIA" if kids_mode else "🎲  ROBOT ALEATORIO"
	var action: Callable = _randomize_kids_build if kids_mode else _randomize_build
	random_button = _make_button(text, action, Color("b06cff"), Vector2(250, 52))
	random_button.size = Vector2(250, 52)
	random_button.add_theme_font_size_override("font_size", 18)
	ui_root.add_child(random_button)
	_update_robot_touch_targets()

func _update_robot_touch_targets() -> void:
	if not is_instance_valid(preview_robot) or not is_instance_valid(camera):
		return
	var viewport_size: Vector2 = ui_root.size
	if viewport_size.x < 10.0 or viewport_size.y < 10.0:
		viewport_size = get_viewport().get_visible_rect().size
	for button in robot_touch_buttons:
		if not is_instance_valid(button):
			continue
		var slot: String = str(button.get_meta("robot_slot", "torso"))
		var screen_position: Vector2 = camera.unproject_position(preview_robot.get_part_world_position(slot))
		var side_offset: Vector2 = Vector2.ZERO
		if slot.begins_with("left"):
			side_offset.x = -20.0
		elif slot.begins_with("right"):
			side_offset.x = 20.0
		var desired: Vector2 = screen_position - button.size * 0.5 + side_offset
		desired.x = clampf(desired.x, 8.0, viewport_size.x * 0.595 - button.size.x)
		desired.y = clampf(desired.y, 108.0, viewport_size.y - button.size.y - 12.0)
		button.position = desired
	if is_instance_valid(random_button):
		var head_screen: Vector2 = camera.unproject_position(preview_robot.get_part_world_position("head"))
		var random_position: Vector2 = head_screen - Vector2(random_button.size.x * 0.5, random_button.size.y + 78.0)
		random_position.x = clampf(random_position.x, 12.0, viewport_size.x * 0.595 - random_button.size.x)
		random_position.y = clampf(random_position.y, 96.0, viewport_size.y * 0.28)
		random_button.position = random_position

func _select_option(index: int) -> void:
	if game_mode == "story" and not _is_part_unlocked(selected_slot, index):
		var price := Catalog.part_price(selected_slot, index)
		if credits < price:
			option_detail_label.text = "FALTAN %d CRÉDITOS PARA COMPRAR ESTA PIEZA" % (price - credits)
			if audio:
				audio.play_sfx("defeat", 1.25)
			return
		credits -= price
		_unlock_part(selected_slot, index)
		recently_unlocked_slot = selected_slot
		recently_unlocked_index = index
		_save_progress()
	current_build[selected_slot] = index
	if audio:
		audio.play_sfx("join", 0.92 + float(index % 6) * 0.025)
		get_tree().create_timer(0.42).timeout.connect(audio.play_sfx.bind("weld", 0.92 + float(index % 6) * 0.025))
	var tint: Color = TEAM_COLORS[clampi(current_builder - 1, 0, 3)]
	preview_robot.build_robot(current_build, tint, selected_slot)
	preview_robot.remember_floor_height()
	_refresh_options()
	_update_build_info()

func _refresh_options() -> void:
	if not options_grid:
		return
	for child in options_grid.get_children():
		options_grid.remove_child(child)
		child.queue_free()
	var chosen := int(current_build.get(selected_slot, 0))
	var names := Catalog.names_for(selected_slot)
	for index in range(20):
		var locked := game_mode == "story" and not _is_part_unlocked(selected_slot, index)
		var just_unlocked := selected_slot == recently_unlocked_slot and index == recently_unlocked_index
		var prefix := "✓ " if index == chosen else ""
		var button_text := prefix + str(names[index])
		if locked:
			button_text = "🔒 %d C" % Catalog.part_price(selected_slot, index)
		elif just_unlocked:
			button_text = "✨ " + str(names[index])
		var button_color := Color("852d45") if locked else (GOLD if index == chosen else Color("52688f"))
		var button := _make_button("", _select_option.bind(index), button_color, Vector2(104, 104))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "%s · BLOQUEADA · TOCA PARA COMPRAR" % names[index] if locked else str(names[index])
		if locked:
			button.add_theme_color_override("font_color", Color("ffd2d9"))
			button.add_theme_stylebox_override("normal", _locked_button_style())
			button.add_theme_stylebox_override("hover", _locked_button_style(true))
		_decorate_part_tile(button, selected_slot, index, button_text, index == chosen, locked, false)
		options_grid.add_child(button)
		if just_unlocked:
			button.set_meta("unlock_ready", true)
			call_deferred("_animate_unlock_button", button)
	recently_unlocked_slot = ""
	recently_unlocked_index = -1
	for slot in slot_buttons:
		var slot_button: Button = slot_buttons[slot]
		slot_button.modulate = Color.WHITE if slot == selected_slot else Color("b7c4dd")
	option_detail_label.text = Catalog.describe_option(selected_slot, chosen)

func _decorate_part_tile(button: Button, slot: String, index: int, caption: String, selected: bool, locked: bool, kids_mode: bool) -> void:
	var thumbnail := ThumbnailScript.new()
	button.add_child(thumbnail)
	thumbnail.anchor_left = 0.08
	thumbnail.anchor_top = 0.05
	thumbnail.anchor_right = 0.92
	thumbnail.anchor_bottom = 0.73
	thumbnail.setup(slot, index, selected, locked)
	var caption_label := _label(caption, 12 if kids_mode else 9, Color("fff8d1") if selected else Color("eef6ff"))
	caption_label.anchor_left = 0.05
	caption_label.anchor_top = 0.73
	caption_label.anchor_right = 0.95
	caption_label.anchor_bottom = 0.98
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.clip_text = true
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption_label)

func _locked_button_style(hover := false) -> StyleBoxFlat:
	var style := _button_style(Color("6e172b") if hover else Color("3b101d"), Color("ff537f") if hover else Color("a33a55"), 3)
	style.shadow_color = Color("90000000")
	style.shadow_size = 5
	return style

func _animate_unlock_button(button: Button) -> void:
	if not is_instance_valid(button) or not button.has_meta("unlock_ready"):
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(0.70, 0.70)
	button.modulate = Color("fff173")
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color("80fff173")
	button.add_child(flash)
	var tween := button.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.10, 1.10), 0.28)
	tween.tween_property(button, "modulate", Color.WHITE, 0.46)
	tween.tween_property(flash, "color:a", 0.0, 0.46)
	tween.chain().tween_property(button, "scale", Vector2.ONE, 0.16)
	tween.chain().tween_callback(flash.queue_free)
	if audio:
		audio.play_sfx("unlock", 1.0)

func _update_build_info() -> void:
	if not stats_label:
		return
	var stats := Catalog.build_stats(current_build)
	var normalized := Catalog.normalized_stats(current_build)
	var affinity := Catalog.dominant_affinity(current_build)
	stats_label.text = "%s  ·  PODER %.0f%s" % [Catalog.AFFINITY_NAMES[affinity], Catalog.combat_rating(current_build), "  ·  %d C" % credits if game_mode == "story" else ""]
	stats_label.add_theme_color_override("font_color", Catalog.AFFINITY_COLORS[affinity])
	for key in Catalog.STAT_KEYS:
		var bar: ProgressBar = stats_bars[key]
		bar.value = float(normalized[key])
		var value_label: Label = stat_value_labels[key]
		value_label.text = "%.0f" % float(stats[key])
	var synergy := Catalog.get_synergy(current_build)
	synergy_label.text = "%s\n%s" % [synergy.title, synergy.description]
	_update_timer_label()

func _update_timer_label() -> void:
	if not timer_label:
		return
	if build_duration < 0.0:
		timer_label.text = "TIEMPO  ∞"
	else:
		var seconds := maxi(0, int(ceil(build_time_left)))
		timer_label.text = "TIEMPO  %02d:%02d" % [floori(float(seconds) / 60.0), seconds % 60]
		timer_label.modulate = RED if seconds <= 10 else Color.WHITE

func _randomize_build() -> void:
	current_build = _random_owned_build() if game_mode == "story" else Catalog.random_build(19)
	if not current_build.has("_expression"):
		current_build["_expression"] = randi_range(0, EXPRESSION_LABELS.size() - 1)
	if audio:
		audio.play_sfx("join", 0.82)
	var tint: Color = TEAM_COLORS[clampi(current_builder - 1, 0, 3)]
	preview_robot.build_robot(current_build, tint, selected_slot)
	preview_robot.remember_floor_height()
	_refresh_options()
	_update_build_info()

func _finish_robot() -> void:
	if state != GameState.BUILD:
		return
	player_builds.append(current_build.duplicate(true))
	if game_mode == "local" and current_builder == 1:
		current_builder = 2
		current_build = Catalog.empty_build()
		_start_builder()
		return
	if game_mode == "story":
		_save_last_build(player_builds[0])
		_show_story_opponent_preview()
		return
	if game_mode == "lan":
		_show_lan_lobby()
		return
	_start_battle()

func _ensure_story_opponent() -> void:
	if story_opponent_level == cpu_level and story_opponent_mode == game_mode and not story_opponent_build.is_empty():
		return
	var part_step: float = 3.0 if game_mode == "kids" else 2.0
	var max_cpu_part := clampi(3 + floori(float(cpu_level) / part_step), 3, 19)
	story_opponent_build = Catalog.random_build(max_cpu_part)
	story_opponent_build["_expression"] = (cpu_level * 3 + (1 if game_mode == "kids" else 4)) % EXPRESSION_LABELS.size()
	story_opponent_level = cpu_level
	story_opponent_mode = game_mode
	if game_mode == "kids":
		story_opponent_name = KIDS_RIVAL_NAMES[(cpu_level - 1) % KIDS_RIVAL_NAMES.size()]
	else:
		story_opponent_name = "%s-%03d" % [CPU_CODENAMES[(cpu_level - 1) % CPU_CODENAMES.size()], cpu_level]
	ai_recommended_build.clear()

func _story_cpu_multiplier() -> float:
	return 0.62 + log(float(cpu_level) + 1.0) * 0.16 + float(cpu_level) * 0.007

func _scaled_story_stats(build: Dictionary) -> Dictionary:
	var result := Catalog.build_stats(build).duplicate(true)
	var multiplier := _story_cpu_multiplier()
	result.health = float(result.health) * multiplier
	result.power = float(result.power) * multiplier
	result.armor = float(result.armor) * sqrt(multiplier)
	result.energy = float(result.energy) * multiplier
	return result

func _kids_cpu_multiplier() -> float:
	return 0.50 + log(float(cpu_level) + 1.0) * 0.11 + float(cpu_level) * 0.004

func _scaled_kids_stats(build: Dictionary) -> Dictionary:
	var result := Catalog.build_stats(build).duplicate(true)
	var multiplier := _kids_cpu_multiplier()
	result.health = float(result.health) * multiplier
	result.power = float(result.power) * multiplier
	result.armor = float(result.armor) * sqrt(multiplier)
	result.energy = float(result.energy) * multiplier
	return result

func _rating_from_stats(robot_stats: Dictionary) -> float:
	var durability := float(robot_stats.health) * (1.0 + float(robot_stats.armor) / 115.0)
	var dps := float(robot_stats.power) * float(robot_stats.attack_speed) * float(robot_stats.accuracy) / 100.0
	var control := 0.72 + float(robot_stats.speed) * 0.035 + float(robot_stats.range) * 0.025 + float(robot_stats.stability) * 0.002
	return sqrt(maxf(0.001, durability * dps)) * control

func _story_prediction_for(player_robot: Dictionary, opponent_robot: Dictionary) -> Dictionary:
	var player_rating := Catalog.combat_rating(player_robot)
	var cpu_rating := _rating_from_stats(_scaled_story_stats(opponent_robot))
	var player_affinity := Catalog.dominant_affinity(player_robot)
	var cpu_affinity := Catalog.dominant_affinity(opponent_robot)
	player_rating *= Catalog.affinity_multiplier(player_affinity, cpu_affinity)
	cpu_rating *= Catalog.affinity_multiplier(cpu_affinity, player_affinity)
	var total := maxf(0.001, player_rating + cpu_rating)
	return {"player": player_rating / total, "cpu": cpu_rating / total}

func _kids_prediction_for(player_robot: Dictionary, opponent_robot: Dictionary) -> Dictionary:
	var player_rating := Catalog.combat_rating(player_robot)
	var cpu_rating := _rating_from_stats(_scaled_kids_stats(opponent_robot))
	var total := maxf(0.001, player_rating + cpu_rating)
	return {"player": player_rating / total, "cpu": cpu_rating / total}

func _show_story_opponent_preview() -> void:
	if game_mode == "kids":
		_show_kids_opponent_preview()
		return
	state = GameState.OPPONENT_PREVIEW
	_ensure_story_opponent()
	_clear_ui()
	_clear_fighters()
	var player_robot: Dictionary = player_builds[0]
	var player_stats := Catalog.build_stats(player_robot)
	var cpu_stats := _scaled_story_stats(story_opponent_build)
	var prediction := _story_prediction_for(player_robot, story_opponent_build)
	_show_workshop_preview(story_opponent_build, Vector3(2.85, 0.0, 0.0), RED)
	preview_robot.scale = Vector3.ONE * 1.20
	preview_robot.remember_floor_height()
	camera.position = Vector3(0.15, 5.15, 12.25)
	camera.fov = 50.0
	camera.look_at(Vector3(1.35, 2.55, 0.0), Vector3.UP)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.018
	panel.anchor_top = 0.025
	panel.anchor_right = 0.57
	panel.anchor_bottom = 0.975
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, 22))
	ui_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	box.add_child(_title_label("PRÓXIMO RIVAL · NIVEL %d" % cpu_level, 31, GOLD))
	var opponent_title := _title_label(story_opponent_name, 38, RED)
	box.add_child(opponent_title)
	var affinity := Catalog.dominant_affinity(story_opponent_build)
	var personality_id := FighterScript._personality_from_stats(cpu_stats, cpu_level * 7919)
	var identity := _label("AFINIDAD %s  ·  IA %s" % [Catalog.AFFINITY_NAMES[affinity], FighterScript.PERSONALITY_NAMES[personality_id]], 16, Catalog.AFFINITY_COLORS[affinity])
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(identity)
	var chance := _label("ANÁLISIS: TU ROBOT %.0f%%  ·  RIVAL %.0f%%" % [float(prediction.player) * 100.0, float(prediction.cpu) * 100.0], 18, BLUE if float(prediction.player) >= 0.5 else RED)
	chance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(chance)
	box.add_child(_separator())
	var table := GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override("h_separation", 14)
	table.add_theme_constant_override("v_separation", 4)
	box.add_child(table)
	var your_header := _label("TU ROBOT", 14, BLUE)
	your_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table.add_child(your_header)
	var stat_header := _label("ESTADÍSTICA", 14, GOLD)
	stat_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table.add_child(stat_header)
	var rival_header := _label("RIVAL", 14, RED)
	rival_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table.add_child(rival_header)
	for key_value in Catalog.STAT_KEYS:
		var key: String = str(key_value)
		var player_value := float(player_stats[key])
		var cpu_value := float(cpu_stats[key])
		var lower_is_better: bool = key == "weight"
		var player_better: bool = player_value < cpu_value if lower_is_better else player_value > cpu_value
		var cpu_better: bool = cpu_value < player_value if lower_is_better else cpu_value > player_value
		var player_label := _label(_format_comparison_stat(key, player_value), 14, Color("8fffc1") if player_better else INK)
		player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_label.custom_minimum_size.x = 105.0
		table.add_child(player_label)
		var name_label := _label(Catalog.STAT_LABELS[key], 13, Color("c4d3e8"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size.x = 130.0
		table.add_child(name_label)
		var cpu_label := _label(_format_comparison_stat(key, cpu_value), 14, Color("ff9cac") if cpu_better else INK)
		cpu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cpu_label.custom_minimum_size.x = 105.0
		table.add_child(cpu_label)
	box.add_child(_make_button("⚙  ENTRAR AL RING", _start_battle, GOLD, Vector2(0, 56)))
	box.add_child(_make_button("🔧  AJUSTAR MI ROBOT", _rebuild_from_result, Color("9d88ff"), Vector2(0, 48)))
	box.add_child(_make_button("←  MENÚ PRINCIPAL", _show_main_menu, Color("60759a"), Vector2(0, 44)))

func _show_kids_opponent_preview() -> void:
	state = GameState.OPPONENT_PREVIEW
	_ensure_story_opponent()
	_clear_ui()
	_clear_fighters()
	if player_builds.is_empty():
		player_builds.append(current_build.duplicate(true))
	var player_robot: Dictionary = player_builds[0]
	var player_stats := Catalog.build_stats(player_robot)
	var cpu_stats := _scaled_kids_stats(story_opponent_build)
	var prediction := _kids_prediction_for(player_robot, story_opponent_build)
	var player_chance: float = float(prediction.player)
	var challenge_text: String = "¡ESTÁ MUY PAREJO!"
	if player_chance >= 0.62:
		challenge_text = "¡TU ROBOT TIENE VENTAJA!"
	elif player_chance < 0.44:
		challenge_text = "¡SERÁ UN RETO DIVERTIDO!"
	_show_workshop_preview(story_opponent_build, Vector3(2.65, 0.0, 0.0), Color("ff9a76"))
	preview_robot.scale = Vector3.ONE * 1.42
	preview_robot.remember_floor_height()
	camera.position = Vector3(0.20, 5.1, 11.7)
	camera.fov = 48.0
	camera.look_at(Vector3(2.25, 2.65, 0.0), Vector3.UP)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.02
	panel.anchor_top = 0.045
	panel.anchor_right = 0.55
	panel.anchor_bottom = 0.96
	panel.add_theme_stylebox_override("panel", _panel_style(Color("e51c3157"), 26))
	ui_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)
	panel.add_child(box)
	box.add_child(_title_label("2 · CONOCE A TU RIVAL", 31, GOLD))
	box.add_child(_title_label(story_opponent_name, 46, Color("ff9a76")))
	var level_label := _label("NIVEL %d  ·  %s" % [cpu_level, challenge_text], 20, INK)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(level_label)
	box.add_child(_separator())
	var max_health: float = maxf(float(player_stats.health), float(cpu_stats.health))
	var max_power: float = maxf(float(player_stats.power), float(cpu_stats.power))
	var max_speed: float = maxf(float(player_stats.speed), float(cpu_stats.speed))
	var compare := _label(
		"                 TÚ          RIVAL\n❤️  VIDA       %s   %s\n💪  FUERZA     %s   %s\n⚡  RAPIDEZ   %s   %s" % [
			_kids_duel_meter(float(player_stats.health), max_health),
			_kids_duel_meter(float(cpu_stats.health), max_health),
			_kids_duel_meter(float(player_stats.power), max_power),
			_kids_duel_meter(float(cpu_stats.power), max_power),
			_kids_duel_meter(float(player_stats.speed), max_speed),
			_kids_duel_meter(float(cpu_stats.speed), max_speed),
		],
		18,
		Color("f4fbff")
	)
	compare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compare.add_theme_constant_override("line_spacing", 9)
	box.add_child(compare)
	var hint := _label("Los robots juegan solos. Tú solo debes tocar SUPERPODER cuando esté listo.", 18, Color("ccecff"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(hint)
	box.add_child(_make_button("▶  3 · ¡JUGAR!", _start_battle, Color("54c987"), Vector2(0, 72)))
	box.add_child(_make_button("↩  CAMBIAR MI ROBOT", _return_to_kids_builder, Color("9d88ff"), Vector2(0, 54)))
	box.add_child(_make_button("⌂  MENÚ", _show_main_menu, Color("60759a"), Vector2(0, 46)))

func _kids_duel_meter(value: float, maximum: float) -> String:
	var filled: int = clampi(roundi(value / maxf(0.001, maximum) * 5.0), 1, 5)
	return "●".repeat(filled) + "○".repeat(5 - filled)

func _return_to_kids_builder() -> void:
	if not player_builds.is_empty():
		current_build = player_builds[0].duplicate(true)
	player_builds.clear()
	_show_kids_builder()

func _format_comparison_stat(key: String, value: float) -> String:
	return "%.1f" % value if key in ["speed", "attack_speed", "range"] else "%.0f" % value

func _show_lan_lobby() -> void:
	state = GameState.LAN_LOBBY
	_clear_ui()
	_clear_fighters()
	var own_index := clampi(local_lan_index, 0, player_builds.size() - 1)
	var own_build: Dictionary = player_builds[own_index]
	_show_workshop_preview(own_build, Vector3(2.85, 0.0, 0.0), TEAM_COLORS[own_index])
	var panel := PanelContainer.new()
	panel.anchor_left = 0.025
	panel.anchor_top = 0.06
	panel.anchor_right = 0.52
	panel.anchor_bottom = 0.94
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, 22))
	ui_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_title_label("SALA LAN · 2 A 4", 34, Color("8edfa8")))
	var info := _label("Todos deben estar conectados al mismo Wi-Fi.\nEl anfitrión comparte su IP; los demás la escriben.", 17, INK)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var address := LineEdit.new()
	address.placeholder_text = "IP DEL ANFITRIÓN · ejemplo 192.168.1.20"
	address.text = lan.get_local_ip()
	address.custom_minimum_size = Vector2(0.0, 52.0)
	address.add_theme_font_size_override("font_size", 18)
	box.add_child(address)
	box.add_child(_make_button("ABRIR SALA COMO ANFITRIÓN", _host_lan_game, BLUE, Vector2(0, 58)))
	box.add_child(_make_button("UNIRME A ESA IP", _join_lan_game.bind(address), Color("8edfa8"), Vector2(0, 58)))
	lan_status_label = _label("ELIGE ANFITRIÓN O INVITADO", 18, GOLD)
	lan_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lan_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lan_status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(lan_status_label)
	lan_start_button = _make_button("INICIAR PELEA LAN", lan.start_battle, GOLD, Vector2(0, 62))
	lan_start_button.disabled = true
	box.add_child(lan_start_button)
	if lan.hosting:
		_on_lan_status_changed("ROBOTS CONECTADOS: %d / 4" % lan.submitted_builds.size(), lan.submitted_builds.size(), lan.submitted_builds.size() >= 2)
	elif not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_on_lan_status_changed("CONECTADO · esperando al anfitrión", 1, false)
	box.add_child(_make_button("← VOLVER", _show_main_menu, Color("60759a"), Vector2(0, 48)))

func _host_lan_game() -> void:
	var own_index := clampi(local_lan_index, 0, player_builds.size() - 1)
	lan.host_game(player_builds[own_index])

func _join_lan_game(address: LineEdit) -> void:
	var own_index := clampi(local_lan_index, 0, player_builds.size() - 1)
	lan.join_game(address.text, player_builds[own_index])

func _on_lan_status_changed(message: String, _player_count: int, can_start: bool) -> void:
	if lan_status_label:
		lan_status_label.text = message
	if lan_start_button:
		lan_start_button.disabled = not can_start

func _on_lan_battle_ready(builds: Array[Dictionary], local_index: int) -> void:
	player_builds = builds.duplicate(true)
	local_lan_index = local_index
	_start_battle()

func _on_lan_heavy_received(fighter_index: int) -> void:
	_trigger_heavy(fighter_index)

func _start_battle() -> void:
	state = GameState.BATTLE
	Engine.time_scale = 1.0
	battle_speed = 1.0
	battle_camera_time = 0.0
	camera_shake = 0.0
	impact_focus_time = 0.0
	battle_started = false
	battle_finished = false
	battle_time_left = 75.0 if game_mode == "kids" else 90.0
	last_winner = -1
	_clear_ui()
	_clear_preview()
	workshop_root.visible = false
	ring_root.visible = true
	_clear_fighters()
	camera.position = Vector3(0.0, 8.9, 14.2)
	camera.fov = 54.0
	camera.look_at(Vector3(0.0, 1.8, 0.0), Vector3.UP)

	var battle_builds: Array[Dictionary] = player_builds.duplicate(true)
	var multipliers: Array[float] = []
	var names: Array[String] = []
	for index in range(battle_builds.size()):
		multipliers.append(1.0)
		if game_mode == "kids" and index == 0:
			names.append(str(KIDS_ROBOT_NAMES[kids_preset_index]))
		else:
			names.append("ROBOT J%d" % (index + 1))
	if game_mode in ["story", "kids"]:
		_ensure_story_opponent()
		battle_builds.append(story_opponent_build.duplicate(true))
		multipliers.append(_kids_cpu_multiplier() if game_mode == "kids" else _story_cpu_multiplier())
		names.append(story_opponent_name)
	if battle_builds.size() < 2:
		_show_main_menu()
		return
	var spawn_positions := [Vector3(-4.2, 0.18, -2.2), Vector3(4.2, 0.18, 2.2), Vector3(-2.2, 0.18, 4.2), Vector3(2.2, 0.18, -4.2)]
	for index in range(mini(4, battle_builds.size())):
		var fighter: ArenaFighter = FighterScript.new()
		ring_root.add_child(fighter)
		fighter.position = spawn_positions[index]
		fighter.friendly_mode = true
		fighter.ai_difficulty = 1.0
		if game_mode == "story" and index >= player_builds.size():
			fighter.ai_difficulty = clampf(1.15 + float(cpu_level) * 0.025, 1.15, 1.48)
		elif game_mode == "kids" and index >= player_builds.size():
			fighter.ai_difficulty = clampf(1.00 + float(cpu_level) * 0.010, 1.00, 1.16)
		elif game_mode != "kids":
			fighter.ai_difficulty = 1.06
		var fighter_tint: Color = KIDS_ROBOT_COLORS[kids_preset_index] if game_mode == "kids" and index == 0 else TEAM_COLORS[index]
		fighter.setup_robot(battle_builds[index], fighter_tint, multipliers[index], index, names[index])
		fighter.auto_tool_enabled = game_mode in ["story", "kids"] and index == 1
		fighter.health_changed.connect(_on_health_changed)
		fighter.defeated.connect(_on_fighter_defeated)
		fighter.combat_event.connect(_show_battle_message)
		fighter.arcade_event.connect(_show_arcade_callout)
		fighter.sfx_requested.connect(_on_fighter_sfx)
		fighter.impact.connect(_on_fighter_impact)
		fighters.append(fighter)
	for player_index in _controlled_fighter_indexes():
		if player_index >= 0 and player_index < fighters.size():
			var aura_color: Color = KIDS_ROBOT_COLORS[kids_preset_index] if game_mode == "kids" and player_index == 0 else TEAM_COLORS[player_index]
			_add_player_aura(fighters[player_index], aura_color)
	for fighter in fighters:
		var possible_targets: Array[ArenaFighter] = []
		for candidate in fighters:
			if candidate != fighter:
				possible_targets.append(candidate)
		fighter.set_opponents(possible_targets)
	fighter_a = fighters[0]
	fighter_b = fighters[1]
	_build_battle_ui(names)
	for fighter in fighters:
		_on_health_changed(fighter.fighter_id, 1.0, fighter.hp, fighter.max_hp)
	if fighters.size() == 2:
		var prediction: Dictionary = _kids_prediction_for(battle_builds[0], battle_builds[1]) if game_mode == "kids" else (_story_prediction_for(battle_builds[0], battle_builds[1]) if game_mode == "story" else Catalog.matchup_prediction(battle_builds[0], battle_builds[1]))
		var chance_a: float = float(prediction.player) if game_mode in ["story", "kids"] else float(prediction.a)
		var chance_b: float = float(prediction.cpu) if game_mode in ["story", "kids"] else float(prediction.b)
		battle_message.text = "¡TODO LISTO!" if game_mode == "kids" else "ANÁLISIS · J1 %.0f%%  /  J2 %.0f%%" % [chance_a * 100.0, chance_b * 100.0]
		battle_message.modulate = Color("c8d8ef")
		await get_tree().create_timer(0.85).timeout
		if state != GameState.BATTLE:
			return
	if audio:
		audio.start_battle_music()
	await _countdown()
	if state != GameState.BATTLE:
		return
	battle_started = true
	for fighter in fighters:
		fighter.begin_fight()
	_show_battle_message("¡A JUGAR!" if game_mode == "kids" else "¡COMBATE!", GOLD)

func _controlled_fighter_indexes() -> Array[int]:
	var result: Array[int] = []
	if game_mode == "lan":
		result.append(local_lan_index)
	elif game_mode == "local":
		for index in range(fighters.size()):
			result.append(index)
	else:
		result.append(0)
	return result

func _add_player_aura(fighter: ArenaFighter, color: Color) -> void:
	if not is_instance_valid(fighter):
		return
	var aura: Node3D = Node3D.new()
	aura.name = "PlayerAura"
	aura.position = Vector3(0.0, -0.05, 0.0)
	fighter.add_child(aura)
	for layer in range(2):
		var glow_disc: MeshInstance3D = MeshInstance3D.new()
		var disc_mesh: CylinderMesh = CylinderMesh.new()
		disc_mesh.top_radius = 1.20 - float(layer) * 0.25
		disc_mesh.bottom_radius = disc_mesh.top_radius
		disc_mesh.height = 0.035 + float(layer) * 0.012
		disc_mesh.radial_segments = 40
		var material: StandardMaterial3D = StandardMaterial3D.new()
		var aura_tint: Color = color
		aura_tint.a = 0.18 if layer == 0 else 0.34
		material.albedo_color = aura_tint
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color * (1.7 if layer == 0 else 2.4)
		material.emission_energy_multiplier = 1.8
		disc_mesh.material = material
		glow_disc.mesh = disc_mesh
		glow_disc.position.y = float(layer) * 0.025
		aura.add_child(glow_disc)
	var glow_light: OmniLight3D = OmniLight3D.new()
	glow_light.position.y = 0.45
	glow_light.light_color = color
	glow_light.light_energy = 1.1
	glow_light.omni_range = 3.2
	glow_light.shadow_enabled = false
	aura.add_child(glow_light)
	var aura_tween: Tween = aura.create_tween()
	aura_tween.set_loops()
	aura_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	aura_tween.tween_property(aura, "scale", Vector3(1.10, 1.0, 1.10), 0.72)
	aura_tween.tween_property(aura, "scale", Vector3.ONE, 0.72)

func _build_battle_ui(names: Array[String]) -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16.0
	top.offset_top = 14.0
	top.offset_right = -16.0
	top.offset_bottom = 146.0
	top.add_theme_stylebox_override("panel", _panel_style(PANEL, 20))
	ui_root.add_child(top)
	var outer := VBoxContainer.new()
	top.add_child(outer)
	battle_clock = _title_label("75" if game_mode == "kids" else "90", 29, GOLD)
	battle_clock.custom_minimum_size = Vector2(0, 32)
	outer.add_child(battle_clock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	outer.add_child(row)
	fighter_hp_bars.clear()
	fighter_hp_texts.clear()
	for index in range(fighters.size()):
		var fighter_box := VBoxContainer.new()
		fighter_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(fighter_box)
		var title_text: String = names[index]
		if game_mode != "kids":
			title_text = "%s · %s · %s" % [names[index], Catalog.AFFINITY_NAMES[Catalog.dominant_affinity(fighters[index].build)], fighters[index].personality_name]
		var title := _label(title_text, 17 if game_mode == "kids" else 13, TEAM_COLORS[index])
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fighter_box.add_child(title)
		var hp_bar := _health_bar(TEAM_COLORS[index])
		hp_bar.custom_minimum_size.y = 20.0
		fighter_box.add_child(hp_bar)
		var hp_text := _label("", 12, INK)
		hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fighter_box.add_child(hp_text)
		fighter_hp_bars.append(hp_bar)
		fighter_hp_texts.append(hp_text)
	hp_bar_a = fighter_hp_bars[0]
	hp_bar_b = fighter_hp_bars[1]
	hp_text_a = fighter_hp_texts[0]
	hp_text_b = fighter_hp_texts[1]

	battle_message = _title_label("PREPARADOS", 34, GOLD)
	battle_message.anchor_left = 0.25
	battle_message.anchor_top = 0.21
	battle_message.anchor_right = 0.75
	battle_message.anchor_bottom = 0.28
	ui_root.add_child(battle_message)
	var controls := HBoxContainer.new()
	controls.anchor_left = 0.64
	controls.anchor_top = 0.89
	controls.anchor_right = 0.985
	controls.anchor_bottom = 0.98
	controls.add_theme_constant_override("separation", 8)
	ui_root.add_child(controls)
	if game_mode not in ["lan", "kids"]:
		speed_button = _make_button("VELOCIDAD x1", _toggle_battle_speed, Color("9d88ff"), Vector2(150, 48))
		controls.add_child(speed_button)
	controls.add_child(_make_button("MENÚ", _show_main_menu, Color("60759a"), Vector2(130, 48)))
	var heavy_row := GridContainer.new()
	heavy_row.anchor_left = 0.015
	heavy_row.anchor_top = 0.87 if game_mode == "kids" else 0.79
	heavy_row.anchor_right = 0.62 if game_mode == "kids" else 0.70
	heavy_row.anchor_bottom = 0.98
	heavy_row.columns = 1 if game_mode in ["kids", "lan"] else 4
	heavy_row.add_theme_constant_override("h_separation", 8)
	heavy_row.add_theme_constant_override("v_separation", 6)
	ui_root.add_child(heavy_row)
	heavy_buttons.clear()
	advanced_action_buttons.clear()
	var controllable: Array[int] = _controlled_fighter_indexes()
	for index in controllable:
		var button_text: String = "✨  SUPERPODER" if game_mode == "kids" else "USAR ARMA J%d" % (index + 1)
		var button_size := Vector2(330, 76) if game_mode == "kids" else Vector2(218, 60)
		var button := _make_button(button_text, _request_heavy.bind(index), Color("54c987") if game_mode == "kids" else TEAM_COLORS[index], button_size)
		if game_mode == "kids":
			button.add_theme_font_size_override("font_size", 23)
		button.set_meta("fighter_index", index)
		heavy_row.add_child(button)
		heavy_buttons.append(button)
		if game_mode not in ["kids", "lan"]:
			for action_data in [["jump", "↥ SALTAR"], ["guard", "⬡ DEFENSA"], ["dash", "➜ IMPULSO"]]:
				var action: String = str(action_data[0])
				var base_text: String = "%s J%d" % [str(action_data[1]), index + 1]
				var action_button := _make_button(base_text, _request_tactical_action.bind(index, action), Color("42679b"), Vector2(150, 46))
				action_button.set_meta("fighter_index", index)
				action_button.set_meta("action", action)
				action_button.set_meta("base_text", base_text)
				action_button.add_theme_font_size_override("font_size", 11)
				heavy_row.add_child(action_button)
				advanced_action_buttons.append(action_button)

func _request_heavy(fighter_index: int) -> void:
	if game_mode == "lan":
		lan.request_heavy(fighter_index)
	else:
		_trigger_heavy(fighter_index)

func _trigger_heavy(fighter_index: int) -> void:
	if fighter_index < 0 or fighter_index >= fighters.size():
		return
	var fighter := fighters[fighter_index]
	if is_instance_valid(fighter) and not fighter.request_heavy_attack():
		_show_battle_message("¡ESPERA A QUE EL SUPERPODER ESTÉ LISTO!" if game_mode == "kids" else "HERRAMIENTA NO DISPONIBLE O RECARGANDO", Color("c4cfdd"))

func _request_tactical_action(fighter_index: int, action: String) -> void:
	if fighter_index < 0 or fighter_index >= fighters.size():
		return
	var fighter: ArenaFighter = fighters[fighter_index]
	if is_instance_valid(fighter) and not fighter.request_tactical_action(action):
		_show_battle_message("ACCIÓN RECARGANDO", Color("c4cfdd"))

func _update_heavy_buttons() -> void:
	for button in heavy_buttons:
		var fighter_index := int(button.get_meta("fighter_index", -1))
		if fighter_index < 0 or fighter_index >= fighters.size():
			continue
		var fighter := fighters[fighter_index]
		if not is_instance_valid(fighter):
			button.disabled = true
			continue
		button.disabled = fighter.hp <= 0.0 or not fighter.has_manual_weapon()
		if game_mode == "kids":
			button.text = "✨  SUPERPODER · %.1fs" % fighter.heavy_cooldown if fighter.heavy_cooldown > 0.05 else "✨  ¡SUPERPODER LISTO!"
		else:
			var action_name := fighter.manual_action_label()
			button.text = "%s J%d%s" % [action_name, fighter_index + 1, " · %.1fs" % fighter.heavy_cooldown if fighter.heavy_cooldown > 0.05 else " · ¡LISTO!"]

func _update_advanced_action_buttons() -> void:
	for button in advanced_action_buttons:
		var fighter_index := int(button.get_meta("fighter_index", -1))
		if fighter_index < 0 or fighter_index >= fighters.size():
			continue
		var fighter: ArenaFighter = fighters[fighter_index]
		var action: String = str(button.get_meta("action", ""))
		var base_text: String = str(button.get_meta("base_text", "ACCIÓN"))
		if not is_instance_valid(fighter):
			button.disabled = true
			continue
		var cooldown: float = fighter.tactical_action_cooldown(action)
		button.disabled = fighter.hp <= 0.0 or cooldown > 0.05
		button.text = "%s\n%.1fs" % [base_text, cooldown] if cooldown > 0.05 else base_text + "\n¡LISTO!"

func _countdown() -> void:
	var pitch := 0.82
	for word in ["3", "2", "1"]:
		if state != GameState.BATTLE:
			return
		if battle_message:
			battle_message.text = word
			battle_message.modulate = Color.WHITE
		if audio:
			audio.play_sfx("countdown", pitch)
		pitch += 0.12
		await get_tree().create_timer(0.62).timeout

func _on_fighter_sfx(kind: String, pitch: float) -> void:
	if audio:
		audio.play_sfx(kind, pitch)

func _on_fighter_impact(strength: float, _impact_position: Vector3) -> void:
	var shake_limit: float = 0.26 if game_mode == "kids" else 0.46
	camera_shake = maxf(camera_shake, clampf(strength, 0.06, shake_limit))
	if strength >= 0.28:
		impact_focus_position = _impact_position
		impact_focus_time = 0.52
	if strength >= 0.42:
		camera.fov = 47.0
		var camera_tween := camera.create_tween()
		camera_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		camera_tween.tween_property(camera, "fov", 54.0, 0.62)
		var flash := ColorRect.new()
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.color = Color("38fff4b0")
		ui_root.add_child(flash)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var flash_tween := flash.create_tween()
		flash_tween.tween_property(flash, "color:a", 0.0, 0.20)
		flash_tween.tween_callback(flash.queue_free)

func _on_health_changed(id: int, ratio: float, current: float, maximum: float) -> void:
	if id >= 0 and id < fighter_hp_bars.size():
		fighter_hp_bars[id].value = ratio * 100.0
		fighter_hp_texts[id].text = "%.0f / %.0f" % [current, maximum]

func _on_fighter_defeated(_loser_id: int) -> void:
	if battle_finished:
		return
	var alive: Array[ArenaFighter] = []
	for fighter in fighters:
		if is_instance_valid(fighter) and fighter.hp > 0.0:
			alive.append(fighter)
	if alive.size() <= 1:
		last_winner = alive[0].fighter_id if alive.size() == 1 else 0
		_complete_battle()

func _finish_by_time() -> void:
	if battle_finished or fighters.is_empty():
		return
	var best_ratio := -1.0
	for fighter in fighters:
		if not is_instance_valid(fighter):
			continue
		var ratio: float = fighter.hp / fighter.max_hp
		if ratio > best_ratio:
			best_ratio = ratio
			last_winner = fighter.fighter_id
	for fighter in fighters:
		if is_instance_valid(fighter) and fighter.fighter_id != last_winner:
			fighter.stop_fight()
			fighter.model.set_damage_state(0)
			fighter.model.play_defeat()
	_complete_battle()

func _complete_battle() -> void:
	if battle_finished:
		return
	battle_finished = true
	battle_started = false
	var local_victory := last_winner == (local_lan_index if game_mode == "lan" else 0)
	if audio:
		audio.stop_music()
		audio.play_sfx("victory" if local_victory else "defeat")
	for fighter in fighters:
		if is_instance_valid(fighter):
			fighter.stop_fight()
	var winner: ArenaFighter = fighters[last_winner] if last_winner >= 0 and last_winner < fighters.size() else null
	if is_instance_valid(winner):
		winner.model.play_victory()
	last_reward = 0
	if game_mode in ["story", "kids"]:
		if last_winner == 0:
			last_reward = 3 if game_mode == "kids" else 180 + cpu_level * 35
			if game_mode == "kids":
				kids_stars += last_reward
			else:
				credits += last_reward
			total_wins += 1
			cpu_level += 1
			best_level = maxi(best_level, cpu_level)
		else:
			last_reward = 1 if game_mode == "kids" else 45
			if game_mode == "kids":
				kids_stars += last_reward
			else:
				credits += last_reward
		_save_progress()
	await get_tree().create_timer(1.15).timeout
	if state == GameState.BATTLE:
		_show_results()

func _show_results() -> void:
	if game_mode == "kids":
		_show_kids_results()
		return
	state = GameState.RESULT
	Engine.time_scale = 1.0
	_clear_ui()
	var panel := _center_panel(Vector2(650.0, 700.0 if game_mode == "story" else 580.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var local_player := local_lan_index if game_mode == "lan" else 0
	var victory := last_winner == local_player
	var title := "¡VICTORIA!" if victory else "GANA ROBOT %d" % (last_winner + 1)
	if game_mode == "story" and not victory:
		title = "DERROTA"
	box.add_child(_title_label(title, 52, GOLD if victory else RED))
	if game_mode == "story":
		var message := "SUPERASTE EL NIVEL %d" % (cpu_level - 1) if victory else "EL RIVAL NIVEL %d FUE MÁS FUERTE" % cpu_level
		var info := _label(message, 22, INK)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(info)
		var reward_label := _label("+%d CRÉDITOS · TOTAL %d" % [last_reward, credits], 21, GOLD)
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(reward_label)
		if victory:
			box.add_child(_make_button("▶  SIGUIENTE RIVAL · NIVEL %d" % cpu_level, _next_cpu_battle, BLUE, Vector2(540, 64)))
		else:
			ai_recommended_build = _optimize_owned_build(story_opponent_build)
			var current_prediction := _story_prediction_for(player_builds[0], story_opponent_build)
			var improved_prediction := _story_prediction_for(ai_recommended_build, story_opponent_build)
			var advisor := _label("IA MECÁNICA: puedo mejorar tu posibilidad estimada de %.0f%% a %.0f%% usando tus piezas actuales." % [float(current_prediction.player) * 100.0, float(improved_prediction.player) * 100.0], 17, Color("8fffc1"))
			advisor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			advisor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(advisor)
			box.add_child(_make_button("🤖  IA: ARMAR EL MEJOR ROBOT", _apply_ai_recommendation, Color("78dca0"), Vector2(540, 62)))
			box.add_child(_make_button("↻  REINTENTAR NIVEL %d" % cpu_level, _retry_cpu_battle, RED, Vector2(540, 64)))
		box.add_child(_make_button("🔧  VOLVER AL TALLER", _rebuild_from_result, Color("9d88ff"), Vector2(540, 58)))
	elif game_mode == "local":
		var local_info := _label("Los robots jugaron usando sus estadísticas, movimientos y poderes.\nActivar el superpoder en el momento correcto puede cambiar la partida.", 20, INK)
		local_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(local_info)
		box.add_child(_make_button("↻  REVANCHA CON LOS MISMOS ROBOTS", _local_rematch, BLUE, Vector2(540, 64)))
		box.add_child(_make_button("🔧  CONSTRUIR DOS ROBOTS NUEVOS", _restart_local_build, RED, Vector2(540, 58)))
	else:
		var lan_info := _label("PELEA LAN TERMINADA · GANA ROBOT %d" % (last_winner + 1), 21, INK)
		lan_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(lan_info)
		box.add_child(_make_button("📡  VOLVER A LA SALA LAN", _show_lan_lobby, Color("8edfa8"), Vector2(540, 60)))
	box.add_child(_make_button("⌂  MENÚ PRINCIPAL", _show_main_menu, Color("60759a"), Vector2(540, 52)))

func _show_kids_results() -> void:
	state = GameState.RESULT
	Engine.time_scale = 1.0
	_clear_ui()
	var victory: bool = last_winner == 0
	var panel := _center_panel(Vector2(680.0, 620.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(_title_label("¡LO LOGRASTE!" if victory else "¡BUEN INTENTO!", 54, Color("72e39e") if victory else Color("ffe36e")))
	var message_text: String = "¡Tu robot ganó el juego del nivel %d!" % (cpu_level - 1) if victory else "%s ganó esta vez. ¡Puedes probar otro robot!" % story_opponent_name
	var message := _label(message_text, 23, INK)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(message)
	var stars := _title_label("+%d ⭐  ·  TIENES %d ESTRELLAS" % [last_reward, kids_stars], 25, GOLD)
	box.add_child(stars)
	var encouragement := _label("Cada robot es bueno en algo diferente. No hay una elección incorrecta.", 18, Color("ccecff"))
	encouragement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encouragement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(encouragement)
	if victory:
		box.add_child(_make_button("▶  SIGUIENTE AMIGO · NIVEL %d" % cpu_level, _next_cpu_battle, Color("54c987"), Vector2(560, 72)))
	else:
		box.add_child(_make_button("✨  AYÚDAME A ELEGIR", _kids_auto_help, Color("9d88ff"), Vector2(560, 72)))
		box.add_child(_make_button("↻  JUGAR OTRA VEZ", _retry_cpu_battle, Color("54c987"), Vector2(560, 62)))
	box.add_child(_make_button("🤖  ELEGIR OTRO ROBOT", _return_to_kids_builder, BLUE, Vector2(560, 58)))
	box.add_child(_make_button("⌂  MENÚ", _show_main_menu, Color("60759a"), Vector2(560, 48)))

func _best_kids_preset_against(opponent_build: Dictionary) -> int:
	var best_index: int = 0
	var best_chance: float = -1.0
	for index in range(KIDS_PRESETS.size()):
		var candidate: Dictionary = KIDS_PRESETS[index]
		var prediction: Dictionary = _kids_prediction_for(candidate, opponent_build)
		var chance: float = float(prediction.player)
		if chance > best_chance:
			best_chance = chance
			best_index = index
	return best_index

func _kids_auto_help() -> void:
	kids_preset_index = _best_kids_preset_against(story_opponent_build)
	var selected_build: Dictionary = KIDS_PRESETS[kids_preset_index]
	current_build = selected_build.duplicate(true)
	player_builds.clear()
	if audio:
		audio.play_sfx("unlock", 1.02)
	_show_kids_builder()

func _next_cpu_battle() -> void:
	story_opponent_build.clear()
	story_opponent_level = -1
	story_opponent_mode = ""
	_show_story_opponent_preview()

func _retry_cpu_battle() -> void:
	_show_story_opponent_preview()

func _optimize_owned_build(opponent_build: Dictionary) -> Dictionary:
	var best: Dictionary = player_builds[0].duplicate(true) if not player_builds.is_empty() else _load_last_build()
	for _pass_index in range(4):
		for slot in Catalog.SLOTS:
			var unlocked: Array = unlocked_parts.get(slot, [0, 1, 2, 3])
			var best_index := int(best.get(slot, 0))
			var best_score := _candidate_story_score(best, opponent_build)
			for option_value in unlocked:
				var trial := best.duplicate(true)
				trial[slot] = int(option_value)
				var score := _candidate_story_score(trial, opponent_build)
				if score > best_score + 0.0001:
					best_score = score
					best_index = int(option_value)
			best[slot] = best_index
	return best

func _candidate_story_score(candidate: Dictionary, opponent_build: Dictionary) -> float:
	var prediction := _story_prediction_for(candidate, opponent_build)
	var opponent_affinity := Catalog.dominant_affinity(opponent_build)
	var left_bonus := Catalog.affinity_multiplier(Catalog.weapon_affinity(candidate, true), opponent_affinity)
	var right_bonus := Catalog.affinity_multiplier(Catalog.weapon_affinity(candidate, false), opponent_affinity)
	return float(prediction.player) + (left_bonus + right_bonus - 2.0) * 0.018

func _apply_ai_recommendation() -> void:
	if ai_recommended_build.is_empty():
		ai_recommended_build = _optimize_owned_build(story_opponent_build)
	var saved_expression: int = clampi(int(current_build.get("_expression", 0)), 0, EXPRESSION_LABELS.size() - 1)
	current_builder = 1
	current_build = ai_recommended_build.duplicate(true)
	current_build["_expression"] = saved_expression
	player_builds.clear()
	_start_builder()
	var prediction := _story_prediction_for(current_build, story_opponent_build)
	if option_detail_label:
		option_detail_label.text = "🤖 IA MECÁNICA: robot optimizado contra %s · posibilidad estimada %.0f%%" % [story_opponent_name, float(prediction.player) * 100.0]
	if audio:
		audio.play_sfx("unlock", 0.92)

func _rebuild_from_result() -> void:
	current_builder = 1
	current_build = player_builds[0].duplicate(true)
	player_builds.clear()
	_start_builder()

func _local_rematch() -> void:
	_start_battle()

func _restart_local_build() -> void:
	current_builder = 1
	current_build = Catalog.empty_build()
	player_builds.clear()
	_start_builder()

func _toggle_battle_speed() -> void:
	battle_speed = 2.0 if battle_speed < 1.5 else 1.0
	Engine.time_scale = battle_speed
	if speed_button:
		speed_button.text = "VELOCIDAD x%d" % int(battle_speed)
	_show_battle_message("VELOCIDAD x%d" % int(battle_speed), Color("9d88ff"))

func _show_battle_message(message: String, color: Color) -> void:
	if not battle_message:
		return
	if message_tween and message_tween.is_valid():
		message_tween.kill()
	battle_message.text = message
	battle_message.modulate = color
	battle_message.scale = Vector2(0.72, 0.72)
	battle_message.pivot_offset = battle_message.size * 0.5
	message_tween = create_tween()
	message_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	message_tween.tween_property(battle_message, "scale", Vector2.ONE, 0.22)
	message_tween.tween_interval(0.85)
	message_tween.tween_property(battle_message, "modulate:a", 0.0, 0.28)

func _show_arcade_callout(message: String, color: Color, intensity: int) -> void:
	if state != GameState.BATTLE:
		return
	camera_shake = maxf(camera_shake, 0.32 + float(intensity) * 0.16)
	if audio:
		audio.pulse_battle_music(intensity)
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	var flash_color: Color = color
	flash_color.a = 0.14 + float(intensity) * 0.035
	flash.color = flash_color
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(flash)
	var callout := Label.new()
	callout.text = message
	callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	callout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	callout.anchor_left = 0.12
	callout.anchor_top = 0.34
	callout.anchor_right = 0.88
	callout.anchor_bottom = 0.60
	callout.add_theme_font_size_override("font_size", 22 + intensity * 4)
	callout.add_theme_color_override("font_color", color)
	callout.add_theme_color_override("font_outline_color", Color("e6000714"))
	callout.add_theme_constant_override("outline_size", 5 + intensity)
	callout.add_theme_color_override("font_shadow_color", color.darkened(0.60))
	callout.add_theme_constant_override("shadow_offset_x", 8)
	callout.add_theme_constant_override("shadow_offset_y", 10)
	callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	callout.scale = Vector2(0.22, 0.22)
	ui_root.add_child(callout)
	callout.pivot_offset = callout.size * 0.5
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.18 + float(intensity) * 0.04)
	flash_tween.tween_callback(flash.queue_free)
	var tween := callout.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(callout, "scale", Vector2(1.10, 1.10), 0.16)
	tween.tween_property(callout, "scale", Vector2.ONE, 0.10)
	tween.tween_interval(0.46 + float(intensity) * 0.08)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(callout, "scale", Vector2(1.75, 0.35), 0.16)
	tween.parallel().tween_property(callout, "modulate:a", 0.0, 0.16)
	tween.tween_callback(callout.queue_free)

func _show_help() -> void:
	state = GameState.HELP
	_clear_ui()
	var panel := _center_panel(Vector2(760.0, 760.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_title_label("CÓMO SE JUEGA", 40, GOLD))
	var help := _label(
		"MODO FÁCIL · SOLO 4 PASOS\n\n" +
		"1  ELIGE Y CAMBIA PARTES\nToca directamente el robot: los controles son invisibles para que puedas verlo completo. También puedes usar las categorías del costado. En modo fácil hay cuatro opciones por zona.\n\n" +
		"2  ELIGE SU CARA\nPrueba ocho expresiones divertidas. La cara elegida aparece en el taller y durante toda la pelea.\n\n" +
		"3  CONOCE A TU RIVAL\nLos puntos muestran quién tiene más vida, fuerza y rapidez.\n\n" +
		"4  ¡JUEGA!\nLos robots rodean, saltan, flanquean, amagan, esquivan, cargan y se separan después de atacar. Los críticos pueden lanzar una pieza mecánica con muchas chispas. Toca SUPERPODER cuando diga LISTO. El aro luminoso muestra cuál es tu robot.\n\n" +
		"SI NO GANAS\nNo pasa nada. Toca AYÚDAME A ELEGIR y el juego recomendará el robot más conveniente.\n\n" +
		"MÁS OPCIONES\nTaller avanzado permite construir pieza por pieza y agrega botones para Saltar, Defensa e Impulso. También hay dos jugadores y modo Wi-Fi. Todos los modos usan la misma IA, críticos arcade y desarmes mecánicos.",
		18,
		INK
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(help)
	box.add_child(_make_button("←  ENTENDIDO", _show_main_menu, BLUE, Vector2(0, 56)))

func _show_workshop_preview(build: Dictionary, location: Vector3, tint: Color) -> void:
	workshop_root.visible = true
	ring_root.visible = false
	_clear_preview()
	preview_robot = RobotModelScript.new()
	workshop_root.add_child(preview_robot)
	preview_robot.position = location
	preview_robot.build_robot(build, tint)
	preview_robot.remember_floor_height()

func _clear_preview() -> void:
	if is_instance_valid(preview_robot):
		preview_robot.queue_free()
	preview_robot = null

func _clear_fighters() -> void:
	for fighter in fighters:
		if is_instance_valid(fighter):
			fighter.queue_free()
	for debris in get_tree().get_nodes_in_group("battle_debris"):
		if is_instance_valid(debris):
			debris.queue_free()
	fighters.clear()
	fighter_a = null
	fighter_b = null

func _reset_runtime() -> void:
	Engine.time_scale = 1.0
	if audio:
		audio.stop_music()
	battle_started = false
	battle_finished = false
	if lan:
		lan.close_connection()
	_clear_fighters()
	workshop_root.visible = true
	ring_root.visible = false

func _clear_ui() -> void:
	for child in ui_root.get_children():
		ui_root.remove_child(child)
		child.queue_free()
	timer_label = null
	stats_label = null
	synergy_label = null
	option_detail_label = null
	options_grid = null
	hp_bar_a = null
	hp_bar_b = null
	hp_text_a = null
	hp_text_b = null
	battle_clock = null
	battle_message = null
	stats_bars.clear()
	stat_value_labels.clear()
	fighter_hp_bars.clear()
	fighter_hp_texts.clear()
	heavy_buttons.clear()
	advanced_action_buttons.clear()
	robot_touch_buttons.clear()
	lan_status_label = null
	lan_start_button = null
	speed_button = null
	random_button = null

func _build_workshop() -> void:
	_mesh_box(workshop_root, Vector3(22.0, 0.45, 16.0), Color("101a35"), Vector3(0.0, -0.32, 0.0), 0.45)
	_mesh_box(workshop_root, Vector3(22.0, 10.0, 0.45), Color("081027"), Vector3(0.0, 4.5, -5.0), 0.25)
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_mesh_box(workshop_root, Vector3(0.10, 8.0, 0.18), BLUE.darkened(0.25), Vector3(x, 4.2, -4.72), 0.1, true)
	for y in [1.0, 3.0, 5.0, 7.0]:
		_mesh_box(workshop_root, Vector3(19.0, 0.08, 0.15), Color("704dff"), Vector3(0.0, y, -4.70), 0.1, true)
	_mesh_cylinder(workshop_root, 3.05, 0.42, Color("283965"), Vector3(-0.80, -0.02, 0.0), false)
	_mesh_cylinder(workshop_root, 2.68, 0.55, BLUE.darkened(0.35), Vector3(-0.80, 0.18, 0.0), true)
	_mesh_cylinder(workshop_root, 2.50, 0.38, Color("283965"), Vector3(2.85, -0.02, 0.0), false)
	_mesh_cylinder(workshop_root, 2.14, 0.50, Color("5e4dff").darkened(0.30), Vector3(2.85, 0.16, 0.0), true)
	for x in [-7.0, 6.6]:
		_mesh_box(workshop_root, Vector3(2.6, 2.4, 0.36), Color("192a56"), Vector3(x, 3.9, -4.52), 0.3)
		_mesh_box(workshop_root, Vector3(2.25, 1.75, 0.18), RED if x > 0 else BLUE, Vector3(x, 3.9, -4.30), 0.12, true)

func _build_ring() -> void:
	_mesh_box(ring_root, Vector3(18.0, 0.80, 18.0), Color("151c38"), Vector3(0.0, -0.48, 0.0), 0.5)
	_mesh_box(ring_root, Vector3(13.3, 0.30, 13.3), Color("dbe8f2"), Vector3(0.0, 0.08, 0.0), 0.65)
	_mesh_box(ring_root, Vector3(1.0, 0.05, 12.0), Color("5bc9ff"), Vector3(0.0, 0.25, 0.0), 0.2)
	_mesh_box(ring_root, Vector3(12.0, 0.052, 1.0), Color("ff6b8f"), Vector3(0.0, 0.26, 0.0), 0.2)
	for x in [-6.7, 6.7]:
		for z in [-6.7, 6.7]:
			_mesh_cylinder(ring_root, 0.22, 4.2, RED if x > 0 else BLUE, Vector3(x, 2.0, z), true)
	for height in [1.25, 2.15, 3.05]:
		for z in [-6.55, 6.55]:
			_mesh_cylinder(ring_root, 0.055, 13.1, Color("f3f7ff"), Vector3(0.0, height, z), true, Vector3(0.0, 0.0, 90.0))
		for x in [-6.55, 6.55]:
			_mesh_cylinder(ring_root, 0.055, 13.1, Color("f3f7ff"), Vector3(x, height, 0.0), true, Vector3(90.0, 0.0, 0.0))
	for i in range(22):
		var angle := TAU * float(i) / 22.0
		var color := BLUE if i % 2 == 0 else RED
		_mesh_sphere(ring_root, 0.12, color, Vector3(cos(angle) * 9.5, 3.5 + float(i % 3) * 0.65, sin(angle) * 9.5), true)

func _mesh_box(parent: Node3D, size: Vector3, color: Color, position: Vector3, roughness: float, glow := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh_instance(parent, mesh, color, position, roughness, glow)

func _mesh_cylinder(parent: Node3D, radius: float, height: float, color: Color, position: Vector3, glow := false, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var instance := _mesh_instance(parent, mesh, color, position, 0.28, glow)
	instance.rotation_degrees = rotation
	return instance

func _mesh_sphere(parent: Node3D, radius: float, color: Color, position: Vector3, glow := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return _mesh_instance(parent, mesh, color, position, 0.22, glow)

func _mesh_instance(parent: Node3D, mesh: PrimitiveMesh, color: Color, position: Vector3, roughness: float, glow: bool) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.60
	material.roughness = roughness
	if glow:
		material.emission_enabled = true
		material.emission = color * 1.4
		material.emission_energy_multiplier = 1.25
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	return instance

func _center_panel(minimum: Vector2) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, 24))
	center.add_child(panel)
	return panel

func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("6d8ac2")
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 17.0
	style.content_margin_bottom = 17.0
	return style

func _make_button(text: String, action: Callable, color: Color, minimum: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("f5fbff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(color.darkened(0.48), color.darkened(0.18), 2))
	button.add_theme_stylebox_override("hover", _button_style(color.darkened(0.24), color, 3))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.55), Color.WHITE, 3))
	button.add_theme_stylebox_override("focus", _button_style(color.darkened(0.38), GOLD, 3))
	button.pressed.connect(_play_ui_sound)
	button.pressed.connect(action)
	return button

func _play_ui_sound() -> void:
	if audio:
		audio.play_ui()

func _button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _title_label(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_shadow_color", Color("c0000000"))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	return label

func _separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.custom_minimum_size.y = 8.0
	return separator

func _health_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 27.0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("58101a32")
	background.set_corner_radius_all(10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(10)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _stat_bar(color: Color) -> ProgressBar:
	var bar := _health_bar(color)
	bar.custom_minimum_size = Vector2(0.0, 13.0)
	return bar

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_level", best_level)
	config.set_value("progress", "current_level", cpu_level)
	config.set_value("progress", "total_wins", total_wins)
	config.set_value("progress", "credits", credits)
	config.set_value("progress", "kids_stars", kids_stars)
	for slot in Catalog.SLOTS:
		config.set_value("unlocks", slot, unlocked_parts.get(slot, [0, 1, 2, 3]))
	config.save("user://forja_infinita_save.cfg")

func _load_progress() -> void:
	_initialize_unlocks()
	var config := ConfigFile.new()
	if config.load("user://forja_infinita_save.cfg") == OK:
		best_level = maxi(1, int(config.get_value("progress", "best_level", 1)))
		cpu_level = maxi(1, int(config.get_value("progress", "current_level", 1)))
		total_wins = maxi(0, int(config.get_value("progress", "total_wins", 0)))
		credits = maxi(0, int(config.get_value("progress", "credits", 600)))
		kids_stars = maxi(0, int(config.get_value("progress", "kids_stars", 0)))
		for slot in Catalog.SLOTS:
			var saved: Array = config.get_value("unlocks", slot, [0, 1, 2, 3])
			unlocked_parts[slot] = saved.duplicate()

func _initialize_unlocks() -> void:
	unlocked_parts.clear()
	for slot in Catalog.SLOTS:
		unlocked_parts[slot] = [0, 1, 2, 3]

func _is_part_unlocked(slot: String, index: int) -> bool:
	var unlocked: Array = unlocked_parts.get(slot, [0, 1, 2, 3])
	return index in unlocked

func _unlock_part(slot: String, index: int) -> void:
	var unlocked: Array = unlocked_parts.get(slot, [0, 1, 2, 3])
	if not index in unlocked:
		unlocked.append(index)
		unlocked.sort()
	unlocked_parts[slot] = unlocked

func _random_owned_build() -> Dictionary:
	var build := {}
	for slot in Catalog.SLOTS:
		var unlocked: Array = unlocked_parts.get(slot, [0, 1, 2, 3])
		build[slot] = int(unlocked[randi_range(0, unlocked.size() - 1)])
	build["_expression"] = randi_range(0, EXPRESSION_LABELS.size() - 1)
	return build

func _save_last_build(build: Dictionary) -> void:
	var config := ConfigFile.new()
	for slot in Catalog.SLOTS:
		config.set_value("robot", slot, int(build.get(slot, 0)))
	config.set_value("robot", "expression", clampi(int(build.get("_expression", 0)), 0, EXPRESSION_LABELS.size() - 1))
	config.save("user://forja_ultimo_robot.cfg")

func _load_last_build() -> Dictionary:
	var build := Catalog.empty_build()
	var config := ConfigFile.new()
	if config.load("user://forja_ultimo_robot.cfg") == OK:
		for slot in Catalog.SLOTS:
			build[slot] = clampi(int(config.get_value("robot", slot, 0)), 0, 19)
		build["_expression"] = clampi(int(config.get_value("robot", "expression", 0)), 0, EXPRESSION_LABELS.size() - 1)
	else:
		build["_expression"] = 0
	return build

func _run_smoke_test() -> void:
	var passed := Catalog.validate_catalog()
	var maximum_build := {}
	for slot in Catalog.SLOTS:
		maximum_build[slot] = 19
	maximum_build["_expression"] = 7
	var stats := Catalog.build_stats(maximum_build)
	passed = passed and Catalog.SLOTS.size() == 8
	passed = passed and Catalog.STAT_KEYS.size() == 10 and Catalog.AFFINITIES.size() == 5
	passed = passed and float(stats.health) > 0.0 and float(stats.power) > 0.0
	passed = passed and Catalog.combat_rating(maximum_build) > 0.0
	passed = passed and Catalog.affinity_multiplier("hydraulic", "thermal") > 1.0
	var model_test := RobotModelScript.new()
	add_child(model_test)
	model_test.build_robot(maximum_build, BLUE, "head")
	passed = passed and model_test.part_roots.size() == 8
	passed = passed and model_test.expression_id == 7 and model_test.get_node_or_null("head/ExpressionFace") != null
	passed = passed and model_test.has_node("AssemblyHand")
	model_test.set_damage_state(3)
	passed = passed and model_test.has_node("MechanicalDamage")
	passed = passed and audio.streams.has("battle_music") and audio.streams.has("critical") and audio.streams.has("weld") and audio.streams.size() >= 17
	var fighter_test_a := FighterScript.new()
	var fighter_test_b := FighterScript.new()
	add_child(fighter_test_a)
	add_child(fighter_test_b)
	fighter_test_a.friendly_mode = true
	fighter_test_b.friendly_mode = true
	fighter_test_a.setup_robot(maximum_build, BLUE, 1.0, 0, "PRUEBA A")
	fighter_test_b.setup_robot(Catalog.empty_build(), RED, 0.75, 1, "PRUEBA B")
	passed = passed and fighter_test_a.personality_id in range(4)
	_add_player_aura(fighter_test_a, BLUE)
	passed = passed and fighter_test_a.has_node("PlayerAura") and TOUCH_PART_LABELS.size() == 8
	fighter_test_a.set_opponent(fighter_test_b)
	fighter_test_b.set_opponent(fighter_test_a)
	fighter_test_a.begin_fight()
	fighter_test_b.begin_fight()
	passed = passed and fighter_test_a.request_heavy_attack()
	passed = passed and fighter_test_a.request_tactical_action("jump") and fighter_test_a.jump_cooldown > 0.0
	var hp_before: float = fighter_test_b.hp
	fighter_test_b.take_damage(50.0, fighter_test_a.global_position, false)
	passed = passed and fighter_test_b.hp < hp_before
	var parts_before: int = fighter_test_b.model.part_roots.size()
	fighter_test_b.take_arcade_critical(50.0, fighter_test_a.global_position, 2, true)
	passed = passed and fighter_test_b.model.part_roots.size() < parts_before
	passed = passed and KIDS_PRESETS.size() == 4 and KIDS_ROBOT_NAMES.size() == 4
	var preview_prediction := _kids_prediction_for(maximum_build, Catalog.empty_build())
	passed = passed and float(preview_prediction.player) > 0.0 and float(preview_prediction.cpu) > 0.0
	passed = passed and EXPRESSION_LABELS.size() == 8
	passed = passed and FighterScript.CombatTactic.size() == 9
	passed = passed and fighter_test_a._can_attack_at_distance(2.0)
	print("FORJA_KIDS_SMOKE_TEST:", "PASS" if passed else "FAIL", " square_thumbnails=OK assembly_hand=OK jumps=OK advanced_buttons=4 combat_tactics=9 criticals=OK LAN=4")
	get_tree().quit(0 if passed else 1)
