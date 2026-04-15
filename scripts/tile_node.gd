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
		# スプライトあり: 背景を描かずそのまま返す（透過ピクセルはマップタイルが透けて見える）
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

## グリッド座標からワールド座標へ変換してノードを移動
func set_grid(gx: int, gy: int) -> void:
	position = Vector2(gx * TILE_SIZE + TILE_SIZE / 2,
					   gy * TILE_SIZE + TILE_SIZE / 2)
