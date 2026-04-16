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
	# ── 序盤 ──
	"slime":             "res://assets/sprites/enemies/slime.png",
	"crow":              "res://assets/sprites/enemies/crow.png",
	"crab":              "res://assets/sprites/enemies/crab.png",
	"bat":               "res://assets/sprites/enemies/bat.png",
	"mushroom":          "res://assets/sprites/enemies/mushroom.png",
	"wolfen_girl":       "res://assets/sprites/enemies/wolfen_girl.png",
	"goblin":            "res://assets/sprites/enemies/goblin.png",
	# ── 中盤前半 ──
	"skeleton":          "res://assets/sprites/enemies/skeleton.png",
	"gnome":             "res://assets/sprites/enemies/gnome.png",
	"dryad":             "res://assets/sprites/enemies/dryad.png",
	"cat_maid_alpha":    "res://assets/sprites/enemies/cat_maid_alpha.png",
	"harpy_girl":        "res://assets/sprites/enemies/harpy_girl.png",
	"dwarf_girl":        "res://assets/sprites/enemies/dwarf_girl.png",
	"tentacle_devil":    "res://assets/sprites/enemies/tentacle_devil.png",
	"metallic_slime":    "res://assets/sprites/enemies/metallic_slime.png",
	"dancer":            "res://assets/sprites/enemies/dancer.png",
	"mimic":             "res://assets/sprites/enemies/mimic.png",
	"ghost":             "res://assets/sprites/enemies/ghost.png",
	# ── 中盤後半 ──
	"minotaur":          "res://assets/sprites/enemies/minotaur.png",
	"vampire_girl":      "res://assets/sprites/enemies/vampire_girl.png",
	"clown_girl":        "res://assets/sprites/enemies/clown_girl.png",
	"butler":            "res://assets/sprites/enemies/butler.png",
	"cat_maid_gamma":    "res://assets/sprites/enemies/cat_maid_gamma.png",
	"witch":             "res://assets/sprites/enemies/witch.png",
	# ── 終盤 ──
	"centaur":           "res://assets/sprites/enemies/centaur.png",
	"dark_elf_shaman":   "res://assets/sprites/enemies/dark_elf_shaman.png",
	"silver_fox":        "res://assets/sprites/enemies/silver_fox.png",
	"samurai_girl":      "res://assets/sprites/enemies/samurai_girl.png",
	"dark_knight":       "res://assets/sprites/enemies/dark_knight.png",
	"scylla":            "res://assets/sprites/enemies/scylla.png",
	"dragon":            "res://assets/sprites/enemies/dragon.png",
	# ── 最終 ──
	"mecha_dragon":      "res://assets/sprites/enemies/mecha_dragon.png",
	"dragon_zombie":     "res://assets/sprites/enemies/dragon_zombie.png",
	"lich":              "res://assets/sprites/enemies/lich.png",
	"inari_hime":        "res://assets/sprites/enemies/inari_hime.png",
	"death":             "res://assets/sprites/enemies/death.png",
	"goddess":           "res://assets/sprites/enemies/goddess.png",
}

# ─── アイテム種別スプライト ──────────────────────────────────
## キーは ItemData.TYPE_* 定数（int）と対応
const ITEM_TYPES := {
	0: "res://assets/sprites/items/weapon.png",   # 武器
	1: "res://assets/sprites/items/shield.png",   # 盾
	2: "res://assets/sprites/items/food.png",     # 食料
	3: "res://assets/sprites/items/scroll.png",   # 本
	4: "res://assets/sprites/items/pot.png",      # 箱
	5: "res://assets/sprites/items/ring.png",     # 指輪
	6: "res://assets/sprites/items/staff.png",    # 杖
	7: "res://assets/sprites/items/potion.png",   # 薬
}

# ─── 店 ─────────────────────────────────────────────────────
## ワナスプライト（発動後に表示）
const TRAP := "res://assets/sprites/traps/trap.png"

# ─── 店 ─────────────────────────────────────────────────────
const SHOP_KEEPER  := "res://assets/sprites/shop/shopkeeper.png"
const SHOP_SIGN    := "res://assets/sprites/shop/shop_sign.png"
const SHOP_FLOOR   := "res://assets/sprites/shop/shop_floor.png"
const SHOP_CARPET  := "res://assets/sprites/shop/shop_carpet.png"

# ─── ユーティリティ ─────────────────────────────────────────
## 敵IDからスプライトパスを取得
static func enemy_sprite(enemy_id: String) -> String:
	return ENEMIES.get(enemy_id, "")

## アイテム種別int からスプライトパスを取得
static func item_type_sprite(type_int: int) -> String:
	return ITEM_TYPES.get(type_int, "")
