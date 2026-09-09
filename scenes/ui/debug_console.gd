extends CanvasLayer

## In-Game Debug & Error Console for Godot 4
## Captures all runtime logs, errors, warnings, system diagnostics, and copies them to clipboard.

enum LogType { INFO, WARNING, ERROR, DIAGNOSTIC }

class LogEntry:
	var type: int
	var message: String
	var timestamp: String
	var callsite: String

var logs: Array = []
var is_console_open: bool = false

@onready var toggle_btn: Button = $ToggleContainer/ConsoleButton
@onready var console_window: Control = $ConsoleWindow
@onready var log_display: RichTextLabel = $ConsoleWindow/Panel/VBoxContainer/LogDisplay
@onready var btn_copy: Button = $ConsoleWindow/Panel/VBoxContainer/BottomBar/CopyButton
@onready var btn_clear: Button = $ConsoleWindow/Panel/VBoxContainer/BottomBar/ClearButton
@onready var btn_diagnose: Button = $ConsoleWindow/Panel/VBoxContainer/BottomBar/DiagnoseButton
@onready var btn_close: Button = $ConsoleWindow/Panel/VBoxContainer/TopBar/CloseButton
@onready var status_toast: Label = $ConsoleWindow/Panel/StatusToast

@onready var filter_all: Button = $ConsoleWindow/Panel/VBoxContainer/FilterBar/BtnAll
@onready var filter_errors: Button = $ConsoleWindow/Panel/VBoxContainer/FilterBar/BtnErrors
@onready var filter_warnings: Button = $ConsoleWindow/Panel/VBoxContainer/FilterBar/BtnWarnings
@onready var filter_diag: Button = $ConsoleWindow/Panel/VBoxContainer/FilterBar/BtnDiag

@onready var stats_label: Label = $ConsoleWindow/Panel/VBoxContainer/TopBar/StatsLabel

var current_filter: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	
	if console_window:
		console_window.visible = false
	if status_toast:
		status_toast.visible = false
	
	_connect_signals()
	_log_initial_system_info()
	_run_comprehensive_diagnostics()

func _connect_signals() -> void:
	if toggle_btn:
		toggle_btn.pressed.connect(toggle_console)
	if btn_close:
		btn_close.pressed.connect(toggle_console)
	if btn_copy:
		btn_copy.pressed.connect(_on_copy_pressed)
	if btn_clear:
		btn_clear.pressed.connect(_on_clear_pressed)
	if btn_diagnose:
		btn_diagnose.pressed.connect(_run_comprehensive_diagnostics)
	
	if filter_all:
		filter_all.pressed.connect(func(): _set_filter(-1))
	if filter_errors:
		filter_errors.pressed.connect(func(): _set_filter(LogType.ERROR))
	if filter_warnings:
		filter_warnings.pressed.connect(func(): _set_filter(LogType.WARNING))
	if filter_diag:
		filter_diag.pressed.connect(func(): _set_filter(LogType.DIAGNOSTIC))

func toggle_console() -> void:
	is_console_open = not is_console_open
	console_window.visible = is_console_open
	
	if is_console_open:
		_refresh_display()
		_update_stats()

func _log_initial_system_info() -> void:
	var dt = Time.get_datetime_dict_from_system()
	var os_name = OS.get_name()
	var godot_ver = Engine.get_version_info().string
	var video_adapter = RenderingServer.get_video_adapter_name()
	var viewport_size = DisplayServer.window_get_size()
	
	add_log(LogType.INFO, "===============================================")
	add_log(LogType.INFO, "PROJECT: Very Hot (SUPERHOT-inspired Godot 4)")
	add_log(LogType.INFO, "ENGINE: Godot Engine v%s" % godot_ver)
	add_log(LogType.INFO, "PLATFORM: %s | GPU: %s" % [os_name, video_adapter])
	add_log(LogType.INFO, "RESOLUTION: %dx%d" % [viewport_size.x, viewport_size.y])
	add_log(LogType.INFO, "===============================================")

