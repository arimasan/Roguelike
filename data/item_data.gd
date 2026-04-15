class_name ItemData
extends RefCounted

# type int constants (used in item dicts)
const TYPE_WEAPON = 0
const TYPE_SHIELD = 1
const TYPE_FOOD   = 2
const TYPE_SCROLL = 3
const TYPE_POT    = 4
const TYPE_RING   = 5
const TYPE_STAFF  = 6

static func type_color(t: int) -> Color:
	match t:
		TYPE_WEAPON: return Color(0.75, 0.75, 0.85)
		TYPE_SHIELD: return Color(0.65, 0.55, 0.35)
		TYPE_FOOD:   return Color(0.35, 0.80, 0.35)
		TYPE_SCROLL: return Color(0.90, 0.90, 0.25)
		TYPE_POT:    return Color(0.35, 0.55, 0.90)
		TYPE_RING:   return Color(0.90, 0.50, 0.15)
		TYPE_STAFF:  return Color(0.60, 0.85, 1.00)
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
	return "*"

# weight: 出現頻度の重み（高いほど出やすい）
const ALL: Array = [
	# ── 武器 ───────────────────────────────────────────────
	{"id":"wood_sword",    "name":"木の剣",         "type":TYPE_WEAPON, "atk":3,  "weight":35},
	{"id":"iron_sword",    "name":"鉄の剣",         "type":TYPE_WEAPON, "atk":7,  "weight":25},
	{"id":"silver_sword",  "name":"銀の剣",         "type":TYPE_WEAPON, "atk":12, "weight":15},
	{"id":"ancient_blade", "name":"古代の刃",       "type":TYPE_WEAPON, "atk":20, "weight":6},
	{"id":"cursed_sword",  "name":"呪われた剣",     "type":TYPE_WEAPON, "atk":28, "cursed":true, "weight":5},
	{"id":"flame_sword",   "name":"炎の剣",         "type":TYPE_WEAPON, "atk":15, "effect":"burn","weight":8},
	# ── 盾 ──────────────────────────────────────────────────
	{"id":"wood_shield",   "name":"木の盾",         "type":TYPE_SHIELD, "def":3,  "weight":30},
	{"id":"iron_shield",   "name":"鉄の盾",         "type":TYPE_SHIELD, "def":7,  "weight":22},
	{"id":"silver_shield", "name":"銀の盾",         "type":TYPE_SHIELD, "def":12, "weight":12},
	{"id":"ancient_shield","name":"古代の盾",       "type":TYPE_SHIELD, "def":20, "weight":5},
	{"id":"cursed_shield", "name":"呪われた盾",     "type":TYPE_SHIELD, "def":25, "cursed":true,"weight":4},
	# ── 食料 ────────────────────────────────────────────────
	{"id":"rice_ball",     "name":"おにぎり",       "type":TYPE_FOOD, "fullness":50, "weight":45},
	{"id":"big_rice_ball", "name":"大きなおにぎり", "type":TYPE_FOOD, "fullness":100,"weight":18},
	{"id":"bread",         "name":"パン",           "type":TYPE_FOOD, "fullness":30, "weight":38},
	{"id":"herb",          "name":"薬草",           "type":TYPE_FOOD, "fullness":10, "heal":20, "weight":28},
	{"id":"power_herb",    "name":"力の薬草",       "type":TYPE_FOOD, "fullness":10, "heal":0, "atk_up":2, "weight":10},
	{"id":"rotten_food",   "name":"腐った食料",     "type":TYPE_FOOD, "fullness":-30,"weight":8},
	# ── 本 ──────────────────────────────────────────────────
	{"id":"sc_identify",   "name":"識別の本",     "type":TYPE_SCROLL, "effect":"identify",  "weight":20},
	{"id":"sc_warp",       "name":"転移の本",     "type":TYPE_SCROLL, "effect":"warp",      "weight":18},
	{"id":"sc_explosion",  "name":"爆発の本",     "type":TYPE_SCROLL, "effect":"explosion", "weight":14},
	{"id":"sc_uncurse",    "name":"魔除けの本",   "type":TYPE_SCROLL, "effect":"uncurse",   "weight":16},
	{"id":"sc_sleep",      "name":"眠りの本",     "type":TYPE_SCROLL, "effect":"sleep",     "weight":16},
	{"id":"sc_map",        "name":"地図の本",     "type":TYPE_SCROLL, "effect":"map",       "weight":14},
	{"id":"sc_monster",    "name":"モンスターの本","type":TYPE_SCROLL,"effect":"monster",   "weight":8},
	# ── 箱 ──────────────────────────────────────────────────
	{"id":"pot_heal",      "name":"回復の箱",  "type":TYPE_POT, "effect":"heal",    "uses":3, "weight":22},
	{"id":"pot_poison",    "name":"毒の箱",    "type":TYPE_POT, "effect":"poison",  "uses":3, "weight":15},
	{"id":"pot_storage",   "name":"保存の箱",  "type":TYPE_POT, "effect":"storage", "uses":5, "weight":12},
	{"id":"pot_blind",     "name":"盲目の箱",  "type":TYPE_POT, "effect":"blind",   "uses":3, "weight":10},
	{"id":"pot_strength",  "name":"強化の箱",  "type":TYPE_POT, "effect":"strength","uses":2, "weight":8},
	# ── 指輪 ────────────────────────────────────────────────
	{"id":"ring_regen",    "name":"回復指輪",   "type":TYPE_RING, "effect":"regen",       "weight":12},
	{"id":"ring_hunger",   "name":"満腹指輪",   "type":TYPE_RING, "effect":"slow_hunger", "weight":12},
	{"id":"ring_atk",      "name":"攻撃指輪",   "type":TYPE_RING, "atk":5,               "weight":14},
	{"id":"ring_def",      "name":"防御指輪",   "type":TYPE_RING, "def":5,               "weight":14},
	{"id":"ring_detect",   "name":"探知指輪",   "type":TYPE_RING, "effect":"detection",   "weight":9},
	{"id":"ring_exp",      "name":"経験指輪",   "type":TYPE_RING, "effect":"exp_boost",   "weight":8},
	# ── 杖 ──────────────────────────────────────────────────
	{"id":"staff_fire",      "name":"火炎の杖",       "type":TYPE_STAFF, "effect":"fire",      "uses":5, "weight":14},
	{"id":"staff_thunder",   "name":"雷の杖",         "type":TYPE_STAFF, "effect":"thunder",   "uses":4, "weight":12},
	{"id":"staff_freeze",    "name":"氷結の杖",       "type":TYPE_STAFF, "effect":"freeze",    "uses":3, "weight":10},
	{"id":"staff_knockback", "name":"吹き飛ばしの杖", "type":TYPE_STAFF, "effect":"knockback", "uses":4, "weight":12},
	{"id":"staff_seal",      "name":"封印の杖",       "type":TYPE_STAFF, "effect":"seal",      "uses":4, "weight":10},
	{"id":"staff_magic",     "name":"魔力の杖",       "type":TYPE_STAFF, "effect":"magic",     "uses":2, "weight":6},
]

static func sell_price(item: Dictionary) -> int:
	return max(1, shop_price(item) / 2)

static func shop_price(item: Dictionary) -> int:
	var base := 50
	match item.get("type", -1):
		TYPE_WEAPON: base = max(50,  item.get("atk",      0) * 15 + 30)
		TYPE_SHIELD: base = max(50,  item.get("def",      0) * 15 + 30)
		TYPE_FOOD:   base = max(20,  item.get("fullness", 0) / 2  + 15)
		TYPE_SCROLL: base = 80
		TYPE_POT:    base = max(60,  item.get("uses",     1) * 25 + 30)
		TYPE_RING:   base = 150
		TYPE_STAFF:  base = max(60,  item.get("uses",     1) * 30 + 40)
	if item.get("cursed", false):
		base = max(10, base / 3)
	return base

static func get_by_id(item_id: String) -> Dictionary:
	for item in ALL:
		if item.get("id", "") == item_id:
			return item.duplicate(true)
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
			return item.duplicate(true)
	return ALL[0].duplicate(true)
