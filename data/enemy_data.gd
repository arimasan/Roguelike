class_name EnemyData
extends RefCounted

# behavior types:
#   "normal"  - chase in sight, random walk otherwise
#   "fast"    - takes 2 move actions per turn
#   "ghost"   - ignores walls when moving
#   "regen"   - regenerates 1 HP per turn
#   "boss"    - normal AI but stronger, special message on death
const ALL: Array = [
	{
		"id": "slime",
		"name": "スライム",
		"symbol": "s",
		"color": Color(0.30, 0.80, 0.30),
		"hp": 8, "atk": 3, "def": 0, "exp": 3,
		"floor_min": 1, "floor_max": 6,
		"behavior": "normal",
	},
	{
		"id": "bat",
		"name": "コウモリ",
		"symbol": "b",
		"color": Color(0.50, 0.25, 0.60),
		"hp": 7, "atk": 4, "def": 1, "exp": 4,
		"floor_min": 1, "floor_max": 8,
		"behavior": "fast",
	},
	{
		"id": "goblin",
		"name": "ゴブリン",
		"symbol": "g",
		"color": Color(0.50, 0.75, 0.20),
		"hp": 15, "atk": 6, "def": 2, "exp": 6,
		"floor_min": 3, "floor_max": 11,
		"behavior": "normal",
	},
	{
		"id": "skeleton",
		"name": "スケルトン",
		"symbol": "S",
		"color": Color(0.85, 0.85, 0.75),
		"hp": 20, "atk": 8, "def": 3, "exp": 10,
		"floor_min": 6, "floor_max": 15,
		"behavior": "normal",
	},
	{
		"id": "orc",
		"name": "オーク",
		"symbol": "O",
		"color": Color(0.65, 0.42, 0.18),
		"hp": 28, "atk": 10, "def": 5, "exp": 15,
		"floor_min": 9, "floor_max": 19,
		"behavior": "normal",
	},
	{
		"id": "ghost",
		"name": "ゴースト",
		"symbol": "G",
		"color": Color(0.65, 0.65, 0.95),
		"hp": 14, "atk": 12, "def": 8, "exp": 18,
		"floor_min": 10, "floor_max": 22,
		"behavior": "ghost",
	},
	{
		"id": "troll",
		"name": "トロル",
		"symbol": "T",
		"color": Color(0.55, 0.38, 0.15),
		"hp": 40, "atk": 13, "def": 6, "exp": 22,
		"floor_min": 12, "floor_max": 24,
		"behavior": "regen",
	},
	{
		"id": "witch",
		"name": "魔女",
		"symbol": "W",
		"color": Color(0.75, 0.10, 0.75),
		"hp": 22, "atk": 15, "def": 4, "exp": 26,
		"floor_min": 14, "floor_max": 26,
		"behavior": "normal",
	},
	{
		"id": "dragon",
		"name": "ドラゴン",
		"symbol": "D",
		"color": Color(0.90, 0.15, 0.05),
		"hp": 55, "atk": 18, "def": 10, "exp": 40,
		"floor_min": 18, "floor_max": 29,
		"behavior": "normal",
	},
	{
		"id": "dark_knight",
		"name": "ダークナイト",
		"symbol": "K",
		"color": Color(0.15, 0.15, 0.45),
		"hp": 65, "atk": 20, "def": 14, "exp": 55,
		"floor_min": 22, "floor_max": 29,
		"behavior": "normal",
	},
	{
		"id": "guardian",
		"name": "古代の守護者",
		"symbol": "B",
		"color": Color(1.00, 0.75, 0.00),
		"hp": 120, "atk": 28, "def": 20, "exp": 200,
		"floor_min": 30, "floor_max": 30,
		"behavior": "boss",
	},
]

static func get_by_id(enemy_id: String) -> Dictionary:
	for e in ALL:
		if e.get("id", "") == enemy_id:
			return e.duplicate(true)
	return {}

static func for_floor(floor_num: int) -> Array:
	var result: Array = []
	for e in ALL:
		if floor_num >= e["floor_min"] and floor_num <= e["floor_max"]:
			result.append(e)
	return result
