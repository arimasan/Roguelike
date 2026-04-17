class_name DungeonPatterns
extends RefCounted

## マップ生成パターン集。各パターンは DungeonGenerator を受け取り、
## rooms 配列への部屋追加＋ map への通路/部屋の彫り込みを行う。
## 戻り値 Dictionary: {"allow_shop": bool, "force_mh": bool, "mh_room_idx": int(-1=ランダム)}

const W := DungeonGenerator.MAP_W   # 60
const H := DungeonGenerator.MAP_H   # 40
const MARGIN := 2   # マップ端からの余白

# ─── パターン選択 ──────────────────────────────────────────
## 抽選して対応するパターン関数を呼ぶ。戻り値は制約 dict。
static func generate_pattern(gen: DungeonGenerator) -> Dictionary:
	var roll: float = randf()
	if roll < 0.50:
		return pattern_normal(gen)
	var idx: int = randi_range(1, 10)
	match idx:
		1:  return pattern_8rooms(gen)
		2:  return pattern_12rooms(gen)
		3:  return pattern_4rooms(gen)
		4:  return pattern_2rooms(gen)
		5:  return pattern_octopus(gen)
		6:  return pattern_connected4(gen)
		7:  return pattern_big_room(gen)
		8:  return pattern_medium_room(gen)
		9:  return pattern_maze(gen)
		10: return pattern_one_stroke(gen)
	return pattern_normal(gen)

# ═══════════════════════════════════════════════════════════
# 1. 通常ランダム（既存ロジック）
# ═══════════════════════════════════════════════════════════
static func pattern_normal(gen: DungeonGenerator) -> Dictionary:
	var max_rooms := 14
	var attempts := max_rooms * 5
	while gen.rooms.size() < max_rooms and attempts > 0:
		attempts -= 1
		var w := randi_range(5, 11)
		var h := randi_range(5, 9)
		var x := randi_range(1, W - w - 1)
		var y := randi_range(1, H - h - 1)
		var nr := Rect2i(x, y, w, h)
		var ok := true
		for r: Rect2i in gen.rooms:
			if nr.intersects(Rect2i(r.position - Vector2i(1,1), r.size + Vector2i(2,2))):
				ok = false
				break
		if ok:
			_carve(gen, nr)
			gen.rooms.append(nr)
	_connect_chain(gen)
	if gen.rooms.size() > 3:
		_connect_pair(gen, gen.rooms[0], gen.rooms[gen.rooms.size() - 1])
	return {"name": "通常", "allow_shop": true, "force_mh": false, "mh_room_idx": -1}

