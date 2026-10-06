extends CanvasLayer

@onready var health_label: Label = $Margin/VBox/Health
@onready var wave_label: Label = $Margin/VBox/Wave
@onready var kills_label: Label = $Margin/VBox/Kills
@onready var stamina_label: Label = $Margin/VBox/Stamina
@onready var weapon_label: Label = $Margin/VBox/Weapon
@onready var card_picker: Control = $CardPicker
@onready var center_label: Label = $CenterMessage
@onready var menu_panel: PanelContainer = $MenuPanel
@onready var join_ip: LineEdit = $MenuPanel/Margin/VBox/JoinIP
@onready var status_label: Label = $MenuPanel/Margin/VBox/Status
@onready var perf_label: Label = $PerfPanel/Margin/VBox/Perf
@onready var peer_label: Label = $PerfPanel/Margin/VBox/Peer
@onready var console_panel: PanelContainer = $ConsolePanel
@onready var console_log: RichTextLabel = $ConsolePanel/Margin/VBox/Log
@onready var console_input: LineEdit = $ConsolePanel/Margin/VBox/Command
@onready var gameplay_hud: MarginContainer = $Margin
@onready var crosshair: Control = $Crosshair
@onready var threat_indicator: Control = $ThreatIndicator

var kills: int = 0
var last_frame_ms: float = 0.0

signal play_solo_requested
signal host_requested
signal join_requested(address: String)
signal command_submitted(command: String)
signal console_visibility_changed(visible_state: bool)
signal card_picked(card_id: StringName)

func _ready() -> void:
	center_label.text = ""
	center_label.modulate.a = 0.0
	console_panel.visible = false
	console_log.clear()
	add_console_line("Console ready. Type 'help' for commands.")
	_update_perf_labels()
	gameplay_hud.visible = not menu_panel.visible
	if crosshair:
		crosshair.visible = not menu_panel.visible
	if threat_indicator:
		threat_indicator.visible = not menu_panel.visible
	if card_picker and card_picker.has_signal("card_picked"):
		card_picker.card_picked.connect(_on_card_picked)
	if SynergyManager and SynergyManager.has_signal("synergy_activated"):
		SynergyManager.synergy_activated.connect(_on_synergy_activated)

func _on_synergy_activated(synergy: Dictionary) -> void:
	var name_str: String = synergy.get("name", "Synergy")
	var desc_str: String = synergy.get("desc", "")
	flash_message("⚡ SYNERGY UNLOCKED: %s ⚡\n%s" % [name_str.to_upper(), desc_str], 3.5)
	add_console_line("★ [Synergy] Activated: %s - %s" % [name_str, desc_str])

func _on_card_picked(card_id: StringName) -> void:
	card_picked.emit(card_id)

func show_card_picker(card_ids: Array, wave_index: int) -> void:
	if card_picker == null:
		return
	card_picker.show_offer(card_ids, wave_index)

func hide_card_picker() -> void:
	if card_picker == null:
		return
	card_picker.hide_picker()

func mark_card_picker_waiting(message: String) -> void:
	if card_picker == null:
		return
	card_picker.show_waiting(message)

func is_card_picker_visible() -> bool:
	return card_picker != null and card_picker.visible

var _current_weapon_idx: int = 0
var _current_weapon_name: String = "Pistol"
var _cached_element_name: StringName = &""
var _tracked_player: Node = null

func _process(delta: float) -> void:
	last_frame_ms = delta * 1000.0
	_update_perf_labels()
	_update_element_indicator()

func _update_element_indicator() -> void:
	if _tracked_player == null or not is_instance_valid(_tracked_player):
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p):
				if p.has_method("_is_locally_controlled") and p._is_locally_controlled():
					_tracked_player = p
					break
				elif not p.has_method("_is_locally_controlled"):
					_tracked_player = p
					break
	if _tracked_player == null:
		return
	if "projectile_index" in _tracked_player and "PROJECTILE_ELEMENTS" in _tracked_player:
		var elems: Array = _tracked_player.PROJECTILE_ELEMENTS
		var idx: int = _tracked_player.projectile_index
		if not elems.is_empty():
			var cur_elem: Dictionary = elems[idx % elems.size()]
			var elem_name: StringName = cur_elem.get("name", &"")
			if elem_name != _cached_element_name:
				_cached_element_name = elem_name
				_refresh_weapon_label()

