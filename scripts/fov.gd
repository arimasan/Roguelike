class_name Fov
extends RefCounted

## 視野計算（Field Of View）とエンティティ可視性同期。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態（fov_visible / explored / fov_mode / p_grid / 各エンティティ配列）は
##   すべて game.gd が所有。このファイルは計算と書き込みのみ。
## * 第1引数に必ず game.gd インスタンス（Node）を受け取る。
## * fov_visible と explored は Dictionary<Vector2i, true>（集合として使用）。
##
## ── ここに書くべきもの ───────────────────────────────────
## * 視野モード別の FOV 計算（半径／部屋flood／画面全体）
## * 視線判定（has_los）
## * エンティティノードの visible 同期（sync_entity_visibility）
##
## ── ここに書かないべきもの ─────────────────────────────
## * マップタイル自体の描画（map_drawer.gd）
## * HUDの表示更新（hud.gd）
## * カメラ位置・ズーム（game.gd）

# FOV モード定数（game.gd 側と対応）
const MODE_CLASSIC := 0   # 通路=1マス／部屋=全体照明
const MODE_SCREEN  := 1   # 画面内全タイル表示

# ─── FOV 更新のエントリポイント ────────────────────────────
## モード・盲目・探知指輪・部屋内／通路 を判定して適切な計算を呼ぶ
static func update(game: Node) -> void:
	game.fov_visible.clear()
	if int(game.fov_mode) == MODE_SCREEN:
		_fov_fill_screen(game)
	elif int(game.p_blind_turns) > 0:
		_fov_radius(game, 1)   # 盲目: 周囲1マスのみ
	elif game.p_ring.get("effect", "") == "detection":
		_fov_radius(game, 15)
	elif _is_in_room(game):
		_fov_flood_room(game)   # 部屋内: 部屋全体を一括照明
	else:
		var base_r: int = 1 + SkillTree.fov_radius_bonus(game)
		_fov_radius(game, base_r)   # 通路: 周囲1マス＋千里眼ボーナス
	game._map_drawer.call("queue_redraw")

## プレイヤーがいずれかの部屋Rect内にいるか判定
static func _is_in_room(game: Node) -> bool:
	if game.generator == null:
		return false
	var p_grid: Vector2i = game.p_grid
	for room: Rect2i in game.generator.rooms:
		if room.has_point(p_grid):
			return true
	return false

## 半径 r の正方形（チェビシェフ距離）＋LOS で視野を計算
static func _fov_radius(game: Node, r: int) -> void:
	var p_grid: Vector2i = game.p_grid
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var tx: int = p_grid.x + dx
			var ty: int = p_grid.y + dy
			if tx < 0 or tx >= DungeonGenerator.MAP_W \
					or ty < 0 or ty >= DungeonGenerator.MAP_H:
				continue
			if has_los(game, p_grid.x, p_grid.y, tx, ty):
				var vp := Vector2i(tx, ty)
				game.fov_visible[vp] = true
				game.explored[vp]    = true

## 現在いる部屋全体（＋周囲1マスの壁）を照らす
static func _fov_flood_room(game: Node) -> void:
	var p_grid: Vector2i = game.p_grid
	for room: Rect2i in game.generator.rooms:
		if not room.has_point(p_grid):
			continue
		for y in range(room.position.y - 1, room.end.y + 1):
			for x in range(room.position.x - 1, room.end.x + 1):
				if x < 0 or x >= DungeonGenerator.MAP_W \
						or y < 0 or y >= DungeonGenerator.MAP_H:
					continue
				var vp := Vector2i(x, y)
				game.fov_visible[vp] = true
				game.explored[vp]    = true
		return   # 1部屋だけ処理

## カメラズームに基づき画面内の全タイルを視野に入れる（②モード用）
static func _fov_fill_screen(game: Node) -> void:
	var vp_size: Vector2 = game.get_viewport().get_visible_rect().size
	var zoom: float = game._camera.zoom.x if is_instance_valid(game._camera) else 1.0
	var tile_size: int = int(game.TILE_SIZE)
	var half_w: int = int(ceil(vp_size.x / (tile_size * zoom * 2.0))) + 1
	var half_h: int = int(ceil(vp_size.y / (tile_size * zoom * 2.0))) + 1
	var p_grid: Vector2i = game.p_grid
	for dy in range(-half_h, half_h + 1):
		for dx in range(-half_w, half_w + 1):
			var tx: int = p_grid.x + dx
			var ty: int = p_grid.y + dy
			if tx < 0 or tx >= DungeonGenerator.MAP_W \
					or ty < 0 or ty >= DungeonGenerator.MAP_H:
				continue
			var vp := Vector2i(tx, ty)
			game.fov_visible[vp] = true
			game.explored[vp]    = true

## Bresenham LOS: (x0,y0) から (x1,y1) への直線上に壁がないか判定
static func has_los(game: Node, x0: int, y0: int, x1: int, y1: int) -> bool:
	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy
	var cx: int  = x0
	var cy: int  = y0
	while true:
		if cx == x1 and cy == y1:
			return true
		if not (cx == x0 and cy == y0):
			if game.generator.get_tile(cx, cy) == DungeonGenerator.TILE_WALL:
				return false
		var e2: int = err * 2
		if e2 > -dy:
			err -= dy
			cx  += sx
		if e2 < dx:
			err += dx
			cy  += sy
	return true

# ─── エンティティ可視性同期 ───────────────────────────────
static func sync_entity_visibility(game: Node) -> void:
	# 敵：視界外は非表示
	for enemy in game.enemies:
		enemy["node"].visible = game.fov_visible.has(enemy["grid_pos"] as Vector2i)
	# アイテム：探索済みなら表示
	for fi in game.floor_items:
		fi["node"].visible = game.explored.has(fi["grid_pos"] as Vector2i)
	# ゴールド：探索済みなら表示
	for pile in game.gold_piles:
		pile["node"].visible = game.explored.has(pile["grid_pos"] as Vector2i)
	# 店員・店アイテム：探索済みなら表示
	if not (game._shopkeeper as Dictionary).is_empty():
		game._shopkeeper["node"].visible = game.explored.has(game._shopkeeper["grid_pos"] as Vector2i)
	for si in game.shop_items:
		si["node"].visible = game.explored.has(si["grid_pos"] as Vector2i)
	# ワナ：発動済み／よくみえの腕輪／罠感知スキルなら可視化
	var trap_sense: bool = game.p_ring.get("effect", "") == "trap_sense"
	var skill_sense: bool = SkillTree.has(game, "explore_3")
	for trap in game.traps:
		if trap["triggered"] or trap_sense:
			trap["node"].visible = game.explored.has(trap["grid_pos"] as Vector2i)
		elif skill_sense and game.fov_visible.has(trap["grid_pos"] as Vector2i):
			trap["node"].visible = true
		else:
			trap["node"].visible = false
