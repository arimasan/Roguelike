class_name ItemData
extends RefCounted

# type int constants (used in item dicts)
const TYPE_WEAPON  = 0
const TYPE_SHIELD  = 1
const TYPE_FOOD    = 2
const TYPE_SCROLL  = 3
const TYPE_POT     = 4
const TYPE_RING    = 5
const TYPE_STAFF   = 6
const TYPE_POTION  = 7

static func type_color(t: int) -> Color:
	match t:
		TYPE_WEAPON: return Color(0.75, 0.75, 0.85)
		TYPE_SHIELD: return Color(0.65, 0.55, 0.35)
		TYPE_FOOD:   return Color(0.35, 0.80, 0.35)
		TYPE_SCROLL: return Color(0.90, 0.90, 0.25)
		TYPE_POT:    return Color(0.35, 0.55, 0.90)
		TYPE_RING:   return Color(0.90, 0.50, 0.15)
		TYPE_STAFF:  return Color(0.60, 0.85, 1.00)
		TYPE_POTION: return Color(0.95, 0.45, 0.75)
	return Color.WHITE

static func type_symbol(t: int) -> String:
	match t:
		TYPE_WEAPON: return ")"
		TYPE_SHIELD: return "["
		TYPE_FOOD:   return "%"
		TYPE_SCROLL: return "?"
		TYPE_POT:    return "!"
		TYPE_RING:   return "="
		TYPE_STAFF:  return "/"
		TYPE_POTION: return "草"
	return "*"

