class_name DungeonGenerator
extends RefCounted

const MAP_W    := 80
const MAP_H    := 50
const TILE_WALL       := 0
const TILE_FLOOR      := 1
const TILE_STAIRS     := 2
const TILE_SHOP_FLOOR := 3

const MAX_ROOMS    := 14
const MIN_ROOM_W   := 4
const MAX_ROOM_W   := 11
const MIN_ROOM_H   := 4
const MAX_ROOM_H   := 9

var map: Array = []          # Array[Array[int]] : map[y][x]
var rooms: Array = []        # Array[Rect2i]
var player_start: Vector2i = Vector2i.ZERO
var stairs_pos:   Vector2i = Vector2i.ZERO
var enemy_spawns: Array = [] # Array[Vector2i]
var item_spawns:  Array = [] # Array[Vector2i]
var trap_spawns:  Array = [] # Array[Vector2i]

# ─── 店 ───────────────────────────────────────────────────
var has_shop:            bool      = false
var shop_room:           Rect2i    = Rect2i()
var shop_keeper_pos:     Vector2i  = Vector2i.ZERO
var shop_item_positions: Array     = []   # Array[Vector2i]

# ─── モンスターハウス ──────────────────────────────────────
var has_monster_house:          bool    = false
var monster_house_room:         Rect2i  = Rect2i()
var monster_house_enemy_spawns: Array   = []   # Array[Vector2i]
var monster_house_item_spawns:  Array   = []   # Array[Vector2i]
var monster_house_trap_pos:     Array   = []   # Array[Vector2i]

# ─── 生成メイン ───────────────────────────────────────────
var _floor_num: int = 0   # generate() から各サブ関数で参照するために保持
var pattern_name: String = ""   # 生成されたパターン名（デバッグ表示用）

func generate(floor_num: int) -> void:
	_floor_num = floor_num
	_init_map()
	# パターン選択＋部屋/通路生成
	var constraints: Dictionary = DungeonPatterns.generate_pattern(self)
	pattern_name = constraints.get("name", "?")
	_place_stairs_and_player()
	# 店
	if constraints.get("allow_shop", true):
		var shop_exclude: int = int(constraints.get("shop_exclude_idx", -1))
		_try_setup_shop(shop_exclude)
	# モンスターハウス
	if constraints.get("force_mh", false) and rooms.size() > 0:
		_force_monster_house(int(constraints.get("mh_room_idx", -1)))
	elif not constraints.get("no_mh", false):
		_try_setup_monster_house()
	_pick_spawn_points(floor_num)

func _init_map() -> void:
	map = []
	rooms = []
	enemy_spawns = []
	item_spawns  = []
	trap_spawns  = []
	has_shop            = false
	shop_room           = Rect2i()
	shop_keeper_pos     = Vector2i.ZERO
	shop_item_positions = []
	has_monster_house          = false
	monster_house_room         = Rect2i()
	monster_house_enemy_spawns = []
	monster_house_item_spawns  = []
	monster_house_trap_pos     = []
	for y in MAP_H:
		var row := []
		for x in MAP_W:
			row.append(TILE_WALL)
		map.append(row)

## 部屋配置・通路生成は DungeonPatterns に移動済み。

func _place_stairs_and_player() -> void:
	player_start = _center(rooms[0])
	stairs_pos   = _center(rooms[rooms.size() - 1])
	_set_tile(stairs_pos.x, stairs_pos.y, TILE_STAIRS)

func _pick_spawn_points(floor_num: int) -> void:
	# 店が占有するタイルを除外リストに登録
	var shop_reserved: Array = []
	if has_shop:
		shop_reserved.append(shop_keeper_pos)
		for p in shop_item_positions:
			shop_reserved.append(p)

	# 敵: 部屋ごとに0〜2体（最初・最後・店・MH部屋は除く）
	for i in range(1, rooms.size() - 1):
		var room: Rect2i = rooms[i]
		if has_shop and room == shop_room:
			continue
		if has_monster_house and room == monster_house_room:
			continue   # MH部屋は独自スポーン
		var num_enemies: int = randi_range(0, min(2, 1 + floor_num / 5))
		for _j in num_enemies:
			var p := _rand_floor(room)
			if p != Vector2i(-1, -1) and p not in shop_reserved:
				enemy_spawns.append(p)
		# アイテム: 1部屋に0〜1個
		if randi() % 3 != 0:
			var p := _rand_floor(room)
			if p != Vector2i(-1, -1) and p not in shop_reserved \
					and p not in item_spawns and p not in trap_spawns:
				item_spawns.append(p)
		# ワナ: 1部屋に0〜1個（約40%）
		if randi() % 5 < 2:
			var p := _rand_floor(room)
			if p != Vector2i(-1, -1) and p not in shop_reserved \
					and p not in item_spawns and p not in trap_spawns \
					and p not in enemy_spawns:
				trap_spawns.append(p)
	# スタート部屋にも少し
	var sp := _rand_floor(rooms[0])
	if sp != Vector2i(-1, -1) and sp != player_start and sp not in shop_reserved:
		item_spawns.append(sp)

