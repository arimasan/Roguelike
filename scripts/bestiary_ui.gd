class_name BestiaryUI
extends RefCounted

## 図鑑画面（敵・アイテム・ワナ）の構築・開閉・選択処理。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態は game.gd が所有（_bestiary_layer / _bestiary_* など）。
##   このファイルはUI生成と入力ハンドラのみ。
## * 表示ロジックは Bestiary.discovered_* を参照。
## * undiscovered（未発見）エントリは「???」として灰色表示。

const PANEL_W: float = 760.0
const PANEL_H: float = 540.0

# ─── ビルド（起動時に1回）────────────────────────────────
static func build_panel(game: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	layer.visible = false
	game.add_child(layer)
	game._bestiary_layer = layer

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left   = -PANEL_W * 0.5
	panel.offset_top    = -PANEL_H * 0.5
	panel.offset_right  =  PANEL_W * 0.5
	panel.offset_bottom =  PANEL_H * 0.5
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "─── 図鑑 ───"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tabs)
	game._bestiary_tabs = tabs

	# ── 敵タブ ──
	var enemy_tab := _build_tab(game, "敵")
	tabs.add_child(enemy_tab["root"])
	game._bestiary_enemy_list   = enemy_tab["list"]
	game._bestiary_enemy_detail = enemy_tab["detail"]
	game._bestiary_enemy_sprite = enemy_tab["sprite"]
	game._bestiary_enemy_btn    = enemy_tab["btn"]
	enemy_tab["list"].item_selected.connect(func(idx: int) -> void:
		_on_select(game, "enemy", idx))
	enemy_tab["btn"].pressed.connect(func() -> void:
		_on_debug_spawn(game, "enemy"))

	# ── アイテムタブ ──
	var item_tab := _build_tab(game, "アイテム")
	tabs.add_child(item_tab["root"])
	game._bestiary_item_list   = item_tab["list"]
	game._bestiary_item_detail = item_tab["detail"]
	game._bestiary_item_sprite = item_tab["sprite"]
	game._bestiary_item_btn    = item_tab["btn"]
	item_tab["list"].item_selected.connect(func(idx: int) -> void:
		_on_select(game, "item", idx))
	item_tab["btn"].pressed.connect(func() -> void:
		_on_debug_spawn(game, "item"))

	# ── ワナタブ ──
	var trap_tab := _build_tab(game, "ワナ")
	tabs.add_child(trap_tab["root"])
	game._bestiary_trap_list   = trap_tab["list"]
	game._bestiary_trap_detail = trap_tab["detail"]
	game._bestiary_trap_sprite = trap_tab["sprite"]
	game._bestiary_trap_btn    = trap_tab["btn"]
	trap_tab["list"].item_selected.connect(func(idx: int) -> void:
		_on_select(game, "trap", idx))
	trap_tab["btn"].pressed.connect(func() -> void:
		_on_debug_spawn(game, "trap"))

	# 閉じるヒント
	var hint := Label.new()
	hint.text = "[Z] または [Esc] で閉じる"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(hint)

# 1タブ分のレイアウト（左:リスト / 右:詳細＋デバッグ生成ボタン）
static func _build_tab(_game: Node, tab_name: String) -> Dictionary:
	var root := HBoxContainer.new()
	root.name = tab_name
	root.add_theme_constant_override("separation", 12)

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(280, 0)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.fixed_icon_size = Vector2i(24, 24)
	root.add_child(list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)

	var sprite := TextureRect.new()
	sprite.custom_minimum_size = Vector2(96, 96)
	sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	right.add_child(sprite)

	var detail := RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.fit_content = false
	detail.scroll_active = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail)

	# デバッグ生成ボタン（debug_mode 時のみ可視）
	var btn := Button.new()
	btn.text = "[DEBUG] 生成する"
	btn.visible = false
	right.add_child(btn)

	return {"root": root, "list": list, "detail": detail, "sprite": sprite, "btn": btn}

# ─── 開閉 ────────────────────────────────────────────────
static func open(game: Node) -> void:
	Bestiary.ensure_loaded()
	_refresh_all(game)
	refresh_visibility(game)
	game._bestiary_layer.visible = true
	game.game_state = "bestiary"

static func close(game: Node) -> void:
	if is_instance_valid(game._bestiary_layer):
		game._bestiary_layer.visible = false
	game.game_state = "playing"

static func handle_input(game: Node, kc: int) -> void:
	if kc == KEY_ESCAPE or kc == KEY_Z:
		close(game)

## debug_mode に応じて生成ボタンの可視を更新する
static func refresh_visibility(game: Node) -> void:
	var dbg: bool = bool(game.debug_mode)
	if is_instance_valid(game._bestiary_enemy_btn):
		game._bestiary_enemy_btn.visible = dbg
	if is_instance_valid(game._bestiary_item_btn):
		game._bestiary_item_btn.visible = dbg
	if is_instance_valid(game._bestiary_trap_btn):
		game._bestiary_trap_btn.visible = dbg