# ═══════════════════════════════════════════════════════════
# 2. 8部屋（2×4 グリッド中央配置＋各部屋から外へ伸びる通路＋外周ループ）
# ═══════════════════════════════════════════════════════════
static func pattern_8rooms(gen: DungeonGenerator) -> Dictionary:
	# 外周ループ通路を先に彫る（マップ端から3マス内側を一周）
	var loop_margin := 3
	var lx1: int = loop_margin
	var ly1: int = loop_margin
	var lx2: int = W - 1 - loop_margin
	var ly2: int = H - 1 - loop_margin
	# 上辺・下辺（水平）
	for x in range(lx1, lx2 + 1):
		gen._set_tile(x, ly1, DungeonGenerator.TILE_FLOOR)
		gen._set_tile(x, ly2, DungeonGenerator.TILE_FLOOR)
	# 左辺・右辺（垂直）
	for y in range(ly1, ly2 + 1):
		gen._set_tile(lx1, y, DungeonGenerator.TILE_FLOOR)
		gen._set_tile(lx2, y, DungeonGenerator.TILE_FLOOR)
	# 中央に 2×4 の小さめの部屋を配置
	var cols := 4
	var rows := 2
	var inner_x1: int = 10
	var inner_x2: int = W - 10
	var inner_y1: int = 10
	var inner_y2: int = H - 10
	var cell_w: float = float(inner_x2 - inner_x1) / cols
	var cell_h: float = float(inner_y2 - inner_y1) / rows
	for row in rows:
		for col in cols:
			var rw: int = randi_range(3, mini(6, int(cell_w) - 2))
			var rh: int = randi_range(3, mini(5, int(cell_h) - 2))
			var rx: int = inner_x1 + int(col * cell_w + (cell_w - rw) / 2)
			var ry: int = inner_y1 + int(row * cell_h + (cell_h - rh) / 2)
			var room := Rect2i(rx, ry, rw, rh)
			_carve(gen, room)
			gen.rooms.append(room)
	# 各部屋の接続: 外周ループへ or 隣接部屋へ（ランダムに混在）
	# グリッド配列: rooms[row * cols + col]
	for row in rows:
		for col in cols:
			var idx: int = row * cols + col
			var rc: Vector2i = _center_of(gen.rooms[idx])
			# 50%の確率で外周ループへ直結、50%で隣接部屋と接続
			if randf() < 0.5:
				# 外周ループへ最短で接続
				var dist_top:    int = rc.y - ly1
				var dist_bottom: int = ly2 - rc.y
				var dist_left:   int = rc.x - lx1
				var dist_right:  int = lx2 - rc.x
				var min_dist: int = mini(mini(dist_top, dist_bottom), mini(dist_left, dist_right))
				if min_dist == dist_top:
					_v_tunnel(gen, rc.y, ly1, rc.x)
				elif min_dist == dist_bottom:
					_v_tunnel(gen, rc.y, ly2, rc.x)
				elif min_dist == dist_left:
					_h_tunnel(gen, rc.x, lx1, rc.y)
				else:
					_h_tunnel(gen, rc.x, lx2, rc.y)
			# 隣接部屋と接続（右隣・下隣がいれば）
			if col < cols - 1 and randf() < 0.6:
				_connect_pair(gen, gen.rooms[idx], gen.rooms[idx + 1])
			if row < rows - 1 and randf() < 0.6:
				_connect_pair(gen, gen.rooms[idx], gen.rooms[idx + cols])
	# 全体の到達性を保証: 外周ループに最低2部屋は接続する
	# 左上(0)は必ず外周へ、右下(7)も必ず外周へ
	var rc0: Vector2i = _center_of(gen.rooms[0])
	_v_tunnel(gen, rc0.y, ly1, rc0.x)
	var rc7: Vector2i = _center_of(gen.rooms[7])
	_v_tunnel(gen, rc7.y, ly2, rc7.x)
	return {"name": "8部屋", "allow_shop": true, "force_mh": false, "mh_room_idx": -1}

# ═══════════════════════════════════════════════════════════
# 3. 12部屋（3×4 グリッド＋#型通路）
# ═══════════════════════════════════════════════════════════
static func pattern_12rooms(gen: DungeonGenerator) -> Dictionary:
	_grid_rooms(gen, 4, 3, 5, 8, 5, 8)
	# 隣接する全ペアを接続
	for row in 3:
		for col in 4:
			var idx: int = row * 4 + col
			if col < 3:
				_connect_pair(gen, gen.rooms[idx], gen.rooms[idx + 1])
			if row < 2:
				_connect_pair(gen, gen.rooms[idx], gen.rooms[idx + 4])
	return {"name": "12部屋", "allow_shop": true, "force_mh": false, "mh_room_idx": -1}

# ═══════════════════════════════════════════════════════════
# 4. 4部屋（四隅、MH確定、店なし）
# ═══════════════════════════════════════════════════════════
static func pattern_4rooms(gen: DungeonGenerator) -> Dictionary:
	var rw := randi_range(6, 12)
	var rh := randi_range(6, 10)
	# 左上, 右上, 左下, 右下
	var positions := [
		Vector2i(MARGIN, MARGIN),
		Vector2i(W - rw - MARGIN, MARGIN),
		Vector2i(MARGIN, H - rh - MARGIN),
		Vector2i(W - rw - MARGIN, H - rh - MARGIN),
	]
	for p: Vector2i in positions:
		var room := Rect2i(p.x, p.y, rw, rh)
		_carve(gen, room)
		gen.rooms.append(room)
	# TL↔TR, TL↔BL, TR↔BR, BL↔BR
	_connect_pair(gen, gen.rooms[0], gen.rooms[1])
	_connect_pair(gen, gen.rooms[0], gen.rooms[2])
	_connect_pair(gen, gen.rooms[1], gen.rooms[3])
	_connect_pair(gen, gen.rooms[2], gen.rooms[3])
	var mh_idx: int = randi_range(1, 2)   # プレイヤー開始以外
	return {"name": "4部屋", "allow_shop": false, "force_mh": true, "mh_room_idx": mh_idx}

