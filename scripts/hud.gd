extends Control
## ゲームHUD（ステータスバー・メッセージログ・インベントリ画面）

var game_ref: Node = null   # game.gd への参照

const BAR_H     := 100      # 下部ステータスバーの高さ
const MSG_W     := 0        # メッセージ表示はバー内
const MSG_LINES := 6        # 表示するメッセージ行数

# アイテム種別アイコンのテクスチャキャッシュ（type_int → Texture2D）
# _draw() 内で load() するとGPU未アップロードで白くなるため、事前にロードしておく
var _icon_cache: Dictionary = {}

func _ready() -> void:
	for type_int in Assets.ITEM_TYPES.keys():
		var path: String = Assets.item_type_sprite(type_int)
		if not path.is_empty() and ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_icon_cache[type_int] = tex

func _draw() -> void:
	if game_ref == null:
		return
	var vp := get_viewport_rect().size

	match game_ref.game_state:
		"inventory":
			_draw_hud_base(vp)
			_draw_inventory(vp, false)
		"inv_action":
			_draw_hud_base(vp)
			_draw_inventory(vp, false)
			_draw_action_submenu(vp)
		"throw_aim", "throw_anim":
			_draw_hud_base(vp)
			_draw_throw_overlay(vp)
		"storage_select":
			_draw_hud_base(vp)
			_draw_inventory(vp, true)
		"storage_pot":
			_draw_hud_base(vp)
			_draw_storage_pot(vp)
		"shop":
			_draw_hud_base(vp)
			_draw_shop(vp)
		"skill_tree":
			_draw_hud_base(vp)
			SkillTreeUI.draw(self, vp, game_ref)
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
		"ATK %d  DEF %d" % [Combat.calc_atk(gref), Combat.calc_def(gref)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.85, 0.85))

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
	ey += 18
	draw_string(font, Vector2(ex, ey),
		"G : %d" % gref.p_gold,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.00, 0.85, 0.10))

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
	# デバッグ: マップパターン名（フロア番号の下に表示）
	if gref.debug_mode and gref.generator != null:
		var pname: String = gref.generator.pattern_name
		if not pname.is_empty():
			fy += 16
			draw_string(font, Vector2(fx, fy),
				"[%s]" % pname,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.8, 1.0, 0.7))

	# ── メッセージログ ────────────────────────────────────
	_draw_messages(vp, font)

	# ── ミニマップ ────────────────────────────────────────
	if game_ref.show_minimap:
		_draw_minimap(vp)

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