## デバッグ「生成する」ボタン押下：選択中エントリのIDを取得して game の生成関数を呼び、図鑑を閉じる
static func _on_debug_spawn(game: Node, kind: String) -> void:
	var lst: ItemList
	var data_arr: Array
	match kind:
		"enemy": lst = game._bestiary_enemy_list; data_arr = EnemyData.ALL
		"item":  lst = game._bestiary_item_list;  data_arr = ItemData.ALL
		"trap":  lst = game._bestiary_trap_list;  data_arr = TrapData.ALL
		_: return
	var sel: PackedInt32Array = lst.get_selected_items()
	if sel.is_empty():
		return
	var idx: int = sel[0]
	if idx < 0 or idx >= data_arr.size():
		return
	var entry_id: String = (data_arr[idx] as Dictionary).get("id", "")
	var ok: bool = false
	match kind:
		"enemy": ok = game.debug_spawn_enemy(entry_id)
		"item":  ok = game.debug_spawn_item(entry_id)
		"trap":  ok = game.debug_spawn_trap(entry_id)
	if ok:
		close(game)

# ─── リスト構築 ────────────────────────────────────────
static func _refresh_all(game: Node) -> void:
	_refresh_enemy_list(game)
	_refresh_item_list(game)
	_refresh_trap_list(game)
	# 各タブの詳細を初期表示
	if game._bestiary_enemy_list.item_count > 0:
		game._bestiary_enemy_list.select(0)
		_on_select(game, "enemy", 0)
	if game._bestiary_item_list.item_count > 0:
		game._bestiary_item_list.select(0)
		_on_select(game, "item", 0)
	if game._bestiary_trap_list.item_count > 0:
		game._bestiary_trap_list.select(0)
		_on_select(game, "trap", 0)

static func _refresh_enemy_list(game: Node) -> void:
	var lst: ItemList = game._bestiary_enemy_list
	lst.clear()
	var dbg: bool = bool(game.debug_mode)
	for entry: Dictionary in EnemyData.ALL:
		var id: String = entry.get("id", "")
		var known: bool = dbg or Bestiary.knows_enemy(id)
		var label: String = entry.get("name", "?") if known else "???"
		# 仲間化済みならハートマークを末尾に（debug でも実績ベース）
		if known and Bestiary.has_recruited(id):
			label += "  ♥"
		var idx: int = lst.add_item(label)
		if known:
			var path: String = Assets.enemy_sprite(id)
			if path != "" and ResourceLoader.exists(path):
				lst.set_item_icon(idx, load(path))
			if Bestiary.has_recruited(id):
				lst.set_item_custom_fg_color(idx, Color(1.0, 0.55, 0.75))
		else:
			lst.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))

static func _refresh_item_list(game: Node) -> void:
	var lst: ItemList = game._bestiary_item_list
	lst.clear()
	var dbg: bool = bool(game.debug_mode)
	for entry: Dictionary in ItemData.ALL:
		var id: String = entry.get("id", "")
		var known: bool = dbg or Bestiary.knows_item(id)
		var label: String = entry.get("name", "?") if known else "???"
		var idx: int = lst.add_item(label)
		if known:
			var path: String = Assets.item_type_sprite(int(entry.get("type", -1)))
			if path != "" and ResourceLoader.exists(path):
				lst.set_item_icon(idx, load(path))
		else:
			lst.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))

static func _refresh_trap_list(game: Node) -> void:
	var lst: ItemList = game._bestiary_trap_list
	lst.clear()
	var dbg: bool = bool(game.debug_mode)
	for entry: Dictionary in TrapData.ALL:
		var id: String = entry.get("id", "")
		var known: bool = dbg or Bestiary.knows_trap(id)
		var label: String = entry.get("name", "?") if known else "???"
		var idx: int = lst.add_item(label)
		if known and ResourceLoader.exists(Assets.TRAP):
			lst.set_item_icon(idx, load(Assets.TRAP))
		else:
			lst.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))

# ─── 詳細表示 ────────────────────────────────────────────
static func _on_select(game: Node, kind: String, idx: int) -> void:
	match kind:
		"enemy": _show_enemy_detail(game, idx)
		"item":  _show_item_detail(game, idx)
		"trap":  _show_trap_detail(game, idx)