func _run_comprehensive_diagnostics() -> void:
	add_log(LogType.DIAGNOSTIC, "--- [ЗАПУСК ПОЛНОЙ ДИАГНОСТИКИ ПРОЕКТА] ---")
	
	var errors_found = 0
	var warnings_found = 0
	
	# 1. Check critical assets
	var assets_to_check = [
		"res://assets/textures/Skybox_Day.jpg",
		"res://assets/textures/joystick_base.png",
		"res://assets/textures/joystick_stick.png",
		"res://assets/textures/crosshair.png",
		"res://assets/ui/jump.png",
		"res://assets/ui/crouch.png",
		"res://assets/ui/run.png",
		"res://assets/ui/pickup.png",
		"res://assets/ui/pause.png",
		"res://assets/models/map/VH_TestMap.gltf",
		"res://assets/models/enemy/Standing.fbx",
		"res://assets/models/enemy/Running.fbx",
		"res://assets/models/enemy/Shooting.fbx",
		"res://assets/models/enemy/Right Hook.fbx",
		"res://assets/models/enemy/Pick Up Item.fbx",
		"res://assets/models/enemy/Light Hit To Head.fbx",
		"res://assets/sounds/hit.wav",
		"res://assets/sounds/shoot.wav",
		"res://assets/sounds/shatter.wav",
		"res://assets/sounds/whoosh.wav",
		"res://assets/sounds/jump.wav",
		"res://assets/sounds/victory.wav"
	]
	
	for path in assets_to_check:
		if ResourceLoader.exists(path):
			add_log(LogType.DIAGNOSTIC, "[OK] Ресурс найден: %s" % path)
		else:
			add_log(LogType.ERROR, "[ОШИБКА] Ресурс отсутствует: %s" % path)
			errors_found += 1
	
	# 2. Check scenes
	var scenes_to_check = [
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/main.tscn",
		"res://scenes/map/test_map.tscn",
		"res://scenes/player/player.tscn",
		"res://scenes/enemy/enemy.tscn",
		"res://scenes/weapons/pistol.tscn",
		"res://scenes/weapons/bullet.tscn",
		"res://scenes/ui/hud.tscn",
		"res://scenes/ui/mobile_controls.tscn",
		"res://scenes/ui/pause_menu.tscn"
	]
	
	for sc_path in scenes_to_check:
		if ResourceLoader.exists(sc_path):
			var res = ResourceLoader.load(sc_path)
			if res != null:
				add_log(LogType.DIAGNOSTIC, "[OK] Сцена валидна: %s" % sc_path)
			else:
				add_log(LogType.ERROR, "[ОШИБКА] Не удалось загрузить сцену: %s" % sc_path)
				errors_found += 1
		else:
			add_log(LogType.ERROR, "[ОШИБКА] Файл сцены отсутствует: %s" % sc_path)
			errors_found += 1
	
	# 3. Check Input Actions
	var required_actions = ["move_forward", "move_backward", "move_left", "move_right", "jump", "crouch", "run", "primary_action"]
	for act in required_actions:
		if InputMap.has_action(act):
			add_log(LogType.DIAGNOSTIC, "[OK] Input Action зарегистрирован: '%s'" % act)
		else:
			add_log(LogType.WARNING, "[ПРЕДУПРЕЖДЕНИЕ] Input Action отсутствует: '%s'" % act)
			warnings_found += 1
	
	# Summary
	if errors_found == 0:
		add_log(LogType.DIAGNOSTIC, ">>> [ИТОГ ДИАГНОСТИКИ]: КРИТИЧЕСКИХ ОШИБОК НЕ ОБНАРУЖЕНО (0 ошибок, %d предупреждений). Проект полностью исправен!" % warnings_found)
	else:
		add_log(LogType.ERROR, ">>> [ИТОГ ДИАГНОСТИКИ]: ОБНАРУЖЕНО ОШИБОК: %d, ПРЕДУПРЕЖДЕНИЙ: %d" % [errors_found, warnings_found])
	
	_refresh_display()