# ═══════════════════════════════════════════════════════════
# 5. 2部屋（左右、MH確定、店なし）
# ═══════════════════════════════════════════════════════════
static func pattern_2rooms(gen: DungeonGenerator) -> Dictionary:
	var rw := randi_range(10, 18)
	var rh := randi_range(10, 16)
	var gap := randi_range(6, 14)
	var left_x := MARGIN
	var right_x := left_x + rw + gap
	if right_x + rw >= W - MARGIN:
		right_x = W - rw - MARGIN
	var cy := (H - rh) / 2
	var left_room := Rect2i(left_x, cy, rw, rh)
	var right_room := Rect2i(right_x, cy, rw, rh)
	_carve(gen, left_room)
	_carve(gen, right_room)
	gen.rooms.append(left_room)
	gen.rooms.append(right_room)
	_connect_pair(gen, left_room, right_room)
	return {"name": "2部屋", "allow_shop": false, "force_mh": true, "mh_room_idx": 1}

# ═══════════════════════════════════════════════════════════
# 6. たこ足（中央大部屋＋放射状の小部屋）
# ═══════════════════════════════════════════════════════════
static func pattern_octopus(gen: DungeonGenerator) -> Dictionary:
	# 中央の大部屋
	var cw := randi_range(12, 18)
	var ch := randi_range(10, 14)
	var cx := (W - cw) / 2
	var cy := (H - ch) / 2
	var center := Rect2i(cx, cy, cw, ch)
	_carve(gen, center)
	gen.rooms.append(center)
	# 放射状に 4〜6 個の小部屋
	var arm_count := randi_range(4, 6)
	var angles: Array = []
	for _i in arm_count:
		angles.append(randf() * TAU)
	angles.sort()
	for angle: float in angles:
		var dist := randi_range(12, 18)
		var aw := randi_range(5, 8)
		var ah := randi_range(5, 7)
		var ax: int = int(W / 2.0 + cos(angle) * dist) - aw / 2
		var ay: int = int(H / 2.0 + sin(angle) * dist) - ah / 2
		ax = clampi(ax, MARGIN, W - aw - MARGIN)
		ay = clampi(ay, MARGIN, H - ah - MARGIN)
		var arm := Rect2i(ax, ay, aw, ah)
		_carve(gen, arm)
		gen.rooms.append(arm)
		_connect_pair(gen, center, arm)
	# 中央部屋(index 0)には店を置かない → allow_shop=true だが shop_exclude は caller 側で対応
	return {"name": "たこ足", "allow_shop": true, "force_mh": false, "mh_room_idx": -1, "shop_exclude_idx": 0}

# ═══════════════════════════════════════════════════════════
# 7. 連結4部屋（上下左右＋各隣接ペアに2本通路）
# ═══════════════════════════════════════════════════════════
static func pattern_connected4(gen: DungeonGenerator) -> Dictionary:
	var rw := randi_range(8, 14)
	var rh := randi_range(6, 10)
	var hcx: int = W / 2 - rw / 2   # 水平中央
	var vcy: int = H / 2 - rh / 2   # 垂直中央
	# 上, 右, 下, 左
	var rooms_data: Array[Rect2i] = [
		Rect2i(hcx, MARGIN, rw, rh),                    # 上
		Rect2i(W - rw - MARGIN, vcy, rw, rh),           # 右
		Rect2i(hcx, H - rh - MARGIN, rw, rh),           # 下
		Rect2i(MARGIN, vcy, rw, rh),                     # 左
	]
	for r: Rect2i in rooms_data:
		_carve(gen, r)
		gen.rooms.append(r)
	# 隣接ペア（上↔右, 右↔下, 下↔左, 左↔上）に各2本通路
	var pairs := [[0,1],[1,2],[2,3],[3,0]]
	for pair: Array in pairs:
		_connect_pair(gen, gen.rooms[pair[0]], gen.rooms[pair[1]])
		_connect_pair_offset(gen, gen.rooms[pair[0]], gen.rooms[pair[1]], 2)
	return {"name": "連結4部屋", "allow_shop": true, "force_mh": false, "mh_room_idx": -1}

# ═══════════════════════════════════════════════════════════
# 8. 大部屋（MH確定、店なし）
# ═══════════════════════════════════════════════════════════
static func pattern_big_room(gen: DungeonGenerator) -> Dictionary:
	var room := Rect2i(MARGIN, MARGIN, W - MARGIN * 2, H - MARGIN * 2)
	_carve(gen, room)
	gen.rooms.append(room)
	return {"name": "大部屋", "allow_shop": false, "force_mh": true, "mh_room_idx": 0}

