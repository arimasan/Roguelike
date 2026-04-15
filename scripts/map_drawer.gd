extends Node2D
## ダンジョンマップをタイル単位で描画する Node2D。
## 個別画像ファイルが使用可能な場合は画像タイルで描画し、
## 使用不可の場合は色付き矩形にフォールバックする。

const TILE_SIZE := 32

var generator:      DungeonGenerator = null
var visible_tiles:  Dictionary       = {}
var explored_tiles: Dictionary       = {}

var _tex_floor:   Texture2D = null
var _tex_wall:    Texture2D = null
var _tex_stairs:  Texture2D = null
var _tex_carpet:  Texture2D = null

# フォールバック用カラー定数
const C_VIS_WALL   := Color(0.22, 0.24, 0.30)
const C_VIS_FLOOR  := Color(0.42, 0.38, 0.32)
const C_EXP_WALL   := Color(0.07, 0.07, 0.09)
const C_EXP_FLOOR  := Color(0.16, 0.14, 0.12)
const C_UNKNOWN    := Color(0.00, 0.00, 0.00)

# 探索済み（視界外）タイルの暗化係数
const DIM_COLOR    := Color(0.35, 0.35, 0.40, 1.0)

func setup(gen: DungeonGenerator, vis: Dictionary, exp: Dictionary) -> void:
	generator      = gen
	visible_tiles  = vis
	explored_tiles = exp
	# タイルテクスチャ読み込み
	if ResourceLoader.exists(Assets.TILE_FLOOR):
		_tex_floor  = load(Assets.TILE_FLOOR) as Texture2D
	if ResourceLoader.exists(Assets.TILE_WALL):
		_tex_wall   = load(Assets.TILE_WALL) as Texture2D
	if ResourceLoader.exists(Assets.TILE_STAIRS):
		_tex_stairs = load(Assets.TILE_STAIRS) as Texture2D
	if ResourceLoader.exists(Assets.SHOP_CARPET):
		_tex_carpet = load(Assets.SHOP_CARPET) as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	if generator == null:
		return

	var font      := ThemeDB.fallback_font
	var font_size := 18

	for y in DungeonGenerator.MAP_H:
		for x in DungeonGenerator.MAP_W:
			var pos  := Vector2i(x, y)
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var tile := generator.get_tile(x, y)

			if visible_tiles.has(pos):
				_draw_tile_visible(rect, tile, font, font_size)
			elif explored_tiles.has(pos):
				_draw_tile_explored(rect, tile)
			else:
				draw_rect(rect, C_UNKNOWN)

# ─── 視界内タイル描画 ─────────────────────────────────────────
func _draw_tile_visible(rect: Rect2, tile: int, font: Font, font_size: int) -> void:
	match tile:
		DungeonGenerator.TILE_WALL:
			if _tex_wall:
				draw_texture_rect(_tex_wall, rect, false)
			else:
				draw_rect(rect, C_VIS_WALL)
				_draw_char(font, rect, "#", Color(0.35, 0.38, 0.48), font_size)

		DungeonGenerator.TILE_FLOOR:
			if _tex_floor:
				draw_texture_rect(_tex_floor, rect, false)
			else:
				draw_rect(rect, C_VIS_FLOOR)
				_draw_char(font, rect, ".", Color(0.55, 0.50, 0.44), font_size)

		DungeonGenerator.TILE_STAIRS:
			if _tex_floor:
				draw_texture_rect(_tex_floor, rect, false)
			if _tex_stairs:
				draw_texture_rect(_tex_stairs, rect, false)
			if not _tex_floor and not _tex_stairs:
				draw_rect(rect, C_VIS_FLOOR)
				_draw_char(font, rect, ">", Color(0.95, 0.85, 0.10), font_size)

		DungeonGenerator.TILE_SHOP_FLOOR:
			if _tex_carpet:
				draw_texture_rect(_tex_carpet, rect, false)
			else:
				draw_rect(rect, Color(0.55, 0.10, 0.10))
				_draw_char(font, rect, ".", Color(0.85, 0.30, 0.30), font_size)

# ─── 探索済み（視界外）タイル描画 ────────────────────────────
func _draw_tile_explored(rect: Rect2, tile: int) -> void:
	match tile:
		DungeonGenerator.TILE_WALL:
			if _tex_wall:
				draw_texture_rect(_tex_wall, rect, false, DIM_COLOR)
			else:
				draw_rect(rect, C_EXP_WALL)
		DungeonGenerator.TILE_SHOP_FLOOR:
			if _tex_carpet:
				draw_texture_rect(_tex_carpet, rect, false, DIM_COLOR)
			else:
				draw_rect(rect, Color(0.22, 0.04, 0.04))
		_:
			if _tex_floor:
				draw_texture_rect(_tex_floor, rect, false, DIM_COLOR)
			else:
				draw_rect(rect, C_EXP_FLOOR)

# ─── フォールバック用文字描画 ─────────────────────────────────
func _draw_char(font: Font, rect: Rect2, ch: String,
		color: Color, font_size: int) -> void:
	draw_string(font,
		Vector2(rect.position.x, rect.position.y + TILE_SIZE - 6),
		ch,
		HORIZONTAL_ALIGNMENT_CENTER,
		TILE_SIZE,
		font_size,
		color)
