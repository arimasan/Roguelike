class_name EnemyAI
extends RefCounted

## 敵の生成・行動・モンスターハウス処理をまとめる。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態（enemies / _monster_house_triggered など）はすべて game.gd が所有。
##   このファイルは「生成とAIロジック」のみを担当し、状態は game 経由で読み書きする。
## * 第1引数に必ず game.gd インスタンス（Node）を受け取る。
## * 状態異常の付与は ItemEffects.apply_status_to_enemy 経由を推奨
##   （ここでは睡眠などの直接操作のみ許容）。
##
## ── ここに書くべきもの ───────────────────────────────────
## * フロア初期敵配置（spawn_for_floor）
## * モンスターハウス配置・発動（setup_monster_house / trigger_monster_house）
## * 敵ターン処理（run_turns → run_turn → attack/chase/random_walk/move/can_walk）
## * ワンダリング／召喚（spawn_wandering / spawn_one_near_player）
##
## ── ここに書かないべきもの ─────────────────────────────
## * 状態異常ビジュアル更新（game._refresh_enemy_status_visual）
## * プレイヤーのダメージ処理（Combat.apply_damage_to_player）
## * 敵撃破時のドロップ等（Combat.kill_enemy）

# ─── フロア初期スポーン ─────────────────────────────────────
static func spawn_for_floor(game: Node) -> void:
	var floor_num: int = int(game.current_floor)
	var pool: Array = EnemyData.for_floor(floor_num)
	if pool.is_empty():
		return
	var occupied: Array = [game.p_grid]
	for spawn_pos: Vector2i in game.generator.enemy_spawns:
		if spawn_pos in occupied:
			continue
		var data: Dictionary = pool[randi() % pool.size()].duplicate(true)
		var node: Node2D = game._make_tile_node(data["symbol"], data["color"])
		node.z_index = 1
		game._entity_layer.add_child(node)
		node.call("set_grid", spawn_pos.x, spawn_pos.y)
		node.call("set_sprite", Assets.enemy_sprite(data.get("id", "")))
		game.enemies.append(_make_enemy_dict(data, spawn_pos, node, false, false))
		occupied.append(spawn_pos)

# ─── モンスターハウス ──────────────────────────────────────
static func setup_monster_house(game: Node) -> void:
	var floor_num: int = int(game.current_floor)
	var pool: Array = EnemyData.for_floor(floor_num)
	if pool.is_empty():
		return
	var occupied: Array = [game.p_grid]
	# 敵を全員 asleep=true で配置
	for spawn_pos: Vector2i in game.generator.monster_house_enemy_spawns:
		if spawn_pos in occupied:
			continue
		var data: Dictionary = pool[randi() % pool.size()].duplicate(true)
		var node: Node2D = game._make_tile_node(data["symbol"], data["color"])
		node.z_index = 1
		game._entity_layer.add_child(node)
		node.call("set_grid", spawn_pos.x, spawn_pos.y)
		node.call("set_sprite", Assets.enemy_sprite(data.get("id", "")))
		var edict: Dictionary = _make_enemy_dict(data, spawn_pos, node, true, false)
		edict["mh_asleep"] = true   # MH発動前の眠り。隣接で確定解除される
		game.enemies.append(edict)
		node.call("set_status", "眠", Color(0.3, 0.8, 1.0))
		occupied.append(spawn_pos)
	# アイテム
	for item_pos: Vector2i in game.generator.monster_house_item_spawns:
		if item_pos in occupied:
			continue
		var item: Dictionary = ItemData.random_item(floor_num)
		game._place_floor_item(item, item_pos)
		occupied.append(item_pos)
	# ワナ（不可視ノードとして配置）
	for trap_pos: Vector2i in game.generator.monster_house_trap_pos:
		if trap_pos in occupied:
			continue
		var td: Dictionary = TrapData.random_trap()
		game._place_trap(td["id"], trap_pos)
		occupied.append(trap_pos)

## モンスターハウス発動：全員覚醒（BGMは呼び出し元の _update_area_bgm が切り替える）
static func trigger_monster_house(game: Node) -> void:
	game._monster_house_triggered = true
	game.add_message("モンスターハウスだ！！")
	var mh_room: Rect2i = game.generator.monster_house_room
	for enemy: Dictionary in game.enemies:
		if mh_room.has_point(enemy["grid_pos"] as Vector2i):
			enemy["asleep"]  = false
			enemy["alerted"] = true
			game._refresh_enemy_status_visual(enemy)

# ─── 敵ターン処理 ──────────────────────────────────────────
static func run_turns(game: Node) -> void:
	for enemy in (game.enemies as Array).duplicate():   # duplicate でイテレート中の削除を安全に
		if not is_instance_valid(enemy.get("node")):
			continue
		run_turn(game, enemy)