func _refresh_weapon_label() -> void:
	if _cached_element_name != &"":
		weapon_label.text = "WPN [%d] %s  |  %s" % [_current_weapon_idx + 1, _current_weapon_name, _cached_element_name.to_upper()]
	else:
		weapon_label.text = "WPN [%d] %s" % [_current_weapon_idx + 1, _current_weapon_name]

func reset_for_session() -> void:
	kills = 0
	kills_label.text = "Kills 0"
	center_label.text = ""
	center_label.modulate.a = 0.0
	_cached_element_name = &""
	_tracked_player = null
	add_console_line("Session reset.")

func set_health(value: int, max_value: int) -> void:
	health_label.text = "HP %d / %d" % [value, max_value]

func set_stamina(value: float, max_value: float) -> void:
	stamina_label.text = "STAM %d / %d" % [int(round(value)), int(round(max_value))]

func set_weapon(index: int, weapon_name: String) -> void:
	_current_weapon_idx = index
	_current_weapon_name = weapon_name
	_refresh_weapon_label()

func set_wave(wave: int, total: int) -> void:
	wave_label.text = "Wave %d  (%d zombies)" % [wave, total]
	flash_message("WAVE %d" % wave, 1.6)
	add_console_line("Wave %d started with %d zombies." % [wave, total])

func register_kill(_remaining: int) -> void:
	kills += 1
	kills_label.text = "Kills %d" % kills

func set_kills(value: int) -> void:
	kills = value
	kills_label.text = "Kills %d" % kills

func flash_message(msg: String, duration: float) -> void:
	center_label.text = msg
	center_label.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(duration)
	t.tween_property(center_label, "modulate:a", 0.0, 0.6)

func show_persistent(msg: String, color: Color) -> void:
	center_label.text = msg
	center_label.modulate = Color(color.r, color.g, color.b, 1)

func show_win() -> void:
	show_persistent("YOU SURVIVED", Color(0.4, 0.85, 0.5))
	add_console_line("Run complete: survived all waves.")

func show_lose() -> void:
	show_persistent("TEAM WIPED", Color(0.95, 0.35, 0.45))
	add_console_line("Run failed: team wiped.")

func show_menu(visible_state: bool) -> void:
	menu_panel.visible = visible_state
	gameplay_hud.visible = not visible_state
	if crosshair:
		crosshair.visible = not visible_state
	if threat_indicator:
		threat_indicator.visible = not visible_state

func show_hitmarker(hit_type: String = "body") -> void:
	if crosshair and crosshair.has_method("flash_hit"):
		crosshair.flash_hit(hit_type)

func is_menu_visible() -> bool:
	return menu_panel.visible

func set_status(message: String) -> void:
	status_label.text = message
	peer_label.text = message
	add_console_line(message)

func toggle_console() -> void:
	set_console_visible(not console_panel.visible)

func set_console_visible(visible_state: bool) -> void:
	console_panel.visible = visible_state
	if visible_state:
		console_input.grab_focus()
	else:
		console_input.release_focus()
	console_visibility_changed.emit(visible_state)

func is_console_visible() -> bool:
	return console_panel.visible

func add_console_line(message: String) -> void:
	console_log.append_text("%s\n" % message)
	console_log.scroll_to_line(console_log.get_line_count())

func clear_console() -> void:
	console_log.clear()

func _update_perf_labels() -> void:
	var fps := Engine.get_frames_per_second()
	perf_label.text = "FPS %d\nMS %.2f" % [fps, last_frame_ms]

func _on_solo_pressed() -> void:
	play_solo_requested.emit()

func _on_host_pressed() -> void:
	host_requested.emit()

func _on_join_pressed() -> void:
	join_requested.emit(join_ip.text)

func _on_command_text_submitted(new_text: String) -> void:
	var trimmed := new_text.strip_edges()
	if trimmed.is_empty():
		console_input.text = ""
		return
	add_console_line("> %s" % trimmed)
	command_submitted.emit(trimmed)
	console_input.text = ""
