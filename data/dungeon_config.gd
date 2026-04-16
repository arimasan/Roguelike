class_name DungeonConfig
extends RefCounted
## フロア・ダンジョン別のパラメータ定義。
## 将来的にダンジョン種別（通常・遺跡・洞窟など）の軸を追加する場合は
## get_config(dungeon_id, floor_num) のように引数を増やす。

# ─── フロア設定テーブル ───────────────────────────────────
# 上から順に評価し、floor_min〜floor_max に一致した最初のエントリを使用。
# 複数エントリを重ねることでフロア帯ごとに細かく設定できる。
#
# 設定キー一覧（将来追加分もここに記載する）:
#   shop_chance      : float  店の出現確率 0.0〜1.0
#   enemy_density    : float  敵数倍率（1.0=標準）  ※将来用
#   item_density     : float  アイテム数倍率         ※将来用
#   gold_multiplier  : float  金額倍率               ※将来用

const FLOOR_CONFIGS: Array = [
	# ── デバッグ用：全フロア 100% 出現 ──────────────────────
	{
		"floor_min":            1,
		"floor_max":           50,
		"shop_chance":          1.0,   # デバッグ用 100%（通常は 0.25）
		"monster_house_chance": 1.0,   # デバッグ用 100%（通常は 0.30）
	},

	# ── 将来の設定例（コメントアウト中） ───────────────────
	# 序盤（1〜10F）
	# { "floor_min":  1, "floor_max": 10, "shop_chance": 0.25, "monster_house_chance": 0.10 },
	# 中盤（11〜20F）
	# { "floor_min": 11, "floor_max": 20, "shop_chance": 0.30, "monster_house_chance": 0.20 },
	# 終盤（21〜30F）
	# { "floor_min": 21, "floor_max": 30, "shop_chance": 0.20, "monster_house_chance": 0.30 },
]

# ─── フロア設定取得 ───────────────────────────────────────
## floor_num に対応する設定 Dictionary を返す。
## 一致するエントリがなければ最後のエントリをフォールバックとして使用。
static func get_floor_config(floor_num: int) -> Dictionary:
	for cfg in FLOOR_CONFIGS:
		if floor_num >= int(cfg["floor_min"]) and floor_num <= int(cfg["floor_max"]):
			return cfg
	return FLOOR_CONFIGS[FLOOR_CONFIGS.size() - 1]

# ─── 個別アクセサ ─────────────────────────────────────────
static func shop_chance(floor_num: int) -> float:
	return float(get_floor_config(floor_num).get("shop_chance", 0.25))

static func monster_house_chance(floor_num: int) -> float:
	return float(get_floor_config(floor_num).get("monster_house_chance", 0.30))
