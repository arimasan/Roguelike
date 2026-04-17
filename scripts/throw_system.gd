class_name ThrowSystem
extends RefCounted

## 投擲（/撃つ）の方向入力・軌道計算・アニメーション・命中／落下処理をまとめる。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態（_aim_dir / _aim_item_idx / _aim_is_shoot / _aim_node）はすべて game.gd が保持。
##   このファイルは「ロジックとノード生成」のみを担当し、状態は game 経由で読み書きする。
## * 第1引数に必ず game.gd インスタンス（Node）を受け取る。
## * UI状態遷移（game_state 変更）は最小限に留め、投擲フローで必要なもの
##   （"throw_aim" / "throw_anim" / "playing" への復帰）のみここで触る。
##
## ── ここに書くべきもの ───────────────────────────────────
## * 照準UI（矢印ノードの生成・更新・破棄）
## * 方向キー入力処理（8方向）
## * 軌道計算・命中判定（7/8）・アニメーション
## * 命中時ダメージ、落下時のアイテム設置・ワナ発動
##
## ── ここに書かないべきもの ─────────────────────────────
## * アイテム使用効果（ItemEffects.gd へ）
## * インベントリ操作UI（inventory_ui.gd 予定）
## * ワナの通常発動（プレイヤーが踏んだ時）→ game.gd の _check_trap
##
## 呼び出し例:
##   ThrowSystem.start_aim(self, false)   # "throw" アクションから
##   ThrowSystem.handle_aim_input(self, kc)

# ─── 方向文字 ──────────────────────────────────────────────
static func arrow_char(dir: Vector2i) -> String:
	if dir == Vector2i( 0, -1): return "↑"
	if dir == Vector2i( 0,  1): return "↓"
	if dir == Vector2i(-1,  0): return "←"
	if dir == Vector2i( 1,  0): return "→"
	if dir == Vector2i(-1, -1): return "↖"
	if dir == Vector2i( 1, -1): return "↗"
	if dir == Vector2i(-1,  1): return "↙"
	if dir == Vector2i( 1,  1): return "↘"
	return "→"

# ─── 照準開始 ──────────────────────────────────────────────
static func start_aim(game: Node, is_shoot: bool) -> void:
	if game.p_inventory.is_empty():
		return
	game._aim_item_idx  = game.inv_cursor
	game._aim_is_shoot  = is_shoot
	game._aim_from_floor = false
	var facing: Vector2i = game.p_facing
	if facing == Vector2i.ZERO:
		facing = Vector2i(1, 0)
	game._aim_dir = facing
	spawn_arrow(game)
	game.game_state = "throw_aim"
	game._refresh_hud()

## 足元のアイテムを対象に照準開始（インベントリ不要）
static func start_aim_from_floor(game: Node, is_shoot: bool = false) -> void:
	if game._item_at(game.p_grid) == null:
		return
	game._aim_item_idx  = -1
	game._aim_is_shoot  = is_shoot
	game._aim_from_floor = true
	var facing: Vector2i = game.p_facing
	if facing == Vector2i.ZERO:
		facing = Vector2i(1, 0)
	game._aim_dir = facing
	spawn_arrow(game)
	game.game_state = "throw_aim"
	game._refresh_hud()

# ─── 照準矢印ノードの管理 ──────────────────────────────────
static func spawn_arrow(game: Node) -> void:
	if game._aim_node != null and is_instance_valid(game._aim_node):
		game._aim_node.queue_free()
	var dir: Vector2i = game._aim_dir
	var node: Node2D = game._make_tile_node(arrow_char(dir),
		Color(0, 0, 0, 0), Color(1.0, 0.95, 0.3), 22)
	node.z_index = 20
	game._entity_layer.add_child(node)
	game._aim_node = node
	refresh_arrow(game)

static func refresh_arrow(game: Node) -> void:
	var node = game._aim_node
	if node == null or not is_instance_valid(node):
		return
	var p_grid: Vector2i = game.p_grid
	var dir: Vector2i = game._aim_dir
	var tgt: Vector2i = p_grid + dir
	node.call("set_grid", tgt.x, tgt.y)
	node.call("setup", arrow_char(dir),
		Color(0, 0, 0, 0), Color(1.0, 0.95, 0.3), 22)