# weight: 出現頻度の重み（高いほど出やすい）
const ALL: Array = [
	# ── 武器（seal_slots=空き印数, seal_id/seal_name/seal_desc=素材としての印） ──
	{"id":"wood_sword",    "name":"木の剣",     "type":TYPE_WEAPON, "atk":3,  "weight":35, "seal_slots":3},
	{"id":"iron_sword",    "name":"鉄の剣",     "type":TYPE_WEAPON, "atk":7,  "weight":25, "seal_slots":4},
	{"id":"silver_sword",  "name":"銀の剣",     "type":TYPE_WEAPON, "atk":12, "weight":15, "seal_slots":5, "seal_id":"silver",  "seal_name":"銀", "seal_desc":"ATK+3"},
	{"id":"ancient_blade", "name":"古代の刃",   "type":TYPE_WEAPON, "atk":20, "weight":6,  "seal_slots":6, "seal_id":"ancient", "seal_name":"古", "seal_desc":"ATK+5"},
	{"id":"cursed_sword",  "name":"呪われた剣", "type":TYPE_WEAPON, "atk":28, "cursed":true, "weight":5, "se":"curse", "seal_slots":2, "seal_id":"curse", "seal_name":"呪", "seal_desc":"攻撃時5%金縛り"},
	{"id":"flame_sword",   "name":"炎の剣",     "type":TYPE_WEAPON, "atk":15, "effect":"burn","weight":8, "se":"fire", "seal_slots":5, "seal_id":"burn", "seal_name":"炎", "seal_desc":"攻撃時+炎ダメージ"},
	# ── 盾 ──────────────────────────────────────────────────
	{"id":"wood_shield",   "name":"木の盾",     "type":TYPE_SHIELD, "def":3,  "weight":30, "seal_slots":3},
	{"id":"iron_shield",   "name":"鉄の盾",     "type":TYPE_SHIELD, "def":7,  "weight":22, "seal_slots":4},
	{"id":"silver_shield", "name":"銀の盾",     "type":TYPE_SHIELD, "def":12, "weight":12, "seal_slots":5, "seal_id":"silver_def",  "seal_name":"銀", "seal_desc":"DEF+3"},
	{"id":"ancient_shield","name":"古代の盾",   "type":TYPE_SHIELD, "def":20, "weight":5,  "seal_slots":6, "seal_id":"ancient_def", "seal_name":"古", "seal_desc":"DEF+5"},
	{"id":"cursed_shield", "name":"呪われた盾", "type":TYPE_SHIELD, "def":25, "cursed":true, "weight":4, "se":"curse", "seal_slots":2, "seal_id":"curse_def", "seal_name":"呪", "seal_desc":"被弾時5%敵金縛り"},
	# ── 食料 ────────────────────────────────────────────────
	{"id":"rice_ball",     "name":"おにぎり",       "type":TYPE_FOOD, "fullness":50,  "weight":45},
	{"id":"big_rice_ball", "name":"大きなおにぎり", "type":TYPE_FOOD, "fullness":100, "weight":18},
	{"id":"bread",         "name":"パン",           "type":TYPE_FOOD, "fullness":30,  "weight":38},
	{"id":"rotten_food",   "name":"腐った食料",     "type":TYPE_FOOD, "fullness":-30, "weight":8},
	# ── 薬 ──────────────────────────────────────────────────
	{"id":"herb",          "name":"薬草",   "type":TYPE_POTION, "heal":25,           "weight":30},
	{"id":"power_herb",    "name":"力の薬草","type":TYPE_POTION, "atk_up":2,          "weight":12},
	{"id":"potion_heal",   "name":"回復薬", "type":TYPE_POTION, "heal":50,           "weight":22},
	{"id":"potion_cure",   "name":"万能薬", "type":TYPE_POTION, "effect":"antidote", "weight":14},
	{"id":"potion_detox",  "name":"解毒薬", "type":TYPE_POTION, "effect":"detox",    "weight":18},
	{"id":"potion_awaken", "name":"覚醒薬", "type":TYPE_POTION, "effect":"awaken",   "weight":14},
	{"id":"potion_charm",  "name":"魅了の薬","type":TYPE_POTION, "effect":"charm",   "weight":8,  "se":"curse"},
	# ── 本 ──────────────────────────────────────────────────
	{"id":"sc_identify",   "name":"識別の本",      "type":TYPE_SCROLL, "effect":"identify",  "weight":20},
	{"id":"sc_warp",       "name":"転移の本",      "type":TYPE_SCROLL, "effect":"warp",      "weight":18},
	{"id":"sc_explosion",  "name":"爆発の本",      "type":TYPE_SCROLL, "effect":"explosion", "weight":14, "se":"fire"},
	{"id":"sc_uncurse",    "name":"魔除けの本",    "type":TYPE_SCROLL, "effect":"uncurse",   "weight":16, "se":"curse"},
	{"id":"sc_sleep",      "name":"眠りの本",      "type":TYPE_SCROLL, "effect":"sleep",     "weight":16, "se":"curse"},
	{"id":"sc_map",        "name":"地図の本",      "type":TYPE_SCROLL, "effect":"map",       "weight":14},
	{"id":"sc_monster",    "name":"モンスターの本", "type":TYPE_SCROLL, "effect":"monster",  "weight":8},
	{"id":"sc_slow",       "name":"鈍足の本",      "type":TYPE_SCROLL, "effect":"slow",      "weight":14, "se":"curse"},
	{"id":"sc_confuse",    "name":"混乱の本",      "type":TYPE_SCROLL, "effect":"confuse",   "weight":12, "se":"curse"},
	# ── 箱 ──────────────────────────────────────────────────
	{"id":"pot_heal",      "name":"回復の箱",  "type":TYPE_POT, "effect":"heal",     "uses":3, "weight":22},
	{"id":"pot_poison",    "name":"毒の箱",    "type":TYPE_POT, "effect":"poison",   "uses":3, "weight":15, "se":"curse"},
	{"id":"pot_storage",   "name":"保存の箱",  "type":TYPE_POT, "effect":"storage",  "weight":12},
	{"id":"pot_blind",     "name":"盲目の箱",  "type":TYPE_POT, "effect":"blind",    "uses":3, "weight":10, "se":"curse"},
	{"id":"pot_strength",  "name":"強化の箱",  "type":TYPE_POT, "effect":"strength", "uses":2, "weight":8},
	{"id":"pot_synthesis", "name":"合成の箱",  "type":TYPE_POT, "effect":"synthesis","weight":6},
	# ── 指輪 ────────────────────────────────────────────────
	{"id":"ring_regen",    "name":"回復指輪",  "type":TYPE_RING, "effect":"regen",        "weight":12},
	{"id":"ring_hunger",   "name":"満腹指輪",  "type":TYPE_RING, "effect":"slow_hunger",  "weight":12},
	{"id":"ring_atk",      "name":"攻撃指輪",  "type":TYPE_RING, "atk":5,                "weight":14},
	{"id":"ring_def",      "name":"防御指輪",  "type":TYPE_RING, "def":5,                "weight":14},
	{"id":"ring_detect",   "name":"探知指輪",  "type":TYPE_RING, "effect":"detection",    "weight":9},
	{"id":"ring_exp",      "name":"経験指輪",  "type":TYPE_RING, "effect":"exp_boost",    "weight":8},
	{"id":"ring_trap_sense","name":"よくみえの腕輪","type":TYPE_RING, "effect":"trap_sense","weight":9},
	# ── 杖 ──────────────────────────────────────────────────
	{"id":"staff_fire",      "name":"火炎の杖",       "type":TYPE_STAFF, "effect":"fire",      "uses":5, "weight":14, "se":"fire"},
	{"id":"staff_thunder",   "name":"雷の杖",         "type":TYPE_STAFF, "effect":"thunder",   "uses":4, "weight":12, "se":"lightning"},
	{"id":"staff_freeze",    "name":"氷結の杖",       "type":TYPE_STAFF, "effect":"freeze",    "uses":3, "weight":10, "se":"ice"},
	{"id":"staff_knockback", "name":"吹き飛ばしの杖", "type":TYPE_STAFF, "effect":"knockback", "uses":4, "weight":12},
	{"id":"staff_seal",      "name":"封印の杖",       "type":TYPE_STAFF, "effect":"seal",      "uses":4, "weight":10, "se":"curse"},
	{"id":"staff_magic",     "name":"魔力の杖",       "type":TYPE_STAFF, "effect":"magic",     "uses":2, "weight":6},
	{"id":"staff_charm",     "name":"魅了の杖",       "type":TYPE_STAFF, "effect":"charm",     "uses":3, "weight":8,  "se":"curse"},
]

