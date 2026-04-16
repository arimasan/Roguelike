class_name CompanionAI
extends RefCounted

## 仲間（companion）の行動 AI と関連処理。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態（companions / 各 dict / 移動・体力）はすべて game.gd が所有。
## * 仲間ターンはプレイヤーターン直後・敵ターン直前に処理する（run_turns）。
## * 各仲間は以下の優先順で行動：
##     1. 隣接敵がいれば攻撃
##     2. 視界内に敵がいれば最寄りへ追跡
##     3. プレイヤーから 4マス以上離れていれば追従
##     4. それ以外は待機
## * プレイヤーは仲間マスに移動できない（位置固定）。
## * 敵 AI からも、隣接していれば攻撃される対象になる（後で対応）。
##
## ── ここに書くべきもの ───────────────────────────────────
## * 仲間スポーン（add）、撃破処理（kill）
## * 仲間の毎ターン行動（run_turns）
## * 仲間が攻撃に使う関数

const _DIRS_8: Array = [
	Vector2i( 1, 0), Vector2i(-1, 0), Vector2i( 0, 1), Vector2i( 0,-1),
	Vector2i( 1, 1), Vector2i( 1,-1), Vector2i(-1, 1), Vector2i(-1,-1),
]

# ─── 追加 / 撃破 ───────────────────────────────────────────
## 敵 dict をベースに仲間化。pos は隣接マスを別途算出する。
## 仲間が満員ならスポーンせず false を返す。
static func add_from_enemy(game: Node, enemy: Dictionary, pos: Vector2i) -> bool:
	if (game.companions as Array).size() >= int(game.MAX_COMPANIONS):
		game.add_message("仲間が多すぎる…")
		return false
	var data: Dictionary = (enemy["data"] as Dictionary).duplicate(true)
	var node: Node2D = game._make_tile_node(data["symbol"], data["color"])
	node.z_index = 1
	game._entity_layer.add_child(node)
	node.call("set_grid", pos.x, pos.y)
	node.call("set_sprite", Assets.enemy_sprite(data.get("id", "")))
	# 仲間用の青い縁取りで識別性アップ
	node.call("set_status", "仲", Color(0.4, 0.7, 1.0))
	game.companions.append({
		"data":      data,
		"hp":        int(data.get("hp", 1)),
		"hp_max":    int(data.get("hp", 1)),
		"grid_pos":  pos,
		"node":      node,
		"skill_cooldowns": {},
	})
	return true

## 仲間死亡処理
static func kill(game: Node, comp: Dictionary) -> void:
	game.add_message("× %s は力尽きた…" % comp["data"].get("name", "仲間"))
	if is_instance_valid(comp.get("node")):
		comp["node"].queue_free()
	game.companions.erase(comp)

## 指定座標に仲間がいれば返す
static func at(game: Node, pos: Vector2i) -> Variant:
	for c in game.companions:
		if (c["grid_pos"] as Vector2i) == pos:
			return c
	return null

# ─── ターン処理 ───────────────────────────────────────────
static func run_turns(game: Node) -> void:
	for comp in (game.companions as Array).duplicate():
		if not is_instance_valid(comp.get("node")):
			continue
		_run_turn(game, comp)

static func _run_turn(game: Node, comp: Dictionary) -> void:
	var cp: Vector2i = comp["grid_pos"] as Vector2i
	# 1. 隣接敵がいれば攻撃
	var target: Variant = _find_adjacent_enemy(game, cp)
	if target != null:
		_attack_enemy(game, comp, target)
		return
	# 2. 視界内に敵がいれば最寄りへ
	var nearest: Variant = _find_nearest_visible_enemy(game, cp)
	if nearest != null:
		var nep: Vector2i = nearest["grid_pos"] as Vector2i
		var dir: Vector2i = _step_toward(game, comp, cp, nep)
		if dir != Vector2i.ZERO:
			_move(comp, dir)
		return
	# 3. プレイヤーから離れすぎていれば追従
	var pp: Vector2i = game.p_grid
	if cp.distance_squared_to(pp) > 4:
		var dir2: Vector2i = _step_toward(game, comp, cp, pp)
		if dir2 != Vector2i.ZERO:
			_move(comp, dir2)

static func _find_adjacent_enemy(game: Node, cp: Vector2i) -> Variant:
	for d: Vector2i in _DIRS_8:
		var np: Vector2i = cp + d
		var e = game._enemy_at(np)
		if e != null:
			return e
	return null

static func _find_nearest_visible_enemy(game: Node, cp: Vector2i) -> Variant:
	var best: Variant = null
	var best_dist: int = 999999
	for e in game.enemies:
		var ep: Vector2i = e["grid_pos"] as Vector2i
		if not (game.fov_visible as Dictionary).has(ep):
			continue
		var d: int = ep.distance_squared_to(cp)
		if d < best_dist:
			best_dist = d
			best = e
	return best

static func _step_toward(game: Node, comp: Dictionary, cp: Vector2i, target: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i.ZERO
	var best_d: int = cp.distance_squared_to(target)
	var dirs: Array = _DIRS_8.duplicate()
	dirs.shuffle()
	for d: Vector2i in dirs:
		var np: Vector2i = cp + d
		if not _can_walk(game, np, comp):
			continue
		var nd: int = np.distance_squared_to(target)
		if nd < best_d:
			best_d = nd
			best = d
	return best

static func _can_walk(game: Node, pos: Vector2i, self_comp: Dictionary) -> bool:
	if pos.x < 0 or pos.x >= DungeonGenerator.MAP_W \
			or pos.y < 0 or pos.y >= DungeonGenerator.MAP_H:
		return false
	if not game.generator.is_walkable(pos.x, pos.y):
		return false
	if pos == game.p_grid:
		return false
	for e in game.enemies:
		if (e["grid_pos"] as Vector2i) == pos:
			return false
	for c in game.companions:
		if c == self_comp:
			continue
		if (c["grid_pos"] as Vector2i) == pos:
			return false
	return true

static func _move(comp: Dictionary, dir: Vector2i) -> void:
	comp["grid_pos"] = (comp["grid_pos"] as Vector2i) + dir
	var gp: Vector2i = comp["grid_pos"] as Vector2i
	comp["node"].call("set_grid", gp.x, gp.y)

static func _attack_enemy(game: Node, comp: Dictionary, enemy: Dictionary) -> void:
	var atk: int = int(comp["data"].get("atk", 1))
	var def_e: int = int(enemy["data"].get("def", 0))
	var dmg: int = max(1, atk - def_e)
	enemy["hp"] = int(enemy["hp"]) - dmg
	enemy["node"].call("flash", Color(1.0, 0.4, 0.4))
	game.add_message("仲間 %s の攻撃！ %s に %d ダメージ。" % [
		comp["data"].get("name", "仲間"),
		enemy["data"].get("name", "敵"),
		dmg,
	])
	if enemy["hp"] <= 0:
		Combat.kill_enemy(game, enemy, true)   # 仲間が倒した（経験値なし）

# ─── 仲間が攻撃を受ける（敵 AI 用 API） ─────────────────
static func damage(game: Node, comp: Dictionary, dmg: int, source: String) -> void:
	comp["hp"] = max(0, int(comp["hp"]) - dmg)
	comp["node"].call("flash", Color(1.0, 0.3, 0.3))
	game.add_message("%s から %s へ %d ダメージ！" % [
		source, comp["data"].get("name", "仲間"), dmg
	])
	if comp["hp"] <= 0:
		kill(game, comp)
