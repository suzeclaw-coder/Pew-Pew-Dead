extends Control

# 自绘十字准星 + 多阶命中标记闪烁反馈 + 疾跑/滑铲动态扩散

@export var base_gap: float = 4.0
@export var sprint_bloom: float = 7.0
@export var slide_bloom: float = 11.0
@export var bloom_speed: float = 14.0
@export var length: float = 8.0
@export var thickness: float = 2.0
@export var color: Color = Color(1, 1, 1, 0.9)

# 命中反馈配置
@export var hit_marker_color: Color = Color.WHITE                     # 普通身体命中：白
@export var headshot_marker_color: Color = Color(1.0, 0.85, 0.2)      # 爆头：金黄
@export var leg_marker_color: Color = Color(1.0, 0.55, 0.2)           # 打腿/爬行：琥珀橙
@export var kill_marker_color: Color = Color(1.0, 0.2, 0.15)          # 致命击杀：放大红色

@export var hit_flash_duration: float = 0.18
@export var headshot_flash_duration: float = 0.28
@export var leg_flash_duration: float = 0.22
@export var kill_flash_duration: float = 0.4

@export var hit_marker_length: float = 8.0
@export var hit_marker_thickness: float = 2.5

var current_gap: float = 4.0
var _flash_timer: float = 0.0
var _flash_total: float = 0.0
var _flash_color: Color = Color.WHITE
var _flash_scale: float = 1.0

var _player: Node = null

var show_charge_bar: bool = false
var charge_level: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_gap = base_gap

func _find_local_player() -> Node:
	if _player != null and is_instance_valid(_player):
		return _player
	var tree := get_tree()
	if tree == null:
		return null
	for p in tree.get_nodes_in_group("player"):
		if is_instance_valid(p):
			if p.has_method("_is_locally_controlled"):
				if p._is_locally_controlled():
					_player = p
					return _player
			else:
				_player = p
				return _player
	return null

func _process(delta: float) -> void:
	var needs_redraw := false

	# 1. 动态扩散更新
	var player := _find_local_player()
	var target_gap: float = base_gap
	if player != null and is_instance_valid(player):
		var is_sliding: bool = false
		var is_sprinting: bool = false
		if "slide_timer" in player and player.slide_timer > 0.0:
			is_sliding = true
		elif player.has_method("is_sliding") and player.is_sliding():
			is_sliding = true

		if "sprinting" in player and player.sprinting:
			is_sprinting = true
		elif player.has_method("is_sprinting") and player.is_sprinting():
			is_sprinting = true

		if is_sliding:
			target_gap = base_gap + slide_bloom
		elif is_sprinting:
			target_gap = base_gap + sprint_bloom

		# Pistol charge bar — poll state directly from player
		var charging: bool = player.get("charging_shot") == true and player.get("current_weapon") == 0
		var new_level: float = 0.0
		if charging:
			var ct: float = player.get("charge_time") if "charge_time" in player else 0.0
			var mt: float = player.get("max_charge_time") if "max_charge_time" in player else 1.0
			new_level = clampf(ct / maxf(mt, 0.001), 0.0, 1.0)
		if charging != show_charge_bar or not is_equal_approx(new_level, charge_level):
			show_charge_bar = charging
			charge_level = new_level
			needs_redraw = true

	var new_gap: float = lerpf(current_gap, target_gap, clampf(delta * bloom_speed, 0.0, 1.0))
	if not is_equal_approx(new_gap, current_gap):
		current_gap = new_gap
		needs_redraw = true

	# 2. 命中反馈计时器更新
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		needs_redraw = true

	if needs_redraw:
		queue_redraw()

func flash_hit(hit_type: String = "body") -> void:
	match hit_type:
		"head", "headshot":
			_flash_timer = headshot_flash_duration
			_flash_total = headshot_flash_duration
			_flash_color = headshot_marker_color
			_flash_scale = 1.3
		"leg", "crawl":
			_flash_timer = leg_flash_duration
			_flash_total = leg_flash_duration
			_flash_color = leg_marker_color
			_flash_scale = 1.15
		"kill", "lethal":
			_flash_timer = kill_flash_duration
			_flash_total = kill_flash_duration
			_flash_color = kill_marker_color
			_flash_scale = 1.6
		_: # "body" and fallback
			_flash_timer = hit_flash_duration
			_flash_total = hit_flash_duration
			_flash_color = hit_marker_color
			_flash_scale = 1.0
	queue_redraw()

func flash_headshot() -> void:
	flash_hit("head")

func flash_leg() -> void:
	flash_hit("leg")

func flash_kill() -> void:
	flash_hit("kill")

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var g: float = current_gap

	# 主十字准星
	draw_line(center + Vector2(0, -g), center + Vector2(0, -g - length), color, thickness)
	draw_line(center + Vector2(0, g), center + Vector2(0, g + length), color, thickness)
	draw_line(center + Vector2(-g, 0), center + Vector2(-g - length, 0), color, thickness)
	draw_line(center + Vector2(g, 0), center + Vector2(g + length, 0), color, thickness)

	# 命中标记：4条 45° 斜线（X 形），淡出与轻微放大
	if _flash_timer > 0.0 and _flash_total > 0.0:
		var progress: float = _flash_timer / _flash_total  # 1.0 -> 0.0
		var marker_col: Color = _flash_color
		marker_col.a *= progress
		var scale_factor: float = _flash_scale * (1.0 + (1.0 - progress) * 0.3)
		var off: float = (g + 2.0) * scale_factor
		var len_scaled: float = hit_marker_length * scale_factor
		var thick: float = hit_marker_thickness * (_flash_scale if _flash_scale > 1.2 else 1.0)

		# 四个斜角方向：↗ ↘ ↙ ↖
		var diag: Vector2 = Vector2(1, 1).normalized()
		var anti: Vector2 = Vector2(1, -1).normalized()
		draw_line(center + diag * off, center + diag * (off + len_scaled), marker_col, thick)
		draw_line(center - diag * off, center - diag * (off + len_scaled), marker_col, thick)
		draw_line(center + anti * off, center + anti * (off + len_scaled), marker_col, thick)
		draw_line(center - anti * off, center - anti * (off + len_scaled), marker_col, thick)

	# 手枪蓄力进度条（居中位于准星下方）
	if show_charge_bar and charge_level > 0.0:
		var bar_w: float = 64.0
		var bar_h: float = 6.0
		var bar_pos: Vector2 = center + Vector2(-bar_w * 0.5, g + length + 8.0)
		# 背景底槽
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.1, 0.1, 0.14, 0.8), true)
		# 边框
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.6, 0.6, 0.7, 0.9), false, 1.0)
		# 填充条（随蓄力充盈，颜色从天蓝渐变到高能亮金）
		var fill_col: Color = Color(0.35, 0.75, 1.0).lerp(Color(1.0, 0.88, 0.2), charge_level)
		if charge_level >= 0.99:
			fill_col = Color(1.0, 0.95, 0.4)
		var fill_w: float = clampf(bar_w * charge_level, 0.0, bar_w)
		if fill_w > 0.0:
			draw_rect(Rect2(bar_pos + Vector2(1, 1), Vector2(maxf(0.0, fill_w - 2.0), maxf(0.0, bar_h - 2.0))), fill_col, true)
