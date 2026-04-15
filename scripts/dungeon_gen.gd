class_name DungeonGenerator
extends RefCounted

const MAP_W    := 60
const MAP_H    := 40
const TILE_WALL   := 0
const TILE_FLOOR  := 1
const TILE_STAIRS := 2

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

# ─── 生成メイン ───────────────────────────────────────────
func generate(floor_num: int) -> void:
	_init_map()
	_place_rooms()
	_connect_all_rooms()
	_place_stairs_and_player()
	_pick_spawn_points(floor_num)

func _init_map() -> void:
	map = []
	rooms = []
	enemy_spawns = []
	item_spawns  = []
	for y in MAP_H:
		var row := []
		for x in MAP_W:
			row.append(TILE_WALL)
		map.append(row)

func _place_rooms() -> void:
	var attempts := MAX_ROOMS * 5
	while rooms.size() < MAX_ROOMS and attempts > 0:
		attempts -= 1
		var w := randi_range(MIN_ROOM_W, MAX_ROOM_W)
		var h := randi_range(MIN_ROOM_H, MAX_ROOM_H)
		var x := randi_range(1, MAP_W - w - 1)
		var y := randi_range(1, MAP_H - h - 1)
		var nr := Rect2i(x, y, w, h)
		var ok := true
		for r in rooms:
			if nr.intersects(Rect2i(r.position - Vector2i(1,1), r.size + Vector2i(2,2))):
				ok = false
				break
		if ok:
			_carve_room(nr)
			rooms.append(nr)

func _connect_all_rooms() -> void:
	for i in range(1, rooms.size()):
		_connect(rooms[i - 1], rooms[i])
	# 追加ループで接続性を上げる
	if rooms.size() > 3:
		_connect(rooms[0], rooms[rooms.size() - 1])

func _connect(a: Rect2i, b: Rect2i) -> void:
	var ac := _center(a)
	var bc := _center(b)
	if randi() % 2 == 0:
		_h_tunnel(ac.x, bc.x, ac.y)
		_v_tunnel(ac.y, bc.y, bc.x)
	else:
		_v_tunnel(ac.y, bc.y, ac.x)
		_h_tunnel(ac.x, bc.x, bc.y)

func _place_stairs_and_player() -> void:
	player_start = _center(rooms[0])
	stairs_pos   = _center(rooms[rooms.size() - 1])
	_set_tile(stairs_pos.x, stairs_pos.y, TILE_STAIRS)

func _pick_spawn_points(floor_num: int) -> void:
	# 敵: 部屋ごとに0〜2体（最初の部屋と最後の部屋は除く）
	for i in range(1, rooms.size() - 1):
		var room: Rect2i = rooms[i]
		var num_enemies := randi_range(0, min(2, 1 + floor_num / 5))
		for _j in num_enemies:
			var p := _rand_floor(room)
			if p != Vector2i(-1, -1):
				enemy_spawns.append(p)
		# アイテム: 1部屋に0〜1個
		if randi() % 3 != 0:
			var p := _rand_floor(room)
			if p != Vector2i(-1, -1):
				item_spawns.append(p)
	# スタート部屋にも少し
	var sp := _rand_floor(rooms[0])
	if sp != Vector2i(-1, -1) and sp != player_start:
		item_spawns.append(sp)

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
		if map[y][x] == TILE_FLOOR:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

# ─── 公開API ──────────────────────────────────────────────
func get_tile(x: int, y: int) -> int:
	if x < 0 or x >= MAP_W or y < 0 or y >= MAP_H:
		return TILE_WALL
	return map[y][x]

func is_walkable(x: int, y: int) -> bool:
	return get_tile(x, y) != TILE_WALL

func random_floor_pos() -> Vector2i:
	for _i in 200:
		var x := randi_range(0, MAP_W - 1)
		var y := randi_range(0, MAP_H - 1)
		if map[y][x] == TILE_FLOOR:
			return Vector2i(x, y)
	return player_start