static func sell_price(item: Dictionary) -> int:
	return max(1, shop_price(item) / 2)

static func shop_price(item: Dictionary) -> int:
	var base := 50
	match item.get("type", -1):
		TYPE_WEAPON: base = max(50,  item.get("atk", 0) * 15 + 30)
		TYPE_SHIELD: base = max(50,  item.get("def", 0) * 15 + 30)
		TYPE_FOOD:   base = max(20,  item.get("fullness", 0) / 2  + 15)
		TYPE_POTION:
			base = max(30, item.get("heal", 0) + item.get("atk_up", 0) * 20 + 30)
			match item.get("effect", ""):
				"antidote": base = max(base, 80)
				"detox", "awaken": base = max(base, 50)
				"charm": base = max(base, 120)
		TYPE_SCROLL:
			match item.get("effect", ""):
				"identify": base = 60
				"warp", "uncurse": base = 80
				"sleep", "slow", "confuse": base = 100
				"map": base = 120
				"explosion": base = 150
				"monster": base = 40
				_: base = 80
		TYPE_POT:
			if item.get("effect", "") == "storage":
				base = max(80, item.get("capacity", 3) * 30 + 50)
			else:
				base = max(60, item.get("uses", 1) * 25 + 30)
		TYPE_RING:
			match item.get("effect", ""):
				"exp_boost": base = 250
				"detection": base = 200
				"trap_sense": base = 180
				"regen", "slow_hunger": base = 150
				_: base = max(150, item.get("atk", 0) * 30 + item.get("def", 0) * 30 + 50)
		TYPE_STAFF:
			var uses_val: int = item.get("uses", 1)
			base = max(60, uses_val * 30 + 40)
			if item.get("effect", "") == "charm":
				base = max(base, uses_val * 50 + 60)
	if item.get("cursed", false):
		base = max(10, base / 3)
	# 修正値と印によるボーナス（武器/盾のみ）
	var plus_val: int = int(item.get("plus", 0))
	if plus_val > 0:
		base += plus_val * 10
	var seals: Array = item.get("seals", [])
	base += seals.size() * 20
	return base

static func get_by_id(item_id: String) -> Dictionary:
	for item in ALL:
		if item.get("id", "") == item_id:
			var out: Dictionary = item.duplicate(true)
			var eff: String = out.get("effect", "")
			if eff == "storage" or eff == "synthesis":
				if not out.has("capacity"):
					out["capacity"] = randi_range(3, 6)
			return out
	return {}

static func random_item(_floor_num: int) -> Dictionary:
	var total: int = 0
	for item in ALL:
		total += item.get("weight", 10)
	var roll := randi() % total
	var acc := 0
	for item in ALL:
		acc += item.get("weight", 10)
		if roll < acc:
			var out: Dictionary = item.duplicate(true)
			var eff2: String = out.get("effect", "")
			if eff2 == "storage" or eff2 == "synthesis":
				out["capacity"] = randi_range(3, 6)
			_apply_curse_bless(out, _floor_num)
			return out
	return ALL[0].duplicate(true)

## 呪い／祝福をダンジョン設定に基づいてランダム付与
## 箱(TYPE_POT)とお祓い系は呪われない。呪いと祝福は排他。
static func _apply_curse_bless(item: Dictionary, floor_num: int) -> void:
	var t: int = item.get("type", -1)
	# 箱は呪われない・祝福されない
	if t == TYPE_POT:
		return
	# お祓いの書は呪われない
	if item.get("effect", "") == "uncurse":
		return
	# 既に cursed フラグが設定済み（呪われた剣など固定呪い品）はスキップ
	if item.get("cursed", false):
		return
	var c_chance: float = DungeonConfig.curse_chance(floor_num)
	var b_chance: float = DungeonConfig.bless_chance(floor_num)
	var r: float = randf()
	if r < c_chance:
		item["cursed"] = true
	elif r < c_chance + b_chance:
		item["blessed"] = true