# ─── ミニマップ ──────────────────────────────────────────────
func _draw_minimap(vp: Vector2) -> void:
	var gref := game_ref
	if gref.generator == null:
		return

	const CELL  := 2                        # タイル1つ当たりのピクセル数
	const MW    := DungeonGenerator.MAP_W   # 60
	const MH    := DungeonGenerator.MAP_H   # 40
	const PAD   := 8                        # 画面端からの余白

	# 右上に配置
	var ox := vp.x - MW * CELL - PAD
	var oy := PAD

	# 背景・枠
	draw_rect(Rect2(ox - 2, oy - 2, MW * CELL + 4, MH * CELL + 4),
		Color(0.0, 0.0, 0.0, 0.78))
	draw_rect(Rect2(ox - 2, oy - 2, MW * CELL + 4, MH * CELL + 4),
		Color(0.40, 0.40, 0.50, 0.90), false, 1.0)

	# タイル描画（探索済みのみ）
	for y in MH:
		for x in MW:
			var pos := Vector2i(x, y)
			if not gref.explored.has(pos):
				continue
			var tile: int = gref.generator.get_tile(x, y)
			var visible: bool = gref.fov_visible.has(pos)
			var col: Color
			match tile:
				DungeonGenerator.TILE_WALL:
					col = Color(0.22, 0.22, 0.28) if not visible else Color(0.35, 0.35, 0.42)
				DungeonGenerator.TILE_STAIRS:
					col = Color(0.50, 0.50, 0.10) if not visible else Color(0.90, 0.88, 0.20)
				_:  # FLOOR / SHOP_FLOOR
					col = Color(0.35, 0.35, 0.40) if not visible else Color(0.60, 0.60, 0.65)
			draw_rect(Rect2(ox + x * CELL, oy + y * CELL, CELL, CELL), col)

	# アイテム・ゴールド（探索済み・水色）
	var C_ITEM := Color(0.30, 0.85, 1.00)
	for fi in gref.floor_items:
		var fp: Vector2i = fi["grid_pos"]
		if gref.explored.has(fp):
			draw_rect(Rect2(ox + fp.x * CELL, oy + fp.y * CELL, CELL, CELL), C_ITEM)
	for pile in gref.gold_piles:
		var gp: Vector2i = pile["grid_pos"]
		if gref.explored.has(gp):
			draw_rect(Rect2(ox + gp.x * CELL, oy + gp.y * CELL, CELL, CELL), C_ITEM)
	for si in gref.shop_items:
		var sp: Vector2i = si["grid_pos"]
		if gref.explored.has(sp):
			draw_rect(Rect2(ox + sp.x * CELL, oy + sp.y * CELL, CELL, CELL), C_ITEM)

	# ワナ（発動済み・探索済み → × 印）
	var C_TRAP := Color(0.95, 0.60, 0.10)
	for trap in gref.traps:
		if not trap.get("triggered", false):
			continue
		var tp: Vector2i = trap["grid_pos"]
		if not gref.explored.has(tp):
			continue
		var tx: float = ox + tp.x * CELL
		var ty: float = oy + tp.y * CELL
		draw_line(Vector2(tx, ty), Vector2(tx + CELL, ty + CELL), C_TRAP, 1.0)
		draw_line(Vector2(tx + CELL, ty), Vector2(tx, ty + CELL), C_TRAP, 1.0)

	# 敵（視界内・赤）
	for enemy in gref.enemies:
		var ep: Vector2i = enemy["grid_pos"]
		if gref.fov_visible.has(ep):
			draw_rect(Rect2(ox + ep.x * CELL, oy + ep.y * CELL, CELL, CELL),
				Color(0.95, 0.15, 0.15))

	# 階段（探索済み・黄色）
	var stairs: Vector2i = gref.generator.stairs_pos
	if gref.explored.has(stairs):
		draw_rect(Rect2(ox + stairs.x * CELL - 1, oy + stairs.y * CELL - 1, CELL + 2, CELL + 2),
			Color(1.00, 0.90, 0.10))

	# プレイヤー（黄色・1px大きめ）
	var pp: Vector2i = gref.p_grid
	draw_rect(Rect2(ox + pp.x * CELL - 1, oy + pp.y * CELL - 1, CELL + 2, CELL + 2),
		Color(1.00, 0.90, 0.10))

	# 「M: マップ」ラベル
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(ox, oy + MH * CELL + 10),
		"[M] マップ切替", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.50, 0.50, 0.55))

func _item_name(item: Dictionary) -> String:
	if item.is_empty():
		return "なし"
	return item.get("name", "?")