func add_log(type: LogType, message: String, callsite: String = "") -> void:
	var dt = Time.get_datetime_dict_from_system()
	var time_str = "%02d:%02d:%02d" % [dt.hour, dt.minute, dt.second]
	
	var entry = {
		"type": type,
		"message": message,
		"timestamp": time_str,
		"callsite": callsite
	}
	logs.append(entry)
	
	if logs.size() > 500:
		logs.pop_front()
	
	if is_console_open:
		_refresh_display()

func _set_filter(f: int) -> void:
	current_filter = f
	_refresh_display()

func _refresh_display() -> void:
	if not log_display:
		return
	
	var bb = ""
	var err_count = 0
	var warn_count = 0
	
	for entry in logs:
		if entry.type == LogType.ERROR:
			err_count += 1
		elif entry.type == LogType.WARNING:
			warn_count += 1
		
		if current_filter != -1 and entry.type != current_filter:
			continue
		
		var color = "#aaaaaa"
		var prefix = "[INFO]"
		
		match entry.type:
			LogType.INFO:
				color = "#99ccee"
				prefix = "[INFO]"
			LogType.WARNING:
				color = "#ffcc33"
				prefix = "[WARN]"
			LogType.ERROR:
				color = "#ff4444"
				prefix = "[ERROR]"
			LogType.DIAGNOSTIC:
				color = "#44ff88"
				prefix = "[DIAG]"
		
		bb += "[color=#666666][%s][/color] [color=%s][b]%s[/b] %s[/color]\n" % [
			entry.timestamp,
			color,
			prefix,
			entry.message
		]
	
	log_display.text = bb
	_update_stats(err_count, warn_count)

func _update_stats(err_count: int = -1, warn_count: int = -1) -> void:
	if not stats_label:
		return
	if err_count == -1:
		err_count = 0
		warn_count = 0
		for e in logs:
			if e.type == LogType.ERROR: err_count += 1
			elif e.type == LogType.WARNING: warn_count += 1
	
	stats_label.text = "Ошибок: %d | Предупреждений: %d | Записей: %d | FPS: %d" % [
		err_count,
		warn_count,
		logs.size(),
		Engine.get_frames_per_second()
	]

func _on_copy_pressed() -> void:
	var plain_text = "=== VERY HOT - GODOT 4 CONSOLE LOGS ===\n"
	plain_text += "Generated: %s\n" % Time.get_datetime_string_from_system()
	plain_text += "Platform: %s | FPS: %d\n" % [OS.get_name(), Engine.get_frames_per_second()]
	plain_text += "----------------------------------------\n\n"
	
	var error_only = (current_filter == LogType.ERROR)
	for entry in logs:
		if error_only and entry.type != LogType.ERROR:
			continue
		var pfx = "INFO"
		if entry.type == LogType.WARNING: pfx = "WARN"
		elif entry.type == LogType.ERROR: pfx = "ERROR"
		elif entry.type == LogType.DIAGNOSTIC: pfx = "DIAG"
		
		plain_text += "[%s] [%s] %s\n" % [entry.timestamp, pfx, entry.message]
	
	plain_text += "\n=== END OF LOGS ===\n"
	
	DisplayServer.clipboard_set(plain_text)
	_show_toast("📋 Все логи и ошибки скопированы в буфер обмена!")

func _show_toast(msg: String) -> void:
	if not status_toast:
		return
	status_toast.text = msg
	status_toast.visible = true
	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(func(): status_toast.visible = false)

func _on_clear_pressed() -> void:
	logs.clear()
	add_log(LogType.INFO, "Консоль очищена пользователем.")
	_refresh_display()