static func clear_arrow(game: Node) -> void:
	var node = game._aim_node
	if node != null and is_instance_valid(node):
		node.queue_free()
	game._aim_node = null

# ─── 方向入力 ──────────────────────────────────────────────
static func handle_aim_input(game: Node, kc: int) -> void:
	var up_k:    int = int(game.key_bindings.get("move_up",    KEY_UP))
	var down_k:  int = int(game.key_bindings.get("move_down",  KEY_DOWN))
	var left_k:  int = int(game.key_bindings.get("move_left",  KEY_LEFT))
	var right_k: int = int(game.key_bindings.get("move_right", KEY_RIGHT))
	var up:    bool = (kc == up_k)    or (kc == KEY_K)
	var down:  bool = (kc == down_k)  or (kc == KEY_J)
	var left:  bool = (kc == left_k)  or (kc == KEY_H)
	var right: bool = (kc == right_k) or (kc == KEY_L)
	if up or down or left or right:
		var up_h:    bool = Input.is_key_pressed(up_k)
		var down_h:  bool = Input.is_key_pressed(down_k)
		var left_h:  bool = Input.is_key_pressed(left_k)
		var right_h: bool = Input.is_key_pressed(right_k)
		var fx: int = 0
		var fy: int = 0
		if right: fx = 1
		elif left: fx = -1
		elif right_h: fx = 1
		elif left_h: fx = -1
		if down: fy = 1
		elif up: fy = -1
		elif down_h: fy = 1
		elif up_h: fy = -1
		if fx != 0 or fy != 0:
			game._aim_dir = Vector2i(fx, fy)
			refresh_arrow(game)
		return
	match kc:
		KEY_ESCAPE:
			clear_arrow(game)
			game.game_state = "inv_action"
			game._refresh_hud()
		KEY_ENTER, KEY_Z, KEY_KP_ENTER:
			confirm_throw(game)

# ─── 投擲確定：軌道算出＋アニメ開始 ────────────────────────
static func confirm_throw(game: Node) -> void:
	var from_floor: bool = bool(game._aim_from_floor)
	var item: Dictionary
	var floor_fi: Dictionary = {}
	if from_floor:
		var fi = game._item_at(game.p_grid)
		if fi == null:
			clear_arrow(game)
			game.game_state = "playing"
			game._aim_from_floor = false
			game._refresh_hud()
			return
		floor_fi = fi
		item = fi["item"]
	else:
		var aim_idx: int = int(game._aim_item_idx)
		if aim_idx < 0 or aim_idx >= game.p_inventory.size():
			clear_arrow(game)
			game.game_state = "playing"
			game._refresh_hud()
			return
		item = game.p_inventory[aim_idx]
		# 装備中は投げられない（外してから）
		if game.p_weapon.get("_iid", -1) == item.get("_iid", -2) \
				or game.p_shield.get("_iid", -1) == item.get("_iid", -2) \
				or game.p_ring.get("_iid",   -1) == item.get("_iid", -2):
			game.add_message("装備中のアイテムは投げられない。")
			clear_arrow(game)
			game.game_state = "inventory"
			game._refresh_hud()
			return
	# 図鑑登録（投擲した時点で発見扱い）
	var item_id: String = item.get("id", "")
	if Bestiary.discover_item(item_id):
		game.add_message("図鑑に %s を登録した。" % item.get("name", "?"))
	var dir: Vector2i = game._aim_dir
	clear_arrow(game)
	game.p_facing = dir
	game.add_message("%s を投げた。" % item.get("name", "?"))
	# 軌道計算
	var p_grid: Vector2i = game.p_grid
	var tiles: Array = []
	var hit_enemy: Dictionary = {}
	var cur: Vector2i = p_grid
	for _i in 10:
		cur = cur + dir
		if cur.x < 0 or cur.x >= DungeonGenerator.MAP_W \
				or cur.y < 0 or cur.y >= DungeonGenerator.MAP_H:
			break
		if game.generator.get_tile(cur.x, cur.y) == DungeonGenerator.TILE_WALL:
			break
		tiles.append(cur)
		var enemy = game._enemy_at(cur)
		if enemy != null:
			if randf() < 7.0 / 8.0:
				hit_enemy = enemy
				break
			# ミス: この敵の足元に落下
			break
	# 投擲元からアイテムを除去
	if from_floor:
		floor_fi["node"].queue_free()
		(game.floor_items as Array).erase(floor_fi)
		game._aim_from_floor = false
	else:
		var aim_idx: int = int(game._aim_item_idx)
		game.p_inventory.remove_at(aim_idx)
		game.inv_cursor = min(int(game.inv_cursor), max(0, game.p_inventory.size() - 1))
	game._aim_item_idx = -1
	# 投擲ノード作成
	var proj: Node2D = game._make_tile_node(ItemData.type_symbol(item.get("type", 0)),
		Color(0, 0, 0, 0), ItemData.type_color(item.get("type", 0)), 18)
	proj.z_index = 10
	game._entity_layer.add_child(proj)
	proj.call("set_grid", p_grid.x, p_grid.y)
	var icon_path: String = Assets.item_type_sprite(item.get("type", -1))
	if not icon_path.is_empty():
		proj.call("set_sprite", icon_path)
	# アニメーション
	game.game_state = "throw_anim"
	var tile_size: int = game.TILE_SIZE
	var tween: Tween = game.create_tween()
	for tpos in tiles:
		var tp: Vector2i = tpos
		var world_pos := Vector2(tp.x * tile_size + tile_size / 2.0,
								 tp.y * tile_size + tile_size / 2.0)
		tween.tween_property(proj, "position", world_pos, 0.04)
	tween.tween_callback(func(): finish_throw(game, proj, item, tiles, hit_enemy))