static func run_turn(game: Node, enemy: Dictionary) -> void:
	# 麻痺カウントダウン（完全行動不能）
	if enemy.get("paralyzed_turns", 0) > 0:
		enemy["paralyzed_turns"] -= 1
		enemy["node"].call("flash", Color(1.0, 1.0, 0.2))
		if enemy["paralyzed_turns"] == 0:
			game._refresh_enemy_status_visual(enemy)
		return

	# 睡眠カウントダウン
	if enemy.get("asleep_turns", 0) > 0:
		enemy["asleep_turns"] -= 1
		if enemy["asleep_turns"] <= 0:
			enemy["asleep"] = false
			game._refresh_enemy_status_visual(enemy)
	if enemy.get("asleep", false):
		return

	# 毒DoT：毎ターン2ダメージ
	if enemy.get("poisoned", 0) > 0:
		enemy["poisoned"] -= 1
		enemy["hp"] -= 2
		enemy["node"].call("flash", Color(0.3, 1.0, 0.2))
		game.add_message("%s は毒で 2 ダメージ！" % enemy["data"]["name"])
		if enemy["hp"] <= 0:
			Combat.kill_enemy(game, enemy)
			return
		if enemy["poisoned"] == 0:
			game._refresh_enemy_status_visual(enemy)

	# 鈍足：2ターンに1回スキップ
	if enemy.get("slow_turns", 0) > 0:
		enemy["slow_turns"] -= 1
		var skip: bool = enemy.get("slow_skip", false)
		enemy["slow_skip"] = not skip
		if enemy["slow_turns"] == 0:
			enemy["slow_skip"] = false
			game._refresh_enemy_status_visual(enemy)
		if skip:
			enemy["node"].call("flash", Color(0.6, 0.6, 0.6))
			return

	# 混乱カウントダウン（移動はランダム化、後続で判定）
	if enemy.get("confused_turns", 0) > 0:
		enemy["confused_turns"] -= 1
		if enemy["confused_turns"] == 0:
			game._refresh_enemy_status_visual(enemy)

	# 興味カウントダウン（仲間化チャンスの残り）
	if enemy.get("interested_turns", 0) > 0:
		enemy["interested_turns"] -= 1
		if enemy["interested_turns"] == 0:
			game._refresh_enemy_status_visual(enemy)

	# regen: HPを1回復
	if enemy["data"].get("behavior", "") == "regen":
		enemy["hp"] = min(enemy["hp"] + 1, enemy["data"]["hp"])

	# 混乱中はランダム行動のみ
	if enemy.get("confused_turns", 0) > 0:
		enemy["node"].call("flash", Color(0.8, 0.3, 1.0))
		random_walk(game, enemy)
		return

	# スキルCTのデクリメント
	EnemySkills.tick_cooldowns(enemy)

	var ep: Vector2i = enemy["grid_pos"] as Vector2i
	var p_grid: Vector2i = game.p_grid
	var in_sight: bool = game.fov_visible.has(ep)

	if in_sight or enemy.get("alerted", false):
		enemy["alerted"] = true
		# スキル発動抽選（成功したら通常行動スキップ）
		if EnemySkills.try_activate(game, enemy):
			return
		# 隣接した仲間がいれば優先攻撃
		var adj_comp = _find_adjacent_companion(game, ep)
		# 隣接していれば（プレイヤー or 仲間）攻撃
		if ep.distance_squared_to(p_grid) <= 2:
			attack(game, enemy)
		elif adj_comp != null:
			attack_companion(game, enemy, adj_comp)
		else:
			# 追いかけ移動
			chase(game, enemy)
			# fast行動：もう1回（鈍足中は無効）
			if enemy["data"].get("behavior", "") == "fast" and enemy.get("slow_turns", 0) == 0:
				if ep.distance_squared_to(p_grid) <= 2:
					attack(game, enemy)
				else:
					chase(game, enemy)
	else:
		random_walk(game, enemy)

static func attack(game: Node, enemy: Dictionary) -> void:
	var dmg: int = max(1, int(enemy["data"].get("atk", 1)) - Combat.calc_def(game))
	Combat.apply_damage_to_player(game, dmg, enemy["data"]["name"])
	# 盾の呪印: 5% で攻撃した敵を金縛り
	if SealSystem.has_curse_def_seal(game.p_shield) and int(game.p_hp) > 0 and randf() < 0.05:
		ItemEffects.apply_status_to_enemy(game, enemy, "paralyze", 3)
		game.add_message("盾の呪いが発動！")

## 隣接する仲間を返す（なければ null）
static func _find_adjacent_companion(game: Node, ep: Vector2i) -> Variant:
	for d: Vector2i in _DIRS_8:
		var c = CompanionAI.at(game, ep + d)
		if c != null:
			return c
	return null

static func attack_companion(game: Node, enemy: Dictionary, comp: Dictionary) -> void:
	var dmg: int = max(1, int(enemy["data"].get("atk", 1)) - int(comp["data"].get("def", 0)))
	CompanionAI.damage(game, comp, dmg, enemy["data"].get("name", "敵"))