# ═══════════════════════════════════════════════════════════
# 9. 中部屋（MH確定、店なし）
# ═══════════════════════════════════════════════════════════
static func pattern_medium_room(gen: DungeonGenerator) -> Dictionary:
	var rw := randi_range(18, 28)
	var rh := randi_range(14, 20)
	var rx := (W - rw) / 2
	var ry := (H - rh) / 2
	var room := Rect2i(rx, ry, rw, rh)
	_carve(gen, room)
	gen.rooms.append(room)
	return {"name": "中部屋", "allow_shop": false, "force_mh": true, "mh_room_idx": 0}

# ═══════════════════════════════════════════════════════════
# 10. 大迷路（部屋なし、店なし、MHなし）
# ═══════════════════════════════════════════════════════════
static func pattern_maze(gen: DungeonGenerator) -> Dictionary:
	# DFS 再帰バックトラッカーで迷路生成（2マスごとのグリッド）
	var gw: int = (W - 2) / 2   # 迷路グリッド幅
	var gh: int = (H - 2) / 2   # 迷路グリッド高さ
	var visited: Dictionary = {}
	var stack: Array = []
	var start := Vector2i(0, 0)
	visited[start] = true
	stack.append(start)
	# マップの対応座標: グリッド(gx,gy) → タイル(1+gx*2, 1+gy*2)
	var to_tile := func(gp: Vector2i) -> Vector2i:
		return Vector2i(1 + gp.x * 2, 1 + gp.y * 2)
	# 開始点を掘る
	var sp: Vector2i = to_tile.call(start)
	gen._set_tile(sp.x, sp.y, DungeonGenerator.TILE_FLOOR)

	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var neighbors: Array = []
		for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nb: Vector2i = cur + d
			if nb.x >= 0 and nb.x < gw and nb.y >= 0 and nb.y < gh and not visited.has(nb):
				neighbors.append(nb)
		if neighbors.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = neighbors[randi() % neighbors.size()]
		visited[next] = true
		# 通路を掘る（間の壁 + 到達先）
		var ct: Vector2i = to_tile.call(cur)
		var nt: Vector2i = to_tile.call(next)
		var wall_x: int = (ct.x + nt.x) / 2
		var wall_y: int = (ct.y + nt.y) / 2
		gen._set_tile(wall_x, wall_y, DungeonGenerator.TILE_FLOOR)
		gen._set_tile(nt.x, nt.y, DungeonGenerator.TILE_FLOOR)
		stack.append(next)

	# 部屋は作らない（rooms は空のまま）。ダミーで start/end の小区画を rooms に登録
	var start_tile: Vector2i = to_tile.call(Vector2i(0, 0))
	var end_tile: Vector2i = to_tile.call(Vector2i(gw - 1, gh - 1))
	gen.rooms.append(Rect2i(start_tile.x, start_tile.y, 1, 1))
	gen.rooms.append(Rect2i(end_tile.x, end_tile.y, 1, 1))
	return {"name": "大迷路", "allow_shop": false, "force_mh": false, "mh_room_idx": -1, "no_mh": true}

# ═══════════════════════════════════════════════════════════
# 11. 一筆書き（出口1〜2の直列部屋チェーン）
# ═══════════════════════════════════════════════════════════
static func pattern_one_stroke(gen: DungeonGenerator) -> Dictionary:
	var room_count := randi_range(6, 10)
	# ランダムな位置に部屋を生成（重なりチェック付き）
	var attempts := room_count * 10
	while gen.rooms.size() < room_count and attempts > 0:
		attempts -= 1
		var rw := randi_range(5, 9)
		var rh := randi_range(5, 7)
		var rx := randi_range(MARGIN, W - rw - MARGIN)
		var ry := randi_range(MARGIN, H - rh - MARGIN)
		var nr := Rect2i(rx, ry, rw, rh)
		var ok := true
		for r: Rect2i in gen.rooms:
			if nr.intersects(Rect2i(r.position - Vector2i(2,2), r.size + Vector2i(4,4))):
				ok = false
				break
		if ok:
			_carve(gen, nr)
			gen.rooms.append(nr)
	# 一筆書き順に接続（各部屋は前後とのみ繋がる → 出口1〜2）
	# 最寄り順にソートして線形チェーンにする
	if gen.rooms.size() > 1:
		var ordered: Array = [gen.rooms[0]]
		var remaining: Array = gen.rooms.slice(1)
		while not remaining.is_empty():
			var last: Rect2i = ordered[ordered.size() - 1]
			var best_idx := 0
			var best_dist := 999999
			for i in remaining.size():
				var d: int = _center_of(last).distance_squared_to(_center_of(remaining[i]))
				if d < best_dist:
					best_dist = d
					best_idx = i
			ordered.append(remaining[best_idx])
			remaining.remove_at(best_idx)
		gen.rooms = ordered
	_connect_chain(gen)
	return {"name": "一筆書き", "allow_shop": true, "force_mh": false, "mh_room_idx": -1}