# ─── インベントリ画面 ─────────────────────────────────────
func _draw_inventory(vp: Vector2, storage_mode: bool = false) -> void:
	var font := ThemeDB.fallback_font
	var gref := game_ref
	# 半透明オーバーレイ
	draw_rect(Rect2(0, 0, vp.x, vp.y - BAR_H), Color(0, 0, 0, 0.80))

	var title_x := vp.x / 2.0 - 120.0
	var title_y := 40.0
	var title_text := "─── インベントリ ───"
	if storage_mode:
		var pot_cap := 0
		var pot_cnt := 0
		for it in gref.p_inventory:
			if it.get("_iid", -1) == gref._storage_pot_iid:
				pot_cap = int(it.get("capacity", 3))
				pot_cnt = (it.get("contents", []) as Array).size()
				break
		title_text = "─── 何をしまいますか？ （%d/%d） ───" % [pot_cnt, pot_cap]
	var title_color := Color(0.95, 0.85, 0.25) if not storage_mode else Color(0.60, 0.90, 1.00)
	draw_string(font, Vector2(title_x, title_y), title_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, title_color)

	# storage_select はインベントリのみを対象。通常インベントリは足元アイテムも末尾に含める。
	var inv: Array = gref.p_inventory if storage_mode else gref._inventory_display_list()
	var inv_owned_size: int = (gref.p_inventory as Array).size()
	if inv.is_empty():
		draw_string(font, Vector2(title_x, title_y + 40),
			"（アイテムなし）", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.6, 0.6))
	else:
		for i in inv.size():
			var item:  Dictionary = inv[i]
			var iy := title_y + 36 + i * 26
			var selected: bool = (i == gref.inv_cursor)
			var is_floor_entry: bool = not storage_mode and i >= inv_owned_size
			# storage_select中、箱自身はグレーアウト
			var is_pot_self: bool = storage_mode and item.get("_iid", -2) == gref._storage_pot_iid
			var bg_col := Color(0.20, 0.25, 0.35, 0.85) if selected else Color(0, 0, 0, 0)
			draw_rect(Rect2(title_x - 8, iy - 18, 500, 24), bg_col)
			var tag := "[床]" if is_floor_entry else _equip_tag(gref, item)
			var col: Color
			if is_pot_self:
				col = Color(0.45, 0.45, 0.45)
			elif selected:
				col = Color.WHITE
			elif is_floor_entry:
				col = Color(0.70, 0.90, 0.70)   # 薄緑で床アイテムを示す
			elif item.get("cursed", false):
				col = Color(0.85, 0.30, 0.30)   # 呪い: 赤みがかった色
			elif item.get("blessed", false):
				col = Color(1.00, 0.95, 0.40)   # 祝福: 金色
			else:
				col = ItemData.type_color(item.get("type", 0))
			# 武器/盾は修正値＋印付き表示、箱は中身/容量表示
			var name_str: String = SealSystem.display_name(item)
			var pot_eff: String = item.get("effect", "")
			if pot_eff == "storage" or pot_eff == "synthesis":
				var cnt: int = item.get("contents", []).size()
				var cap: int = int(item.get("capacity", 3))
				name_str = "%s（%d/%d）" % [item.get("name", "?"), cnt, cap]
			# アイコン描画（20×20）
			const ICON_SIZE := 20
			var icon_tex: Texture2D = _icon_cache.get(int(item.get("type", -1)))
			var icon_drawn := false
			if icon_tex != null:
				var icon_mod := Color(0.45, 0.45, 0.45) if is_pot_self else Color.WHITE
				draw_texture_rect(icon_tex,
					Rect2(title_x, iy - ICON_SIZE + 4, ICON_SIZE, ICON_SIZE), false, icon_mod)
				icon_drawn = true
			if not icon_drawn:
				# フォールバック：シンボル文字
				draw_string(font, Vector2(title_x, iy),
					ItemData.type_symbol(item.get("type", 0)),
					HORIZONTAL_ALIGNMENT_LEFT, ICON_SIZE, 15, col)
			# アイテム名（アイコン分右にずらす）
			draw_string(font,
				Vector2(title_x + ICON_SIZE + 4, iy),
				"%s %s" % [tag, name_str],
				HORIZONTAL_ALIGNMENT_LEFT, 466, 15, col)

	# 操作ガイド
	var gy := vp.y - BAR_H - 30.0
	draw_rect(Rect2(0, gy - 4, vp.x, 30), Color(0, 0, 0, 0.6))
	var guide := "[↑↓] 選択   [Enter/Z] メニュー   [Shift+Enter] 即使用   [D] 捨てる   [I/Esc] 閉じる"
	if storage_mode:
		guide = "[↑↓] 選択   [Enter/Z] しまう   [Esc] 戻る"
	draw_string(font, Vector2(8, gy + 16),
		guide,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.70, 0.70, 0.70))