const _DIRS_8: Array = [
	Vector2i( 1, 0), Vector2i(-1, 0), Vector2i( 0, 1), Vector2i( 0,-1),
	Vector2i( 1, 1), Vector2i( 1,-1), Vector2i(-1, 1), Vector2i(-1,-1),
]

static func chase(game: Node, enemy: Dictionary) -> void:
	var ep: Vector2i = enemy["grid_pos"] as Vector2i
	var p_grid: Vector2i = game.p_grid
	var best_dir: Vector2i = Vector2i.ZERO
	var best_dist: int = ep.distance_squared_to(p_grid)

	var dirs: Array = _DIRS_8.duplicate()
	dirs.shuffle()

	var is_ghost: bool = enemy["data"].get("behavior", "") == "ghost"
	for dir in dirs:
		var np: Vector2i = ep + dir
		if can_walk(game, np, enemy, is_ghost):
			var d: int = np.distance_squared_to(p_grid)
			if d < best_dist:
				best_dist = d
				best_dir  = dir

	if best_dir != Vector2i.ZERO:
		move(enemy, best_dir)

static func random_walk(game: Node, enemy: Dictionary) -> void:
	if randi() % 3 != 0:
		return
	var dirs: Array = _DIRS_8.duplicate()
	dirs.shuffle()
	var is_ghost: bool = enemy["data"].get("behavior", "") == "ghost"
	for dir in dirs:
		var np: Vector2i = (enemy["grid_pos"] as Vector2i) + Vector2i(dir)
		if can_walk(game, np, enemy, is_ghost):
			move(enemy, dir)
			return

static func move(enemy: Dictionary, dir: Vector2i) -> void:
	enemy["grid_pos"] = (enemy["grid_pos"] as Vector2i) + dir
	var gp: Vector2i = enemy["grid_pos"] as Vector2i
	enemy["node"].call("set_grid", gp.x, gp.y)

static func can_walk(game: Node, pos: Vector2i, self_enemy: Dictionary, is_ghost: bool) -> bool:
	if pos.x < 0 or pos.x >= DungeonGenerator.MAP_W \
			or pos.y < 0 or pos.y >= DungeonGenerator.MAP_H:
		return false
	if not is_ghost and not game.generator.is_walkable(pos.x, pos.y):
		return false
	if pos == game.p_grid:
		return false
	for other in game.enemies:
		if other != self_enemy and (other["grid_pos"] as Vector2i) == pos:
			return false
	return true

# ─── ターン進行による追加スポーン ──────────────────────────
## 視界外のランダム位置に1体湧かせる（通常は 50 ターンに1度呼ばれる）
static func spawn_wandering(game: Node) -> void:
	var floor_num: int = int(game.current_floor)
	var pool: Array = EnemyData.for_floor(floor_num)
	if pool.is_empty():
		return
	var occupied: Array = [game.p_grid]
	for e in game.enemies:
		occupied.append(e["grid_pos"] as Vector2i)
	for _attempt in 10:
		var pos: Vector2i = game.generator.random_floor_pos()
		if pos in occupied:
			continue
		if game.fov_visible.has(pos):
			continue
		var data: Dictionary = pool[randi() % pool.size()].duplicate(true)
		var node: Node2D = game._make_tile_node(data["symbol"], data["color"])
		node.z_index = 1
		game._entity_layer.add_child(node)
		node.call("set_grid", pos.x, pos.y)
		node.call("set_sprite", Assets.enemy_sprite(data.get("id", "")))
		game.enemies.append(_make_enemy_dict(data, pos, node, false, false))
		return   # 1体沸いたら終了

## 「モンスターの本」等で即座に1体出現（警戒状態）
static func spawn_one_near_player(game: Node) -> void:
	var floor_num: int = int(game.current_floor)
	var pool: Array = EnemyData.for_floor(floor_num)
	if pool.is_empty():
		return
	var pos: Vector2i = game.generator.random_floor_pos()
	var data: Dictionary = pool[randi() % pool.size()].duplicate(true)
	var node: Node2D = game._make_tile_node(data["symbol"], data["color"])
	node.z_index = 1
	game._entity_layer.add_child(node)
	node.call("set_grid", pos.x, pos.y)
	game.enemies.append(_make_enemy_dict(data, pos, node, false, true))

# ─── 内部ヘルパ ────────────────────────────────────────────
## enemies 配列に入れる Dictionary を生成（状態異常フィールドをゼロ初期化）
static func _make_enemy_dict(data: Dictionary, pos: Vector2i, node: Node2D,
		asleep: bool, alerted: bool) -> Dictionary:
	return {
		"data":            data,
		"hp":              int(data.get("hp", 1)),
		"grid_pos":        pos,
		"node":            node,
		"asleep":          asleep,
		"alerted":         alerted,
		"asleep_turns":    0,
		"poisoned":        0,
		"sealed":          false,
		"slow_turns":      0,
		"slow_skip":       false,
		"confused_turns":  0,
		"paralyzed_turns": 0,
		"interested_turns":0,
		"skill_cooldowns": {},
	}
