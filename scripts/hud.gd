extends Control
## ゲームHUD（ステータスバー・メッセージログ・インベントリ画面）

var game_ref: Node = null   # game.gd への参照

const BAR_H     := 100      # 下部ステータスバーの高さ
const MSG_W     := 0        # メッセージ表示はバー内
const MSG_LINES := 6        # 表示するメッセージ行数

func _draw() -> void:
	if game_ref == null:
		return
	var vp := get_viewport_rect().size

	match game_ref.game_state:
		"inventory":
			_draw_hud_base(vp)
			_draw_inventory(vp)
		"dead":
			_draw_hud_base(vp)
			_draw_game_over(vp)
		"victory":
			_draw_hud_base(vp)
			_draw_victory(vp)
		_:
			_draw_hud_base(vp)

# ─── 通常HUD ─────────────────────────────────────────────
func _draw_hud_base(vp: Vector2) -> void:
	var font      := ThemeDB.fallback_font
	var font_bold := ThemeDB.fallback_font

	# ステータスバー背景
	var bar_rect := Rect2(0, vp.y - BAR_H, vp.x, BAR_H)
	draw_rect(bar_rect, Color(0.05, 0.05, 0.08, 0.97))
	draw_line(Vector2(0, vp.y - BAR_H), Vector2(vp.x, vp.y - BAR_H), Color(0.3, 0.3, 0.4))

	var gref := game_ref
	var bx   := 12.0
	var by   := vp.y - BAR_H + 22.0

	# ── HP ──────────────────────────────────────────────
	draw_string(font, Vector2(bx, by), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.7))
	by += 4
	_draw_bar(Vector2(bx, by + 2), 140, 14,
		float(gref.p_hp) / float(gref.p_hp_max),
		Color(0.85, 0.15, 0.15), Color(0.30, 0.08, 0.08))
	by += 4
	draw_string(font, Vector2(bx + 145, by - 2),
		"%d / %d" % [gref.p_hp, gref.p_hp_max],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))
	by += 18

	# ── 満腹度 ───────────────────────────────────────────
	draw_string(font, Vector2(bx, by), "腹", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.7))
	by += 4
	var hunger_color := Color(0.20, 0.70, 0.20)
	if gref.p_fullness < 30:
		hunger_color = Color(0.90, 0.30, 0.10)
	elif gref.p_fullness < 60:
		hunger_color = Color(0.85, 0.75, 0.10)
	_draw_bar(Vector2(bx, by + 2), 140, 10,
		float(gref.p_fullness) / 100.0,
		hunger_color, Color(0.15, 0.15, 0.15))
	by += 18

	# ── ステータス数値 ───────────────────────────────────
	var sx := bx + 300.0
	var sy := vp.y - BAR_H + 22.0
	draw_string(font, Vector2(sx, sy),
		"LV %d" % gref.p_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.85, 0.25))
	sy += 20
	draw_string(font, Vector2(sx, sy),
		"EXP %d/%d" % [gref.p_exp, gref.p_exp_next], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.75, 0.75))
	sy += 20
	draw_string(font, Vector2(sx, sy),
		"ATK %d  DEF %d" % [gref.calc_atk(), gref.calc_def()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.85, 0.85))

	# ── 装備欄 ───────────────────────────────────────────
	var ex := sx + 160.0
	var ey := vp.y - BAR_H + 22.0
	draw_string(font, Vector2(ex, ey),
		"剣: %s" % _item_name(gref.p_weapon),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.80, 0.80, 0.90))
	ey += 18
	draw_string(font, Vector2(ex, ey),
		"盾: %s" % _item_name(gref.p_shield),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.65, 0.45))
	ey += 18
	draw_string(font, Vector2(ex, ey),
		"指: %s" % _item_name(gref.p_ring),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.90, 0.55, 0.20))

	# ── フロア番号 ───────────────────────────────────────
	var fx := vp.x - 110.0
	var fy := vp.y - BAR_H + 30.0
	draw_string(font_bold, Vector2(fx, fy),
		"B%dF" % gref.current_floor,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.95, 0.75))
	fy += 28
	draw_string(font, Vector2(fx, fy),
		"Turn %d" % gref.turn_count,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.55, 0.55))

	# ── メッセージログ ────────────────────────────────────
	_draw_messages(vp, font)

func _draw_bar(pos: Vector2, width: int, height: int,
		ratio: float, fill: Color, bg: Color) -> void:
	draw_rect(Rect2(pos, Vector2(width, height)), bg)
	draw_rect(Rect2(pos, Vector2(width * clampf(ratio, 0.0, 1.0), height)), fill)
	draw_rect(Rect2(pos, Vector2(width, height)), Color(0.5, 0.5, 0.5, 0.5), false, 1.0)