# ─── アニメ終了コールバック ───────────────────────────────
static func finish_throw(game: Node, proj: Node2D, item: Dictionary,
		tiles: Array, hit_enemy: Dictionary) -> void:
	if is_instance_valid(proj):
		proj.queue_free()
	var land_pos: Vector2i = game.p_grid
	if not tiles.is_empty():
		land_pos = tiles[tiles.size() - 1]
	if not hit_enemy.is_empty():
		apply_hit(game, item, hit_enemy, land_pos)
	else:
		land_item(game, item, land_pos)
	game.game_state = "playing"
	game._refresh_hud()
	game._end_player_turn()

# ─── 命中時：アイテム種別に応じた効果を敵に適用 ───────────
static func apply_hit(game: Node, item: Dictionary, enemy: Dictionary, pos: Vector2i) -> void:
	# 合成虫: ダメージの代わりにアイテムを飲み込む
	if enemy["data"].get("synthesis", false):
		_absorb_into_synth(game, enemy, item, pos)
		return
	var t: int = item.get("type", -1)
	var name: String = item.get("name", "?")
	var target_name: String = enemy["data"].get("name", "敵")
	# 命中メッセージ＋ノードのフラッシュは共通
	game.add_message("%s が %s に当たった！" % [name, target_name])
	enemy["node"].call("flash", Color(1.0, 0.5, 0.0))

	match t:
		ItemData.TYPE_WEAPON:
			_hit_damage(game, enemy, item.get("atk", 1) + randi_range(3, 6))
		ItemData.TYPE_SHIELD:
			_hit_damage(game, enemy, max(3, item.get("def", 0)) + randi_range(1, 3))
		ItemData.TYPE_RING:
			_hit_damage(game, enemy, 1)
		ItemData.TYPE_SCROLL:
			_hit_damage(game, enemy, 1)
		ItemData.TYPE_FOOD:
			_hit_damage(game, enemy, 1)
		ItemData.TYPE_STAFF:
			_apply_staff_effect_to_enemy(game, enemy, item)
		ItemData.TYPE_POTION:
			_apply_potion_effect_to_enemy(game, enemy, item)
		ItemData.TYPE_POT:
			_hit_damage(game, enemy, 2)
		_:
			_hit_damage(game, enemy, 2)

	# 敵が既に倒れていた場合、land_item はスキップ
	if enemy["hp"] <= 0:
		# land_item は kill_enemy 内で敵ノードが解放されている
		pass

	# 非消耗品（武器・盾・腕輪）は敵の足元 or 近隣に落下、消耗品は消滅
	var keep: bool = t == ItemData.TYPE_WEAPON \
			or t == ItemData.TYPE_SHIELD \
			or t == ItemData.TYPE_RING
	if keep:
		land_item(game, item, pos)

