class_name Assets
extends RefCounted
## スプライトパス定義ファイル。
## 素材を差し替える場合は対応するパスだけ変更すれば全体に反映される。

# ─── プレイヤー ─────────────────────────────────────────────
const PLAYER := "res://assets/sprites/player/player.png"

# ─── マップタイル ───────────────────────────────────────────
const TILE_FLOOR  := "res://assets/sprites/tiles/floor.png"
const TILE_WALL   := "res://assets/sprites/tiles/wall.png"
const TILE_STAIRS := "res://assets/sprites/tiles/stairs.png"

# ─── 敵スプライト ─────────────────────────────────────────────
## キーは enemy_data.gd の "id" フィールドと対応
const ENEMIES := {
	"slime":       "res://assets/sprites/enemies/slime.png",
	"bat":         "res://assets/sprites/enemies/bat.png",
	"goblin":      "res://assets/sprites/enemies/goblin.png",
	"skeleton":    "res://assets/sprites/enemies/skeleton.png",
	"orc":         "res://assets/sprites/enemies/orc.png",
	"ghost":       "res://assets/sprites/enemies/ghost.png",
	"troll":       "res://assets/sprites/enemies/troll.png",
	"witch":       "res://assets/sprites/enemies/witch.png",
	"dragon":      "res://assets/sprites/enemies/dragon.png",
	"dark_knight": "res://assets/sprites/enemies/dark_knight.png",
	"guardian":    "res://assets/sprites/enemies/guardian.png",
}

# ─── アイテム種別スプライト ──────────────────────────────────
## キーは ItemData.TYPE_* 定数（int）と対応
const ITEM_TYPES := {
	0: "res://assets/sprites/items/weapon.png",   # 武器
	1: "res://assets/sprites/items/shield.png",   # 盾
	2: "res://assets/sprites/items/food.png",     # 食料
	3: "res://assets/sprites/items/scroll.png",   # 巻物
	4: "res://assets/sprites/items/pot.png",      # 壺
	5: "res://assets/sprites/items/ring.png",     # 指輪
}

# ─── ユーティリティ ─────────────────────────────────────────
## 敵IDからスプライトパスを取得
static func enemy_sprite(enemy_id: String) -> String:
	return ENEMIES.get(enemy_id, "")

## アイテム種別int からスプライトパスを取得
static func item_type_sprite(type_int: int) -> String:
	return ITEM_TYPES.get(type_int, "")