# ═══════════════════════════════════════════════════════════
# ── 共通ヘルパ ─────────────────────────────────────────────
# ═══════════════════════════════════════════════════════════

## 部屋を map に彫り込む
static func _carve(gen: DungeonGenerator, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			gen._set_tile(x, y, DungeonGenerator.TILE_FLOOR)

## rooms 配列を順番に接続（線形チェーン）
static func _connect_chain(gen: DungeonGenerator) -> void:
	for i in range(1, gen.rooms.size()):
		_connect_pair(gen, gen.rooms[i - 1], gen.rooms[i])

## 2部屋を L 字通路で接続
static func _connect_pair(gen: DungeonGenerator, a: Rect2i, b: Rect2i) -> void:
	var ac: Vector2i = _center_of(a)
	var bc: Vector2i = _center_of(b)
	if randi() % 2 == 0:
		_h_tunnel(gen, ac.x, bc.x, ac.y)
		_v_tunnel(gen, ac.y, bc.y, bc.x)
	else:
		_v_tunnel(gen, ac.y, bc.y, ac.x)
		_h_tunnel(gen, ac.x, bc.x, bc.y)

## オフセット付き接続（2本目の通路用）
static func _connect_pair_offset(gen: DungeonGenerator, a: Rect2i, b: Rect2i, offset: int) -> void:
	var ac: Vector2i = _center_of(a) + Vector2i(offset, offset)
	var bc: Vector2i = _center_of(b) + Vector2i(-offset, -offset)
	ac.x = clampi(ac.x, a.position.x, a.end.x - 1)
	ac.y = clampi(ac.y, a.position.y, a.end.y - 1)
	bc.x = clampi(bc.x, b.position.x, b.end.x - 1)
	bc.y = clampi(bc.y, b.position.y, b.end.y - 1)
	if randi() % 2 == 0:
		_h_tunnel(gen, ac.x, bc.x, ac.y)
		_v_tunnel(gen, ac.y, bc.y, bc.x)
	else:
		_v_tunnel(gen, ac.y, bc.y, ac.x)
		_h_tunnel(gen, ac.x, bc.x, bc.y)

## グリッド状に部屋を配置
static func _grid_rooms(gen: DungeonGenerator, cols: int, rows: int,
		min_rw: int, max_rw: int, min_rh: int, max_rh: int) -> void:
	var cell_w: float = float(W - MARGIN * 2) / cols
	var cell_h: float = float(H - MARGIN * 2) / rows
	for row in rows:
		for col in cols:
			var rw: int = randi_range(min_rw, min(max_rw, int(cell_w) - 3))
			var rh: int = randi_range(min_rh, min(max_rh, int(cell_h) - 3))
			var rx: int = MARGIN + int(col * cell_w) + int((cell_w - rw) / 2)
			var ry: int = MARGIN + int(row * cell_h) + int((cell_h - rh) / 2)
			rx = clampi(rx, MARGIN, W - rw - MARGIN)
			ry = clampi(ry, MARGIN, H - rh - MARGIN)
			var room := Rect2i(rx, ry, rw, rh)
			_carve(gen, room)
			gen.rooms.append(room)

static func _center_of(r: Rect2i) -> Vector2i:
	return Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)

static func _h_tunnel(gen: DungeonGenerator, x1: int, x2: int, y: int) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 1):
		gen._set_tile(x, y, DungeonGenerator.TILE_FLOOR)

static func _v_tunnel(gen: DungeonGenerator, y1: int, y2: int, x: int) -> void:
	for y in range(mini(y1, y2), maxi(y1, y2) + 1):
		gen._set_tile(x, y, DungeonGenerator.TILE_FLOOR)