static func _show_enemy_detail(game: Node, idx: int) -> void:
	if idx < 0 or idx >= EnemyData.ALL.size():
		return
	var entry: Dictionary = EnemyData.ALL[idx]
	var id: String = entry.get("id", "")
	var known: bool = bool(game.debug_mode) or Bestiary.knows_enemy(id)
	var sprite: TextureRect = game._bestiary_enemy_sprite
	var detail: RichTextLabel = game._bestiary_enemy_detail
	if not known:
		sprite.texture = null
		detail.text = "[color=#888]未発見[/color]\n\n撃破することで図鑑に登録される。"
		return
	var path: String = Assets.enemy_sprite(id)
	sprite.texture = load(path) if (path != "" and ResourceLoader.exists(path)) else null
	var skills_text: String = ""
	for sk: Dictionary in entry.get("skills", []):
		skills_text += "  - %s\n" % sk.get("name", "?")
	if skills_text == "":
		skills_text = "  なし\n"
	var heart: String = "  [color=#ff8db5]♥ 仲間にしたことがある[/color]" if Bestiary.has_recruited(id) else ""
	detail.text = "[b]%s[/b]%s\n出現: B%d〜B%dF\nHP %d / ATK %d / DEF %d / EXP %d\n行動: %s\n\n[b]スキル[/b]\n%s\n[b]情報[/b]\n%s" % [
		entry.get("name", "?"),
		heart,
		int(entry.get("floor_min", 1)), int(entry.get("floor_max", 1)),
		int(entry.get("hp", 0)), int(entry.get("atk", 0)),
		int(entry.get("def", 0)), int(entry.get("exp", 0)),
		entry.get("behavior", "normal"),
		skills_text,
		entry.get("info", "（情報なし）"),
	]

static func _show_item_detail(game: Node, idx: int) -> void:
	if idx < 0 or idx >= ItemData.ALL.size():
		return
	var entry: Dictionary = ItemData.ALL[idx]
	var id: String = entry.get("id", "")
	var known: bool = bool(game.debug_mode) or Bestiary.knows_item(id)
	var sprite: TextureRect = game._bestiary_item_sprite
	var detail: RichTextLabel = game._bestiary_item_detail
	if not known:
		sprite.texture = null
		detail.text = "[color=#888]未発見[/color]\n\n使用・装備・投擲することで図鑑に登録される。"
		return
	var path: String = Assets.item_type_sprite(int(entry.get("type", -1)))
	sprite.texture = load(path) if (path != "" and ResourceLoader.exists(path)) else null
	var stats: String = ""
	if entry.has("atk"):      stats += "ATK +%d\n" % int(entry["atk"])
	if entry.has("def"):      stats += "DEF +%d\n" % int(entry["def"])
	if entry.has("heal"):     stats += "回復: %d\n" % int(entry["heal"])
	if entry.has("fullness"): stats += "満腹度: %+d\n" % int(entry["fullness"])
	if entry.has("uses"):     stats += "使用回数: %d\n" % int(entry["uses"])
	if entry.has("effect"):   stats += "効果: %s\n" % str(entry["effect"])
	if entry.get("cursed", false): stats += "[color=#a44]呪われている[/color]\n"
	detail.text = "[b]%s[/b]\n種別: %s\n%s\n買値の目安: %d G" % [
		entry.get("name", "?"),
		_type_label(int(entry.get("type", -1))),
		stats,
		ItemData.shop_price(entry),
	]

static func _show_trap_detail(game: Node, idx: int) -> void:
	if idx < 0 or idx >= TrapData.ALL.size():
		return
	var entry: Dictionary = TrapData.ALL[idx]
	var id: String = entry.get("id", "")
	var known: bool = bool(game.debug_mode) or Bestiary.knows_trap(id)
	var sprite: TextureRect = game._bestiary_trap_sprite
	var detail: RichTextLabel = game._bestiary_trap_detail
	if not known:
		sprite.texture = null
		detail.text = "[color=#888]未発見[/color]\n\n発動することで図鑑に登録される。"
		return
	sprite.texture = load(Assets.TRAP) if ResourceLoader.exists(Assets.TRAP) else null
	detail.text = "[b]%s[/b]\n壊れる確率: %.0f%%\n効果音: %s\n\n%s" % [
		entry.get("name", "?"),
		float(entry.get("break_chance", 0.5)) * 100.0,
		entry.get("se", "trap"),
		_trap_info(id),
	]

static func _type_label(t: int) -> String:
	match t:
		ItemData.TYPE_WEAPON: return "武器"
		ItemData.TYPE_SHIELD: return "盾"
		ItemData.TYPE_FOOD:   return "食料"
		ItemData.TYPE_SCROLL: return "本"
		ItemData.TYPE_POT:    return "箱"
		ItemData.TYPE_RING:   return "指輪"
		ItemData.TYPE_STAFF:  return "杖"
		ItemData.TYPE_POTION: return "薬"
	return "？"

static func _trap_info(trap_id: String) -> String:
	match trap_id:
		"damage":    return "踏むとダメージを受ける。"
		"warp":      return "踏むとフロアのランダム位置へ転移する。"
		"hunger":    return "踏むと満腹度が大きく減る。"
		"blind":     return "踏むと視界が狭くなる（盲目）。"
		"poison":    return "踏むと毒状態になる。"
		"sleep":     return "踏むと睡眠状態になる。"
		"drop_item": return "踏むとアイテムを1つ落とす。"
		"alarm":     return "踏むと付近の敵が一斉に覚醒する。"
		"slow":      return "踏むと鈍足状態になる（行動間隔が伸びる）。"
		"confuse":   return "踏むと混乱状態になる（移動方向ランダム）。"
	return ""