## 保存の箱：中身リスト表示画面
func _draw_storage_pot(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var gref := game_ref
	# 現在操作中の箱を取得
	var pot: Dictionary = {}
	for it in gref.p_inventory:
		if it.get("_iid", -1) == gref._storage_pot_iid:
			pot = it
			break
	# オーバーレイ
	draw_rect(Rect2(0, 0, vp.x, vp.y - BAR_H), Color(0, 0, 0, 0.80))

	var title_x := vp.x / 2.0 - 160.0
	var title_y := 40.0
	var contents: Array = pot.get("contents", [])
	var capacity: int = int(pot.get("capacity", 3))
	var title_text := "─── %s （%d/%d） ───" % [pot.get("name", "保存の箱"), contents.size(), capacity]
	draw_string(font, Vector2(title_x, title_y), title_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.60, 0.90, 1.00))

	if contents.is_empty():
		draw_string(font, Vector2(title_x, title_y + 40),
			"（空っぽ）", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.6, 0.6))
	else:
		for i in contents.size():
			var item: Dictionary = contents[i]
			var iy := title_y + 36 + i * 26
			var selected: bool = (i == gref.storage_cursor)
			var bg_col := Color(0.20, 0.25, 0.35, 0.85) if selected else Color(0, 0, 0, 0)
			draw_rect(Rect2(title_x - 8, iy - 18, 500, 24), bg_col)
			var col: Color = Color.WHITE if selected else ItemData.type_color(item.get("type", 0))
			const ICON_SIZE := 20
			var icon_tex: Texture2D = _icon_cache.get(int(item.get("type", -1)))
			if icon_tex != null:
				draw_texture_rect(icon_tex,
					Rect2(title_x, iy - ICON_SIZE + 4, ICON_SIZE, ICON_SIZE), false, Color.WHITE)
			else:
				draw_string(font, Vector2(title_x, iy),
					ItemData.type_symbol(item.get("type", 0)),
					HORIZONTAL_ALIGNMENT_LEFT, ICON_SIZE, 15, col)
			draw_string(font,
				Vector2(title_x + ICON_SIZE + 4, iy),
				item.get("name", "?"),
				HORIZONTAL_ALIGNMENT_LEFT, 466, 15, col)

	# 操作ガイド
	var gy := vp.y - BAR_H - 30.0
	draw_rect(Rect2(0, gy - 4, vp.x, 30), Color(0, 0, 0, 0.6))
	var guide := "[↑↓] 選択   [Enter/Z] 取り出す   [P] しまう   [I/Esc] 閉じる"
	draw_string(font, Vector2(8, gy + 16),
		guide, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.70, 0.70, 0.70))

## アイテムアクション選択のサブメニュー
func _draw_action_submenu(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var gref := game_ref
	var list: Array = gref._action_list
	if list.is_empty():
		return
	# 選択行の位置に合わせてパネルを表示
	var title_x: float = vp.x / 2.0 - 120.0
	var title_y: float = 40.0
	var inv_cur: int   = int(gref.inv_cursor)
	var act_cur: int   = int(gref.action_cursor)
	var row_y:   float = title_y + 36.0 + float(inv_cur) * 26.0
	var panel_x: float = title_x + 520.0
	var panel_w: float = 180.0
	var panel_h: float = float(list.size() * 26 + 16)
	var panel_y: float = row_y - 22.0
	# 画面下にはみ出す場合は上へ寄せる
	if panel_y + panel_h > vp.y - BAR_H - 40.0:
		panel_y = vp.y - BAR_H - 40.0 - panel_h
	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), Color(0.08, 0.10, 0.15, 0.95))
	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), Color(0.55, 0.70, 0.90), false, 1.0)
	for i in list.size():
		var entry: Array = list[i]
		var label: String = entry[1]
		var ry: float = panel_y + 18.0 + float(i) * 26.0
		var selected: bool = (i == act_cur)
		if selected:
			draw_rect(Rect2(panel_x + 4.0, ry - 15.0, panel_w - 8.0, 22.0),
				Color(0.25, 0.35, 0.55, 0.85))
		var col: Color = Color.WHITE if selected else Color(0.80, 0.80, 0.85)
		draw_string(font, Vector2(panel_x + 16.0, ry), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)