func _try_setup_shop(exclude_idx: int = -1) -> void:
	if rooms.size() < 3 or randf() >= DungeonConfig.shop_chance(_floor_num):
		return
	# 最初・最後の部屋以外（＋除外指定）かつ 5×5 以上の部屋から候補を選ぶ
	var candidates: Array = []
	for i in range(1, rooms.size() - 1):
		if i == exclude_idx:
			continue
		var r: Rect2i = rooms[i]
		if r.size.x < 5 or r.size.y < 5:
			continue
		candidates.append(rooms[i])
	if candidates.is_empty():
		return
	shop_room = candidates[randi() % candidates.size()] as Rect2i
	has_shop  = true

	# 店の床タイルを TILE_SHOP_FLOOR に変換（赤カーペット）
	for y in range(shop_room.position.y, shop_room.end.y):
		for x in range(shop_room.position.x, shop_room.end.x):
			if map[y][x] == TILE_FLOOR:
				map[y][x] = TILE_SHOP_FLOOR

	# 部屋が小さすぎる場合はスキップ
	if shop_room.size.x < 3 or shop_room.size.y < 3:
		has_shop = false
		return

	# ─── 3×3グリッドを部屋中央に配置 ──────────────────────
	var center: Vector2i = _center(shop_room)
	# グリッド9マス（-1〜+1 オフセット）
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var p := Vector2i(center.x + dx, center.y + dy)
			# 部屋内かつ TILE_SHOP_FLOOR のみ
			if shop_room.has_point(p) and map[p.y][p.x] == TILE_SHOP_FLOOR:
				shop_item_positions.append(p)

	# アイテム数を最大9に制限
	while shop_item_positions.size() > 9:
		shop_item_positions.pop_back()

	if shop_item_positions.is_empty():
		has_shop = false
		return

	# 店員: グリッドの上1マス（部屋内なら）、なければグリッド外のランダムな床
	var keeper_candidate := Vector2i(center.x, center.y - 2)
	if shop_room.has_point(keeper_candidate) and map[keeper_candidate.y][keeper_candidate.x] == TILE_SHOP_FLOOR \
			and keeper_candidate not in shop_item_positions:
		shop_keeper_pos = keeper_candidate
	else:
		# グリッド外の店内タイルから探す
		var fallback: Array = []
		for y in range(shop_room.position.y, shop_room.end.y):
			for x in range(shop_room.position.x, shop_room.end.x):
				var p := Vector2i(x, y)
				if map[y][x] == TILE_SHOP_FLOOR and p not in shop_item_positions:
					fallback.append(p)
		if not fallback.is_empty():
			shop_keeper_pos = fallback[0] as Vector2i
		else:
			shop_keeper_pos = shop_item_positions[0] as Vector2i

## パターン制約によるMH強制配置。room_idx=-1 ならプレイヤー開始/階段以外からランダム。
func _force_monster_house(room_idx: int) -> void:
	if rooms.is_empty():
		return
	if room_idx < 0 or room_idx >= rooms.size():
		var candidates: Array = []
		for i in range(0, rooms.size()):
			if i == 0:
				continue
			if rooms.size() > 1 and i == rooms.size() - 1:
				continue
			candidates.append(i)
		if candidates.is_empty():
			room_idx = rooms.size() - 1
		else:
			room_idx = candidates[randi() % candidates.size()]
	monster_house_room = rooms[room_idx]
	has_monster_house  = true
	_populate_mh_spawns()

