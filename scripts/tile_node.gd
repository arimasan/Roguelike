extends Node2D
## エンティティを1タイルで描画する汎用ノード。
## set_sprite() でスプライトパスを設定するとタイル画像で表示。
## 未設定の場合はシンボル文字にフォールバックする。

const TILE_SIZE := 32

var bg_color:  Color  = Color(0.10, 0.30, 0.80)
var fg_color:  Color  = Color.WHITE
var symbol:    String = "@"
var font_size: int    = 20

var _sprite: Sprite2D = null

# ─── 状態異常ビジュアル ─────────────────────────────────────────
var _base_modulate: Color  = Color.WHITE   # flash後に戻る基準色
var _status_text:   String = ""            # バッジに表示する1文字
var _status_color:  Color  = Color.WHITE   # バッジ・tintの色

var _flash_tween: Tween = null             # 実行中のflashツイーン参照

# ─── セットアップ ─────────────────────────────────────────────
func setup(sym: String, bg: Color, fg: Color = Color.WHITE, fs: int = 20) -> void:
	symbol    = sym
	bg_color  = bg
	fg_color  = fg
	font_size = fs
	queue_redraw()

## スプライト画像パス（res://…）を渡して画像表示に切り替える
## 差し替え時は新しいパスを渡すだけでよい
## 画像サイズに関わらず TILE_SIZE に収まるよう自動スケーリングする
func set_sprite(path: String) -> void:
	if path.is_empty():
		return
	if not ResourceLoader.exists(path):
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	var tex := load(path) as Texture2D
	if tex:
		_sprite.texture = tex
		# タイルサイズに合わせてスケール（任意サイズ画像に対応）
		_sprite.scale = Vector2(
			float(TILE_SIZE) / float(tex.get_width()),
			float(TILE_SIZE) / float(tex.get_height())
		)
	queue_redraw()

# ─── 描画 ────────────────────────────────────────────────────
func _draw() -> void:
	var half := TILE_SIZE / 2
	if _sprite != null and is_instance_valid(_sprite) and _sprite.texture != null:
		# スプライトあり: 背景なし（透過ピクセルはマップが透ける）
		if _status_text != "":
			_draw_status_badge()
		return
	# フォールバック: シンボル文字描画
	draw_rect(Rect2(-half, -half, TILE_SIZE, TILE_SIZE), bg_color)
	draw_rect(Rect2(-half, -half, TILE_SIZE, TILE_SIZE),
		bg_color.lightened(0.25), false, 1.0)
	if symbol.length() > 0:
		var font := ThemeDB.fallback_font
		draw_string(font,
			Vector2(-half, half - 4),
			symbol,
			HORIZONTAL_ALIGNMENT_CENTER,
			TILE_SIZE,
			font_size,
			fg_color)
	if _status_text != "":
		_draw_status_badge()

## タイル左上に状態異常バッジを描画（11×10 の小矩形）
func _draw_status_badge() -> void:
	var bx := float(-TILE_SIZE) / 2.0
	var by := float(-TILE_SIZE) / 2.0
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(bx, by, 11.0, 10.0), Color(0.0, 0.0, 0.0, 0.80))
	draw_rect(Rect2(bx, by, 11.0, 10.0), _status_color, false, 1.0)
	draw_string(font, Vector2(bx + 1.0, by + 9.0),
		_status_text, HORIZONTAL_ALIGNMENT_LEFT, 11, 9, _status_color)

## 指定色で一瞬フラッシュして元に戻る（_base_modulate へ復元）
func flash(color: Color = Color(1.0, 0.2, 0.2)) -> void:
	# 前のフラッシュが残っていればキャンセル
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = color
		_flash_tween = create_tween()
		_flash_tween.tween_callback(_restore_sprite_modulate).set_delay(0.12)
	else:
		var orig := bg_color
		bg_color = color
		queue_redraw()
		_flash_tween = create_tween()
		_flash_tween.tween_callback(_restore_bg_color.bind(orig)).set_delay(0.12)

func _restore_sprite_modulate() -> void:
	if is_instance_valid(_sprite):
		_sprite.modulate = _base_modulate

func _restore_bg_color(orig: Color) -> void:
	bg_color = orig
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()

## 状態異常ビジュアルを設定（バッジ表示＋スプライトtint）
func set_status(text: String, tint: Color) -> void:
	_status_text  = text
	_status_color = tint
	_base_modulate = tint
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = tint
	queue_redraw()

## 状態異常ビジュアルをクリア
func clear_status() -> void:
	_status_text   = ""
	_base_modulate = Color.WHITE
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = Color.WHITE
	queue_redraw()

## グリッド座標からワールド座標へ変換してノードを移動
func set_grid(gx: int, gy: int) -> void:
	position = Vector2(gx * TILE_SIZE + TILE_SIZE / 2,
					   gy * TILE_SIZE + TILE_SIZE / 2)