## 投擲狙い中／アニメ中の画面上部ガイド
func _draw_throw_overlay(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var gref := game_ref
	var bar_h := 36.0
	draw_rect(Rect2(0, 0, vp.x, bar_h), Color(0, 0, 0, 0.60))
	var txt: String
	if gref.game_state == "throw_aim":
		txt = "方向を選んで [Enter/Z] で投げる  [Esc] キャンセル"
	else:
		txt = "投擲中…"
	draw_string(font, Vector2(12, 24), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.95, 0.4))

func _equip_tag(gref: Node, item: Dictionary) -> String:
	var iid: int = item.get("_iid", -2)
	if gref.p_weapon.get("_iid", -1) == iid: return "[剣]"
	if gref.p_shield.get("_iid", -1) == iid: return "[盾]"
	if gref.p_ring.get("_iid",   -1) == iid: return "[指]"
	return "    "

# ─── 店UI ────────────────────────────────────────────────
func _draw_shop(vp: Vector2) -> void:
	var font  := ThemeDB.fallback_font
	var g     := game_ref

	const MARGIN    := 8.0
	const TAB_H     := 26.0   # タブ行の高さ
	const HEADER_H  := 50.0   # タイトル+タブ+区切り線の高さ
	const FOOTER_H  := 30.0
	const ROW_H     := 28.0
	var pw := minf(440.0, vp.x - MARGIN * 2)

	var is_sell: bool = (g.shop_mode == "sell")
	var items: Array  = g.shop_items if not is_sell else g.p_inventory
	var cursor: int   = g.shop_sell_cursor if is_sell else g.shop_cursor

	var available_h := vp.y - BAR_H - MARGIN * 2
	var max_rows: int = int((available_h - HEADER_H - FOOTER_H) / ROW_H)
	max_rows = max(1, max_rows)
	var visible_count: int = min(items.size(), max_rows)

	var scroll_offset: int = 0
	if items.size() > max_rows:
		scroll_offset = clamp(cursor - max_rows / 2, 0, items.size() - max_rows)

	var ph := HEADER_H + ROW_H * float(max(1, visible_count)) + FOOTER_H
	ph = minf(ph, available_h)
	var px := (vp.x - pw) / 2.0
	var py := maxf(MARGIN, (vp.y - BAR_H - ph) / 2.0)

	# 暗幕・パネル背景・枠
	draw_rect(Rect2(0, 0, vp.x, vp.y - BAR_H), Color(0, 0, 0, 0.70))
	draw_rect(Rect2(px, py, pw, ph), Color(0.06, 0.05, 0.02, 0.97))
	draw_rect(Rect2(px, py, pw, ph), Color(0.75, 0.65, 0.15), false, 2.0)

	# タイトル行
	draw_string(font, Vector2(px, py + 28),
		"＊ 店 ＊", HORIZONTAL_ALIGNMENT_CENTER, int(pw), 22, Color(1.0, 0.88, 0.20))
	draw_string(font, Vector2(px + 8, py + 28),
		"所持金: %dG" % g.p_gold, HORIZONTAL_ALIGNMENT_RIGHT, int(pw - 16), 14, Color(1.0, 0.85, 0.1))

	# ── 購入 / 売却 タブ ──────────────────────────────────────
	var tab_y := py + 34.0
	var tab_w := pw / 2.0
	var buy_col:  Color = Color(1.0, 0.90, 0.30) if not is_sell else Color(0.50, 0.45, 0.25)
	var sell_col: Color = Color(1.0, 0.90, 0.30) if is_sell     else Color(0.50, 0.45, 0.25)
	if not is_sell:
		draw_rect(Rect2(px, tab_y, tab_w, TAB_H), Color(0.20, 0.16, 0.04, 0.80))
	draw_string(font, Vector2(px, tab_y + TAB_H * 0.75),
		"購入", HORIZONTAL_ALIGNMENT_CENTER, int(tab_w), 14, buy_col)
	if is_sell:
		draw_rect(Rect2(px + tab_w, tab_y, tab_w, TAB_H), Color(0.20, 0.16, 0.04, 0.80))
	draw_string(font, Vector2(px + tab_w, tab_y + TAB_H * 0.75),
		"売却", HORIZONTAL_ALIGNMENT_CENTER, int(tab_w), 14, sell_col)

	# ヘッダー区切り線
	var line_y := py + HEADER_H - 10.0
	draw_line(Vector2(px + 12, line_y), Vector2(px + pw - 12, line_y), Color(0.50, 0.40, 0.10), 1.0)

	# ── アイテムリスト ──────────────────────────────────────
	if items.is_empty():
		var empty_msg: String = "売り切れです" if not is_sell else "持ち物がありません"
		draw_string(font, Vector2(px + pw / 2.0, py + HEADER_H + ROW_H * 0.75),
			empty_msg, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.6, 0.6, 0.6))
	else:
		if scroll_offset > 0:
			draw_string(font, Vector2(px + pw / 2.0, py + HEADER_H - 2),
				"▲", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.70, 0.60, 0.20))

		for row in visible_count:
			var i: int = row + scroll_offset
			if i >= items.size():
				break

			var item_name: String
			var price: int
			var type_int: int
			if not is_sell:
				var si: Dictionary = items[i]
				item_name = si["item"].get("name", "？")
				price     = si["price"]
				type_int  = int(si["item"].get("type", -1))
			else:
				var inv_item: Dictionary = items[i]
				item_name = inv_item.get("name", "？")
				price     = ItemData.sell_price(inv_item)
				type_int  = int(inv_item.get("type", -1))

			var row_top := py + HEADER_H + ROW_H * float(row)
			var iy      := row_top + ROW_H * 0.75

			# カーソル行ハイライト
			if i == cursor:
				draw_rect(Rect2(px + 4, row_top, pw - 8, ROW_H - 2),
					Color(0.55, 0.45, 0.05, 0.45))
				draw_string(font, Vector2(px + 16, iy), "▶",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.90, 0.3))

			# アイコン
			var icon: Texture2D = _icon_cache.get(type_int)
			if icon:
				draw_texture_rect(icon, Rect2(px + 30, row_top + 4, 20, 20), false)

			# アイテム名
			draw_string(font, Vector2(px + 56, iy), item_name,
				HORIZONTAL_ALIGNMENT_LEFT, int(pw - 56 - 70), 15, Color(0.95, 0.92, 0.80))
			# 価格（売却時は緑系で表示）
			var price_col: Color
			if not is_sell:
				price_col = Color(1.0, 0.85, 0.1) if g.p_gold >= price else Color(0.7, 0.3, 0.3)
			else:
				price_col = Color(0.40, 0.90, 0.40)
			draw_string(font, Vector2(px + 8, iy), "%dG" % price,
				HORIZONTAL_ALIGNMENT_RIGHT, int(pw - 16), 15, price_col)

		if scroll_offset + max_rows < items.size():
			var ind_y := py + HEADER_H + ROW_H * float(visible_count) - 4.0
			draw_string(font, Vector2(px + pw / 2.0, ind_y),
				"▼", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.70, 0.60, 0.20))

	# フッター
	var footer_y := py + ph - 14.0
	draw_line(Vector2(px + 12, footer_y - 12), Vector2(px + pw - 12, footer_y - 12),
		Color(0.50, 0.40, 0.10), 1.0)
	var footer_text: String
	if not is_sell:
		footer_text = "↑↓ 選択   Enter/Z 購入   Tab 売却へ   Esc 閉じる"
	else:
		footer_text = "↑↓ 選択   Enter/Z 売却   Tab 購入へ   Esc 閉じる"
	draw_string(font, Vector2(px, footer_y),
		footer_text, HORIZONTAL_ALIGNMENT_CENTER, int(pw), 13, Color(0.55, 0.55, 0.55))

