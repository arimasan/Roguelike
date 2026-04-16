class_name DialogUI
extends RefCounted

## 会話イベント表示パネル（画面下部オーバーレイ）。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態（_dialog_layer / _dialog_lines / _dialog_idx / _dialog_choices /
##   _dialog_callback / _dialog_speaker）はすべて game.gd が所有。
## * 第1引数に必ず game.gd インスタンス（Node）を受け取る。
## * 会話中はゲームを止める（game_state == "dialog"）。プレイヤー入力は
##   handle_input() のみ反応する。
##
## ── 表示仕様 ─────────────────────────────────────────────
## * 画面下40%のパネル。背景半透明黒、上部に話者名、下に本文。
## * 複数行の場合は Enter/Space/Z で次に進む。最終行で選択肢が必要なら
##   「[1] はい  [2] いいえ」を表示し、1/2 キーで選択。
## * 選択コールバック: callback.call(choice_index) を返す。

# ─── ビルド（起動時に1回） ────────────────────────────────
static func build_panel(game: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	layer.visible = false
	game.add_child(layer)
	game._dialog_layer = layer

	# 背景オーバーレイ（後ろのHUDを暗く）
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	overlay.offset_top    = -240
	overlay.offset_bottom = 0
	overlay.color = Color(0, 0, 0, 0.85)
	layer.add_child(overlay)

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top    = -220
	panel.offset_left   =   16
	panel.offset_right  =  -16
	panel.offset_bottom =  -16
	# 不透明の濃紺背景＋金色の縁取り
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.12, 1.0)
	sb.border_color = Color(0.85, 0.70, 0.30, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left   = 16
	sb.content_margin_right  = 16
	sb.content_margin_top    = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var speaker := Label.new()
	speaker.add_theme_font_size_override("font_size", 18)
	speaker.modulate = Color(1.0, 0.9, 0.4)
	vbox.add_child(speaker)
	game._dialog_speaker = speaker

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = false
	body.scroll_active = false
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 16)
	vbox.add_child(body)
	game._dialog_body = body

	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.7, 0.7, 0.7)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(hint)
	game._dialog_hint = hint

# ─── 開始 ────────────────────────────────────────────────
## 会話を開始する。
## - speaker: 話者名（例：「スライム」）
## - lines: 本文の配列（複数ページ）
## - choices: 最終ページで提示する選択肢ラベル配列（空なら選択なし）
## - callback: 終了時 callback.call(choice_idx) で呼ばれる（選択なしは -1）
static func start(game: Node, speaker: String, lines: Array, choices: Array,
		callback: Callable) -> void:
	game._dialog_speaker.text = speaker
	game._dialog_lines    = lines
	game._dialog_idx      = 0
	game._dialog_choices  = choices
	game._dialog_callback = callback
	_render_current(game)
	game._dialog_layer.visible = true
	game.game_state = "dialog"

static func _render_current(game: Node) -> void:
	var idx: int = int(game._dialog_idx)
	var lines: Array = game._dialog_lines as Array
	if idx < 0 or idx >= lines.size():
		return
	game._dialog_body.text = str(lines[idx])
	# 最終ページかつ選択肢ありなら選択肢を追記
	var is_last: bool = (idx == lines.size() - 1)
	var choices: Array = game._dialog_choices as Array
	if is_last and not choices.is_empty():
		var choices_text: String = "\n\n"
		for i in choices.size():
			choices_text += "[color=#ffd040][%d][/color] %s   " % [i + 1, str(choices[i])]
		game._dialog_body.text += choices_text
		game._dialog_hint.text = "[1〜%d] で選択" % choices.size()
	else:
		game._dialog_hint.text = "[Enter / Z] で次へ"

# ─── 入力 ────────────────────────────────────────────────
static func handle_input(game: Node, kc: int) -> void:
	var idx: int = int(game._dialog_idx)
	var lines: Array = game._dialog_lines as Array
	var choices: Array = game._dialog_choices as Array
	var is_last: bool = (idx == lines.size() - 1)
	# 最終ページかつ選択肢あり：1〜N で選択
	if is_last and not choices.is_empty():
		for i in choices.size():
			if kc == KEY_1 + i or kc == KEY_KP_1 + i:
				_finish(game, i)
				return
		return   # 選択肢中は他キー無効
	# それ以外：Enter / Z / Space で次へ
	if kc == KEY_ENTER or kc == KEY_Z or kc == KEY_SPACE or kc == KEY_KP_ENTER:
		if is_last:
			_finish(game, -1)
		else:
			game._dialog_idx = idx + 1
			_render_current(game)

static func _finish(game: Node, choice_idx: int) -> void:
	if is_instance_valid(game._dialog_layer):
		game._dialog_layer.visible = false
	game.game_state = "playing"
	var cb: Callable = game._dialog_callback
	game._dialog_callback = Callable()
	if cb.is_valid():
		cb.call(choice_idx)