func _draw_messages(vp: Vector2, font: Font) -> void:
	var msgs: Array = game_ref.messages
	var total: int = msgs.size()
	var start: int = max(0, total - MSG_LINES)
	var my: float = vp.y - BAR_H - MSG_LINES * 20 - 8
	# 半透明背景
	draw_rect(Rect2(0, my - 4, 500, MSG_LINES * 20 + 8), Color(0, 0, 0, 0.55))
	for i in range(start, total):
		var age   := total - 1 - i
		var alpha := 1.0 - age * 0.15
		draw_string(font, Vector2(8, my + (i - start) * 20 + 16),
			msgs[i], HORIZONTAL_ALIGNMENT_LEFT, 490, 14, Color(1, 1, 1, alpha))

func _item_name(item: Dictionary) -> String:
	if item.is_empty():
		return "なし"
	return item.get("name", "?")

# ─── インベントリ画面 ─────────────────────────────────────
func _draw_inventory(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var gref := game_ref
	# 半透明オーバーレイ
	draw_rect(Rect2(0, 0, vp.x, vp.y - BAR_H), Color(0, 0, 0, 0.80))

	var title_x := vp.x / 2.0 - 120.0
	var title_y := 40.0
	draw_string(font, Vector2(title_x, title_y), "─── インベントリ ───",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.95, 0.85, 0.25))

	var inv: Array = gref.p_inventory
	if inv.is_empty():
		draw_string(font, Vector2(title_x, title_y + 40),
			"（アイテムなし）", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.6, 0.6))
	else:
		for i in inv.size():
			var item:  Dictionary = inv[i]
			var iy := title_y + 36 + i * 26
			var selected: bool = (i == gref.inv_cursor)
			var bg_col := Color(0.20, 0.25, 0.35, 0.85) if selected else Color(0, 0, 0, 0)
			draw_rect(Rect2(title_x - 8, iy - 18, 500, 24), bg_col)
			var tag := _equip_tag(gref, item)
			var col := ItemData.type_color(item.get("type", 0)) if not selected else Color.WHITE
			draw_string(font,
				Vector2(title_x, iy),
				"%s%s %s" % [ItemData.type_symbol(item.get("type", 0)), tag, item.get("name", "?")],
				HORIZONTAL_ALIGNMENT_LEFT, 490, 15, col)

	# 操作ガイド
	var gy := vp.y - BAR_H - 30.0
	draw_rect(Rect2(0, gy - 4, vp.x, 30), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(8, gy + 16),
		"[↑↓] 選択   [Enter/Z] 使う/装備   [D] 捨てる   [I/Esc] 閉じる",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.70, 0.70, 0.70))

func _equip_tag(gref: Node, item: Dictionary) -> String:
	var id: String = item.get("id", "")
	if gref.p_weapon.get("id", "") == id: return "[剣]"
	if gref.p_shield.get("id", "") == id: return "[盾]"
	if gref.p_ring.get("id","")   == id: return "[指]"
	return "    "

# ─── ゲームオーバー ───────────────────────────────────────
func _draw_game_over(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, vp.x, vp.y - BAR_H), Color(0, 0, 0, 0.88))
	draw_string(font, Vector2(vp.x / 2 - 110, vp.y / 2 - 50),
		"あなたは倒れた…", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.85, 0.15, 0.15))
	draw_string(font, Vector2(vp.x / 2 - 150, vp.y / 2),
		"B%dF  LV%d  Turn%d" % [game_ref.current_floor, game_ref.p_level, game_ref.turn_count],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.75, 0.75))
	draw_string(font, Vector2(vp.x / 2 - 100, vp.y / 2 + 50),
		"[R] でリスタート", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.75, 0.75))

# ─── 勝利 ─────────────────────────────────────────────────
func _draw_victory(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, vp.x, vp.y - BAR_H), Color(0.02, 0.02, 0.06, 0.88))
	draw_string(font, Vector2(vp.x / 2 - 160, vp.y / 2 - 50),
		"遺産を持ち帰った！", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.95, 0.85, 0.10))
	draw_string(font, Vector2(vp.x / 2 - 150, vp.y / 2),
		"LV%d  Turn%d  おめでとう！" % [game_ref.p_level, game_ref.turn_count],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.90, 0.90, 0.60))
	draw_string(font, Vector2(vp.x / 2 - 100, vp.y / 2 + 50),
		"[R] でリスタート", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.75, 0.75))