# ─── ゲームオーバー ───────────────────────────────────────
func _draw_game_over(vp: Vector2) -> void:
	var font  := ThemeDB.fallback_font
	var g     := game_ref

	# 暗幕
	draw_rect(Rect2(0, 0, vp.x, vp.y - BAR_H), Color(0, 0, 0, 0.90))

	# パネル
	var pw    := 480.0
	var ph    := 320.0
	var px    := (vp.x - pw) / 2.0
	var py    := (vp.y - BAR_H - ph) / 2.0
	draw_rect(Rect2(px, py, pw, ph), Color(0.08, 0.04, 0.04, 0.97))
	draw_rect(Rect2(px, py, pw, ph), Color(0.60, 0.15, 0.10), false, 2.0)

	# タイトル
	var cy := py + 36.0
	draw_string(font, Vector2(px + pw / 2, cy),
		"GAME  OVER", HORIZONTAL_ALIGNMENT_CENTER, -1, 34, Color(0.90, 0.15, 0.10))

	# 死因
	cy += 44.0
	var cause_text: String = g.death_cause if g.death_cause != "" else "力尽きた"
	draw_string(font, Vector2(px + pw / 2, cy),
		"─  %s  ─" % cause_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 17, Color(0.85, 0.65, 0.35))

	# 区切り線
	cy += 18.0
	draw_line(Vector2(px + 24, cy), Vector2(px + pw - 24, cy), Color(0.40, 0.20, 0.18), 1.0)

	# ── ステータス表 ──────────────────────────────────────
	cy += 22.0
	var lx := px + 40.0
	var rx := px + pw / 2 + 20.0
	var row_h := 22.0
	var label_col := Color(0.60, 0.60, 0.65)
	var value_col := Color(0.95, 0.95, 0.90)

	# 左列
	draw_string(font, Vector2(lx, cy),       "フロア",   HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_col)
	draw_string(font, Vector2(lx + 80, cy),  "B%dF" % g.current_floor, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, value_col)
	cy += row_h
	draw_string(font, Vector2(lx, cy),       "レベル",   HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_col)
	draw_string(font, Vector2(lx + 80, cy),  "LV %d" % g.p_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, value_col)
	cy += row_h
	draw_string(font, Vector2(lx, cy),       "HP",       HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_col)
	draw_string(font, Vector2(lx + 80, cy),  "%d / %d" % [g.p_hp, g.p_hp_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, value_col)
	cy += row_h
	draw_string(font, Vector2(lx, cy),       "攻撃力",   HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_col)
	draw_string(font, Vector2(lx + 80, cy),  "%d" % Combat.calc_atk(g), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, value_col)
	cy += row_h
	draw_string(font, Vector2(lx, cy),       "防御力",   HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_col)
	draw_string(font, Vector2(lx + 80, cy),  "%d" % Combat.calc_def(g), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, value_col)

	# 右列（cy をリセット）
	cy = py + 36.0 + 44.0 + 18.0 + 22.0
	draw_string(font, Vector2(rx, cy),       "所持金",   HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_col)
	draw_string(font, Vector2(rx + 80, cy),  "%d G" % g.p_gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.00, 0.88, 0.15))
	cy += row_h
	draw_string(font, Vector2(rx, cy),       "満腹度",   HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_col)
	draw_string(font, Vector2(rx + 80, cy),  "%d%%" % g.p_fullness, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, value_col)
	cy += row_h
	draw_string(font, Vector2(rx, cy),       "ターン数", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_col)
	draw_string(font, Vector2(rx + 80, cy),  "%d" % g.turn_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, value_col)
	cy += row_h
	# 経過時間
	var elapsed_sec := int((Time.get_ticks_msec() - g._start_time_msec) / 1000)
	var el_m := elapsed_sec / 60
	var el_s := elapsed_sec % 60
	draw_string(font, Vector2(rx, cy),       "経過時間", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_col)
	draw_string(font, Vector2(rx + 80, cy),  "%d:%02d" % [el_m, el_s], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, value_col)
	cy += row_h
	draw_string(font, Vector2(rx, cy),       "経験値",   HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_col)
	draw_string(font, Vector2(rx + 80, cy),  "%d" % g.p_exp, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, value_col)

	# リスタート案内
	var bottom_y := py + ph - 28.0
	draw_line(Vector2(px + 24, bottom_y - 14), Vector2(px + pw - 24, bottom_y - 14), Color(0.40, 0.20, 0.18), 1.0)
	draw_string(font, Vector2(px + pw / 2, bottom_y),
		"[R] でリスタート", HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color(0.60, 0.60, 0.65))

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