## 命中時のダメージ処理: ダメージ数字表示＋HP減＋死亡判定
static func _hit_damage(game: Node, enemy: Dictionary, dmg: int) -> void:
	dmg = int(dmg * SkillTree.throw_damage_mult(game))
	enemy["hp"] -= dmg
	game._show_damage_number(enemy["grid_pos"] as Vector2i, str(dmg), Color(1.0, 0.8, 0.3))
	game.add_message("%d ダメージ！" % dmg)
	if enemy["hp"] <= 0:
		Combat.kill_enemy(game, enemy)

## 杖を敵にぶつけた時: 杖の振った効果を単体対象に適用
static func _apply_staff_effect_to_enemy(game: Node, enemy: Dictionary, item: Dictionary) -> void:
	var effect: String = item.get("effect", "")
	var name: String = enemy["data"].get("name", "敵")
	match effect:
		"fire":
			_hit_damage(game, enemy, randi_range(20, 35))
			game.add_message("%s が炎に包まれた！" % name)
		"thunder":
			_hit_damage(game, enemy, randi_range(10, 18))
			game.add_message("%s に雷が落ちた！" % name)
		"freeze":
			enemy["asleep"]       = true
			enemy["asleep_turns"] = 3
			game._refresh_enemy_status_visual(enemy)
			game.add_message("%s が凍りついた！" % name)
		"knockback":
			ItemEffects.knockback_enemy(game, enemy, 5)
			game.add_message("%s を吹き飛ばした！" % name)
		"seal":
			enemy["asleep"]       = true
			enemy["asleep_turns"] = 5
			game._refresh_enemy_status_visual(enemy)
			game.add_message("%s を封印した！" % name)
		"magic":
			enemy["hp"] = max(1, int(enemy["hp"]) / 2)
			game.add_message("%s のHPが半分になった！" % name)
		_:
			_hit_damage(game, enemy, 3)

## 薬を敵にぶつけた時: 飲んだ時の効果を敵に適用
static func _apply_potion_effect_to_enemy(game: Node, enemy: Dictionary, item: Dictionary) -> void:
	var name: String = enemy["data"].get("name", "敵")
	# 回復量
	var heal: int = int(item.get("heal", 0))
	if heal > 0:
		var max_hp: int = int(enemy["data"].get("hp", enemy["hp"]))
		enemy["hp"] = min(int(enemy["hp"]) + heal, max_hp)
		game.add_message("%s のHPが %d 回復した。" % [name, heal])
	# 攻撃力上昇
	var atk_up: int = int(item.get("atk_up", 0))
	if atk_up > 0:
		enemy["data"]["atk"] = int(enemy["data"].get("atk", 0)) + atk_up
		game.add_message("%s の攻撃力が %d 上がった！" % [name, atk_up])
	# 特殊効果
	match item.get("effect", ""):
		"antidote":
			enemy["poisoned"]        = 0
			enemy["asleep"]          = false
			enemy["asleep_turns"]    = 0
			enemy["slow_turns"]      = 0
			enemy["confused_turns"]  = 0
			enemy["paralyzed_turns"] = 0
			game._refresh_enemy_status_visual(enemy)
			game.add_message("%s の状態異常が治った。" % name)
		"detox":
			if int(enemy.get("poisoned", 0)) > 0:
				enemy["poisoned"] = 0
				game._refresh_enemy_status_visual(enemy)
				game.add_message("%s の毒が治った。" % name)
		"awaken":
			if enemy.get("asleep", false):
				enemy["asleep"]       = false
				enemy["asleep_turns"] = 0
				game._refresh_enemy_status_visual(enemy)
				game.add_message("%s の眠気が吹き飛んだ！" % name)
		"charm":
			ItemEffects.apply_status_to_enemy(game, enemy, "interest", 6)

# ─── 落下：ワナ発動＋アイテム設置 ─────────────────────────
static func land_item(game: Node, item: Dictionary, pos: Vector2i) -> void:
	game.add_message("%s は床に落ちた。" % item.get("name", "?"))
	# ワナ発動チェック
	for i in game.traps.size():
		if (game.traps[i]["grid_pos"] as Vector2i) == pos:
			trigger_trap_on_tile(game, i, pos)
			break
	# 配置先が空いていなければ近隣へ
	var place_pos: Vector2i = pos
	var occupied := false
	for fi in game.floor_items:
		if (fi["grid_pos"] as Vector2i) == pos:
			occupied = true
			break
	if occupied:
		var near: Vector2i = game._find_free_drop_pos(pos)
		if near != Vector2i(-1, -1):
			place_pos = near
		else:
			return
	game._place_floor_item(item, place_pos)

