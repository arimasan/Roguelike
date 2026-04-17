class_name TrapData
extends RefCounted
## ワナ定義ファイル。
## break_chance: 発動後に壊れる確率（0.0〜1.0）

const ALL: Array = [
	{"id":"damage",   "name":"ダメージのワナ",   "break_chance":0.50, "se":"trap"},
	{"id":"warp",     "name":"テレポートのワナ", "break_chance":0.40, "se":"trap"},
	{"id":"hunger",   "name":"空腹のワナ",       "break_chance":0.60, "se":"trap"},
	{"id":"blind",    "name":"目くらましのワナ", "break_chance":0.50, "se":"curse"},
	{"id":"poison",   "name":"毒のワナ",         "break_chance":0.45, "se":"curse"},
	{"id":"sleep",    "name":"眠りのワナ",       "break_chance":0.55, "se":"curse"},
	{"id":"drop_item","name":"転倒のワナ",       "break_chance":0.70, "se":"trap"},
	{"id":"alarm",    "name":"警報のワナ",       "break_chance":0.90, "se":"trap"},
	{"id":"slow",     "name":"鈍足のワナ",       "break_chance":0.55, "se":"curse"},
	{"id":"confuse",  "name":"混乱のワナ",       "break_chance":0.60, "se":"curse"},
	{"id":"unequip",  "name":"装備外しのワナ",   "break_chance":0.50, "se":"trap"},
]

static func get_by_id(trap_id: String) -> Dictionary:
	for t in ALL:
		if t.get("id", "") == trap_id:
			return t.duplicate(true)
	return {}

static func random_trap() -> Dictionary:
	return ALL[randi() % ALL.size()].duplicate(true)

static func break_chance(trap_id: String) -> float:
	return float(get_by_id(trap_id).get("break_chance", 0.5))

static func trap_name(trap_id: String) -> String:
	return get_by_id(trap_id).get("name", "ワナ")

static func trap_se(trap_id: String) -> String:
	return get_by_id(trap_id).get("se", "trap")