func _try_setup_monster_house() -> void:
	if rooms.size() < 3 or randf() >= DungeonConfig.monster_house_chance(_floor_num):
		return
	var candidates: Array = []
	for i in range(1, rooms.size() - 1):
		if has_shop and rooms[i] == shop_room:
			continue
		candidates.append(rooms[i])
	if candidates.is_empty():
		return
	monster_house_room = candidates[randi() % candidates.size()] as Rect2i
	has_monster_house  = true
	_populate_mh_spawns()

## MH部屋のスポーン位置リスト（敵/アイテム/ワナ）を生成する共通処理
func _populate_mh_spawns() -> void:
	var floor_tiles: Array = []
	for y in range(monster_house_room.position.y, monster_house_room.end.y):
		for x in range(monster_house_room.position.x, monster_house_room.end.x):
			var t: int = map[y][x]
			if t == TILE_FLOOR or t == TILE_SHOP_FLOOR:
				floor_tiles.append(Vector2i(x, y))
	floor_tiles.shuffle()
	if floor_tiles.size() < 5:
		has_monster_house = false
		return
	var idx: int = 0
	# 敵スポーン: 床タイルの 50〜65%（最大25体、大部屋対応で上限引き上げ）
	var enemy_count: int = min(int(floor_tiles.size() * randf_range(0.50, 0.65)), 25)
	for _i in enemy_count:
		if idx >= floor_tiles.size():
			break
		monster_house_enemy_spawns.append(floor_tiles[idx] as Vector2i)
		idx += 1
	# アイテム: 3〜6 個
	var item_count: int = min(randi_range(3, 6), floor_tiles.size() - idx)
	for _i in item_count:
		if idx >= floor_tiles.size():
			break
		monster_house_item_spawns.append(floor_tiles[idx] as Vector2i)
		idx += 1
	# ワナ: 3〜8 個
	var trap_count: int = min(randi_range(3, 8), floor_tiles.size() - idx)
	for _i in trap_count:
		if idx >= floor_tiles.size():
			break
		monster_house_trap_pos.append(floor_tiles[idx] as Vector2i)
		idx += 1

# ─── タイル操作ヘルパー ────────────────────────────────────
func _carve_room(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_set_tile(x, y, TILE_FLOOR)

func _h_tunnel(x1: int, x2: int, y: int) -> void:
	for x in range(min(x1, x2), max(x1, x2) + 1):
		_set_tile(x, y, TILE_FLOOR)

func _v_tunnel(y1: int, y2: int, x: int) -> void:
	for y in range(min(y1, y2), max(y1, y2) + 1):
		_set_tile(x, y, TILE_FLOOR)

func _set_tile(x: int, y: int, tile: int) -> void:
	if x >= 0 and x < MAP_W and y >= 0 and y < MAP_H:
		map[y][x] = tile

func _center(r: Rect2i) -> Vector2i:
	return Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)

func _rand_floor(r: Rect2i) -> Vector2i:
	for _i in 15:
		var x := randi_range(r.position.x, r.end.x - 1)
		var y := randi_range(r.position.y, r.end.y - 1)
		var t: int = map[y][x]
		if t == TILE_FLOOR or t == TILE_SHOP_FLOOR:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

# ─── 公開API ──────────────────────────────────────────────
func get_tile(x: int, y: int) -> int:
	if x < 0 or x >= MAP_W or y < 0 or y >= MAP_H:
		return TILE_WALL
	return map[y][x]

func is_walkable(x: int, y: int) -> bool:
	var t := get_tile(x, y)
	return t == TILE_FLOOR or t == TILE_STAIRS or t == TILE_SHOP_FLOOR

func random_floor_pos() -> Vector2i:
	for _i in 200:
		var x := randi_range(0, MAP_W - 1)
		var y := randi_range(0, MAP_H - 1)
		var t: int = map[y][x]
		if t == TILE_FLOOR or t == TILE_SHOP_FLOOR:
			return Vector2i(x, y)
	return player_start

## セーブデータからマップを復元する（generate() の代替）
func load_map_data(tiles_flat: Array,
		p_start_x: int, p_start_y: int,
		stairs_x: int,  stairs_y: int) -> void:
	map = []
	for y in MAP_H:
		var row := []
		for x in MAP_W:
			row.append(int(tiles_flat[y * MAP_W + x]))
		map.append(row)
	player_start = Vector2i(p_start_x, p_start_y)
	stairs_pos   = Vector2i(stairs_x,  stairs_y)
	rooms        = []
	enemy_spawns = []
	item_spawns  = []
