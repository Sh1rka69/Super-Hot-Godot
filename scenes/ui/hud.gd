extends CanvasLayer

## HUD for "Very Hot"
## Manages Crosshair, Time Scale feedback, Victory/Defeat overlays, and Damage Vignette.

@onready var crosshair = $Control/Crosshair
@onready var banner_label = $Control/BannerLabel
@onready var time_meter = $Control/TimeMeter
@onready var damage_vignette = $Control/DamageVignette
@onready var victory_panel = $Control/VictoryPanel
@onready var victory_label_1 = $Control/VictoryPanel/SuperLabel
@onready var victory_label_2 = $Control/VictoryPanel/HotLabel
@onready var defeat_panel = $Control/DefeatPanel
@onready var victory_restart_btn = $Control/VictoryPanel/RestartButton
@onready var defeat_restart_btn = $Control/DefeatPanel/RestartButton

func _ready() -> void:
	if victory_panel:
		victory_panel.visible = false
	if defeat_panel:
		defeat_panel.visible = false
	if damage_vignette:
		damage_vignette.modulate.a = 0.0
	
	_show_intro_banner()
	
	GameManager.time_scale_changed.connect(_on_time_scale_changed)
	GameManager.victory_achieved.connect(_on_victory)
	GameManager.player_damaged.connect(_on_player_damaged)
	
	if victory_restart_btn:
		victory_restart_btn.pressed.connect(_on_restart_pressed)
	if defeat_restart_btn:
		defeat_restart_btn.pressed.connect(_on_restart_pressed)

func _show_intro_banner() -> void:
	if banner_label:
		banner_label.text = "TIME MOVES ONLY WHEN YOU MOVE"
		banner_label.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_interval(2.5)
		tween.tween_property(banner_label, "modulate:a", 0.0, 1.0)

func _on_time_scale_changed(scale_val: float) -> void:
	if time_meter:
		time_meter.value = scale_val * 100.0

func _on_player_damaged(hp: int) -> void:
	if damage_vignette:
		var tween = create_tween()
		tween.tween_property(damage_vignette, "modulate:a", 0.6, 0.05)
		tween.tween_property(damage_vignette, "modulate:a", 0.0, 0.4)
	
	if hp <= 0:
		_on_defeat()

func _on_victory() -> void:
	SoundManager.play_victory()
	if victory_panel:
		victory_panel.visible = true
		_animate_superhot_text()

func _animate_superhot_text() -> void:
	if victory_label_1 and victory_label_2:
		victory_label_1.visible = true
		victory_label_2.visible = false
		
		var loop_tween = create_tween().set_loops(6)
		loop_tween.tween_callback(func():
			victory_label_1.visible = true
			victory_label_2.visible = false
		)
		loop_tween.tween_interval(0.4)
		loop_tween.tween_callback(func():
			victory_label_1.visible = false
			victory_label_2.visible = true
		)
		loop_tween.tween_interval(0.4)

func _on_defeat() -> void:
	if defeat_panel:
		defeat_panel.visible = true

func _on_restart_pressed() -> void:
	GameManager.restart_game()
