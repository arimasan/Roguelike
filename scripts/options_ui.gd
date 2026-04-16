class_name OptionsUI
extends RefCounted

## オプション画面（音量・キーコンフィグ・冒険を諦める）の構築／開閉／リバインド処理。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態（vol_* / _options_layer / _confirm_layer / _rebind_* / key_bindings など）は
##   すべて game.gd が所有。このファイルは「UI生成と状態遷移」のみを担当する。
## * 第1引数に必ず game.gd インスタンス（Node）を受け取る。
## * シグナル接続は lambda で `game` をキャプチャする（OptionsUI は静的メソッド集）。
##
## ── ここに書くべきもの ───────────────────────────────────
## * オプションパネル／確認ダイアログのビルド（build_panel）
## * open / close / rebinding の状態遷移
## * ロード時のUI値反映（apply_loaded）
##
## ── ここに書かないべきもの ─────────────────────────────
## * セーブ／ロード（SaveLoad）
## * 実際のBGM再生（game._play_bgm）
## * ゲームオーバー処理（game._trigger_game_over）

# ─── ビルド（ゲーム起動時に1回呼ぶ） ──────────────────────
static func build_panel(game: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer   = 10
	layer.visible = false
	game.add_child(layer)
	game._options_layer = layer

	# 背景オーバーレイ
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	# パネル本体（中央固定）
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(500, 440)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left   = -250.0
	panel.offset_top    = -220.0
	panel.offset_right  =  250.0
	panel.offset_bottom =  220.0
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "─── オプション ───"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)

	# タブコンテナ
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tabs)

	# ── タブ1: 音量設定 ──
	var vol_container := VBoxContainer.new()
	vol_container.name = "音量設定"
	vol_container.add_theme_constant_override("separation", 14)
	tabs.add_child(vol_container)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vol_container.add_child(spacer)

	var master_row := _add_volume_row(vol_container, "マスター音量", float(game.vol_master), func(v: float) -> void:
		game.vol_master = v
		game._lbl_master_pct.text = "%d%%" % int(v * 100)
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Master"), game._linear_to_db_safe(float(game.vol_master)))
	)
	game._lbl_master_pct = master_row[0] as Label
	game._slider_master  = master_row[1] as HSlider

	var bgm_row := _add_volume_row(vol_container, "BGM 音量", float(game.vol_bgm), func(v: float) -> void:
		game.vol_bgm = v
		game._lbl_bgm_pct.text = "%d%%" % int(v * 100)
		if is_instance_valid(game._bgm_player):
			game._bgm_player.volume_db = game._linear_to_db_safe(float(game.vol_bgm))
	)
	game._lbl_bgm_pct = bgm_row[0] as Label
	game._slider_bgm  = bgm_row[1] as HSlider

	var se_row := _add_volume_row(vol_container, "SE 音量", float(game.vol_se), func(v: float) -> void:
		game.vol_se = v
		game._lbl_se_pct.text = "%d%%" % int(v * 100)
	)
	game._lbl_se_pct = se_row[0] as Label
	game._slider_se  = se_row[1] as HSlider

	# ── タブ2: キーコンフィグ ──
	var key_outer := VBoxContainer.new()
	key_outer.name = "キーコンフィグ"
	key_outer.add_theme_constant_override("separation", 6)
	tabs.add_child(key_outer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	key_outer.add_child(scroll)

	var key_vbox := VBoxContainer.new()
	key_vbox.add_theme_constant_override("separation", 4)
	key_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(key_vbox)

	for action: String in game.KEY_ACTIONS:
		_add_key_row(game, key_vbox, action)

	var reset_btn := Button.new()
	reset_btn.text = "デフォルトに戻す"
	reset_btn.pressed.connect(func(): reset_key_bindings(game))
	key_outer.add_child(reset_btn)

	# 冒険を諦めるボタン（赤系スタイル）
	var give_up_btn := Button.new()
	give_up_btn.text = "冒険を諦める"
	give_up_btn.add_theme_color_override("font_color",          Color(1.00, 0.35, 0.30))
	give_up_btn.add_theme_color_override("font_hover_color",    Color(1.00, 0.55, 0.50))
	give_up_btn.add_theme_color_override("font_pressed_color",  Color(0.80, 0.20, 0.15))
	give_up_btn.pressed.connect(func(): show_give_up_confirm(game))
	vbox.add_child(give_up_btn)

	# 閉じるボタン
	var close_btn := Button.new()
	close_btn.text = "閉じる  [ Esc ]"
	close_btn.pressed.connect(func(): close(game))
	vbox.add_child(close_btn)

	# 確認ダイアログ（初期非表示）
	_build_confirm_give_up_panel(game)

## スライダー行を生成して追加。パーセント表示ラベルとスライダーを [label, slider] で返す
static func _add_volume_row(parent: Control, label_text: String,
		initial: float, on_change: Callable) -> Array:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(110, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step      = 0.01
	slider.value     = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)

	var pct := Label.new()
	pct.text = "%d%%" % int(initial * 100)
	pct.custom_minimum_size    = Vector2(44, 0)
	pct.horizontal_alignment   = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_font_size_override("font_size", 14)
	hbox.add_child(pct)

	slider.value_changed.connect(on_change)
	return [pct, slider]

## キーコンフィグ行を生成する
static func _add_key_row(game: Node, parent: Control, action: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = game.KEY_ACTIONS[action]["label"]
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)

	var btn := Button.new()
	btn.text = OS.get_keycode_string(int(game.key_bindings.get(action, 0)))
	btn.custom_minimum_size = Vector2(160, 0)
	btn.name = "keybind_" + action
	btn.pressed.connect(func(): start_rebind(game, action, btn))
	hbox.add_child(btn)

# ─── リバインド ────────────────────────────────────────────
static func start_rebind(game: Node, action: String, btn: Button) -> void:
	game._rebinding_action = action
	game._rebind_button    = btn
	btn.text               = "--- 押してください ---"
	game.game_state        = "rebinding"

static func finish_rebind(game: Node, kc: int) -> void:
	game.key_bindings[game._rebinding_action] = kc
	game._rebind_button.text = OS.get_keycode_string(kc)
	game._rebinding_action   = ""
	game._rebind_button      = null
	game.game_state          = "options"

static func cancel_rebind(game: Node) -> void:
	if game._rebind_button != null:
		game._rebind_button.text = OS.get_keycode_string(
			int(game.key_bindings.get(game._rebinding_action, 0)))
	game._rebinding_action = ""
	game._rebind_button    = null
	game.game_state        = "options"

## キーバインドをデフォルトに戻す
static func reset_key_bindings(game: Node) -> void:
	for action: String in game.KEY_ACTIONS:
		game.key_bindings[action] = game.KEY_ACTIONS[action]["default"]
	# ボタン表示を更新
	for action: String in game.KEY_ACTIONS:
		var btn := game._options_layer.find_child("keybind_" + action, true, false) as Button
		if btn:
			btn.text = OS.get_keycode_string(int(game.key_bindings[action]))

# ─── 開閉 ──────────────────────────────────────────────────
static func open(game: Node) -> void:
	game._options_layer.visible = true
	game.game_state = "options"

static func close(game: Node) -> void:
	game._options_layer.visible = false
	if is_instance_valid(game._confirm_layer):
		game._confirm_layer.visible = false
	game.game_state = "playing"

# ─── 冒険を諦める確認ダイアログ ────────────────────────────
static func _build_confirm_give_up_panel(game: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer   = 12   # オプションより手前
	layer.visible = false
	game.add_child(layer)
	game._confirm_layer = layer

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(360, 160)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left   = -180.0
	panel.offset_top    = -80.0
	panel.offset_right  =  180.0
	panel.offset_bottom =  80.0
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "本当に冒険を諦めますか？"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var yes_btn := Button.new()
	yes_btn.text = "はい（諦める）"
	yes_btn.custom_minimum_size = Vector2(140, 0)
	yes_btn.add_theme_color_override("font_color",         Color(1.00, 0.35, 0.30))
	yes_btn.add_theme_color_override("font_hover_color",   Color(1.00, 0.55, 0.50))
	yes_btn.add_theme_color_override("font_pressed_color", Color(0.80, 0.20, 0.15))
	yes_btn.pressed.connect(func(): confirm_give_up(game))
	hbox.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "いいえ（続ける）"
	no_btn.custom_minimum_size = Vector2(140, 0)
	no_btn.pressed.connect(func(): cancel_give_up(game))
	hbox.add_child(no_btn)

static func show_give_up_confirm(game: Node) -> void:
	if is_instance_valid(game._confirm_layer):
		game._confirm_layer.visible = true

static func cancel_give_up(game: Node) -> void:
	if is_instance_valid(game._confirm_layer):
		game._confirm_layer.visible = false

static func confirm_give_up(game: Node) -> void:
	if is_instance_valid(game._confirm_layer):
		game._confirm_layer.visible = false
	close(game)
	game._trigger_game_over("冒険を諦めた")

# ─── ロード後の値反映 ──────────────────────────────────────
static func apply_loaded(game: Node) -> void:
	# スライダーとラベルへ音量を反映（パネルが構築済みの場合のみ）
	if is_instance_valid(game._slider_master):
		game._slider_master.value = float(game.vol_master)
		game._lbl_master_pct.text = "%d%%" % int(float(game.vol_master) * 100)
	if is_instance_valid(game._slider_bgm):
		game._slider_bgm.value = float(game.vol_bgm)
		game._lbl_bgm_pct.text = "%d%%" % int(float(game.vol_bgm) * 100)
	if is_instance_valid(game._slider_se):
		game._slider_se.value = float(game.vol_se)
		game._lbl_se_pct.text = "%d%%" % int(float(game.vol_se) * 100)
	# キーコンフィグボタンのラベルを更新
	for action: String in game.KEY_ACTIONS:
		var btn := game._options_layer.find_child("keybind_" + action, true, false) as Button
		if is_instance_valid(btn):
			btn.text = OS.get_keycode_string(int(game.key_bindings.get(action, 0)))