# ─── 落下時のワナ発動（対象ありのワナは敵に適用） ────────
static func trigger_trap_on_tile(game: Node, idx: int, pos: Vector2i) -> void:
	var trap: Dictionary = game.traps[idx]
	trap["triggered"] = true
	trap["node"].visible = game.explored.has(pos)
	trap["node"].call("flash", Color(1.0, 0.5, 0.0))
	game._play_se(TrapData.trap_se(trap["type"]))
	var trap_name: String = TrapData.trap_name(trap["type"])
	var enemy = game._enemy_at(pos)
	match trap["type"]:
		"damage":
			if enemy != null:
				var dmg: int = randi_range(5, 12)
				enemy["hp"] -= dmg
				game.add_message("%s が %s にヒット！%d ダメージ！" % [trap_name, enemy["data"].get("name","敵"), dmg])
				if enemy["hp"] <= 0:
					Combat.kill_enemy(game, enemy)
			else:
				game.add_message("%s が発動した。" % trap_name)
		"poison":
			if enemy != null:
				ItemEffects.apply_status_to_enemy(game, enemy, "poison", 10)
				game.add_message("%s により %s は毒状態！" % [trap_name, enemy["data"].get("name","敵")])
		"sleep":
			if enemy != null:
				ItemEffects.apply_status_to_enemy(game, enemy, "sleep", 5)
				game.add_message("%s により %s は眠った！" % [trap_name, enemy["data"].get("name","敵")])
		"slow":
			if enemy != null:
				ItemEffects.apply_status_to_enemy(game, enemy, "slow", 8)
				game.add_message("%s により %s は鈍足！" % [trap_name, enemy["data"].get("name","敵")])
		"confuse":
			if enemy != null:
				ItemEffects.apply_status_to_enemy(game, enemy, "confuse", 5)
				game.add_message("%s により %s は混乱！" % [trap_name, enemy["data"].get("name","敵")])
		"blind", "hunger", "alarm", "drop_item":
			# プレイヤー向けの効果は敵にはない／対象なし
			game.add_message("%s が発動した。" % trap_name)
		"warp":
			if enemy != null:
				var np: Vector2i = game.generator.random_floor_pos()
				enemy["grid_pos"] = np
				enemy["node"].call("set_grid", np.x, np.y)
				game.add_message("%s により %s は飛ばされた！" % [trap_name, enemy["data"].get("name","敵")])
	# 壊れ判定
	if randf() < TrapData.break_chance(trap["type"]):
		trap["node"].queue_free()
		game.traps.remove_at(idx)

# ─── 合成虫：アイテム吸収＋合成 ────────────────────────────
## 合成虫にアイテムを投げた場合の処理
static func _absorb_into_synth(game: Node, enemy: Dictionary, item: Dictionary, pos: Vector2i) -> void:
	var enemy_name: String = enemy["data"].get("name", "敵")
	var item_name: String = SealSystem.display_name(item)
	if not enemy.has("absorbed"):
		enemy["absorbed"] = []
	# 同タイプのアイテムが既に吸収されていれば合成
	var absorbed: Array = enemy["absorbed"]
	for i in absorbed.size():
		var existing: Dictionary = absorbed[i]
		if int(existing.get("type", -1)) == int(item.get("type", -1)):
			var it: int = int(item.get("type", -1))
			if it == ItemData.TYPE_WEAPON or it == ItemData.TYPE_SHIELD:
				# existing をベースとして item を合成
				var msgs: Array = SealSystem.synthesize(existing, item)
				for msg: String in msgs:
					game.add_message(msg)
				game.add_message("%s が %s を吐き出した！" % [enemy_name, SealSystem.display_name(existing)])
				# 合成結果を足元に落とす
				absorbed.remove_at(i)
				land_item(game, existing, pos)
				game._play_se("general_item")
				return
	# 合成対象なし: 飲み込む
	absorbed.append(item)
	enemy["node"].call("flash", Color(0.4, 0.85, 0.55))
	game.add_message("%s は %s を飲み込んだ！" % [enemy_name, item_name])
	game._play_se("general_item")
