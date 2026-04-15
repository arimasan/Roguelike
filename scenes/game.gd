extends Node2D
## ローグライクゲーム メインコントローラー

# ─── 定数 ─────────────────────────────────────────────────
const TILE_SIZE     := 32
const MAX_FLOOR     := 30
const MAX_INVENTORY := 20
const FOV_RADIUS    := 7
const HUNGER_RATE   := 15   # 何ターンごとに満腹度-1か

# ─── ゲーム状態 ───────────────────────────────────────────
var game_state: String = "playing"   # playing / inventory / dead / victory

# ─── フロア・マップ ───────────────────────────────────────
var current_floor: int = 1
var turn_count:    int = 0
var generator:     DungeonGenerator = null
var explored:    Dictionary = {}   # Vector2i → true
var fov_visible: Dictionary = {}   # Vector2i → true  ※CanvasItem.visible と衝突を避けるため改名

# ─── プレイヤーステータス ─────────────────────────────────
var p_hp:       int = 30
var p_hp_max:   int = 30
var p_atk_base: int = 5
var p_def_base: int = 2
var p_level:    int = 1
var p_exp:      int = 0
var p_exp_next: int = 10
var p_fullness: int = 100
var p_grid:     Vector2i = Vector2i.ZERO
var p_weapon:   Dictionary = {}
var p_shield:   Dictionary = {}
var p_ring:     Dictionary = {}
var p_inventory: Array = []

# ─── エンティティ ─────────────────────────────────────────
# enemies: Array of { "data": dict, "hp": int, "grid_pos": V2i,
#                     "node": Node2D, "asleep": bool, "alerted": bool }
var enemies:     Array = []
# floor_items: Array of { "item": dict, "grid_pos": V2i, "node": Node2D }
var floor_items: Array = []

# ─── メッセージ ───────────────────────────────────────────
var messages: Array = []

# ─── インベントリカーソル ─────────────────────────────────
var inv_cursor: int = 0

# ─── ノード参照 ───────────────────────────────────────────
var _map_drawer    = null   # map_drawer.gd スクリプト付き Node2D
var _entity_layer: Node2D  = null
var _player_node   = null   # tile_node.gd スクリプト付き Node2D
var _camera:       Camera2D = null
var _hud           = null   # hud.gd スクリプト付き Control

# ─── 初期化 ───────────────────────────────────────────────
func _ready() -> void:
	_build_scene_nodes()
	_start_new_floor()

func _build_scene_nodes() -> void:
	# マップ描画レイヤー
	_map_drawer = Node2D.new()
	_map_drawer.set_script(load("res://scripts/map_drawer.gd"))
	add_child(_map_drawer)

	# エンティティレイヤー（マップより手前）
	_entity_layer = Node2D.new()
	add_child(_entity_layer)

	# カメラ
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed   = 12.0
	add_child(_camera)

	# CanvasLayer → HUD
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_hud = Control.new()
	_hud.set_script(load("res://scripts/hud.gd"))
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_hud)
	_hud.set("game_ref", self)   # 型なし変数への安全なプロパティ代入

# ─── フロア生成 ───────────────────────────────────────────
func _start_new_floor() -> void:
	# 旧エンティティ削除
	for ch in _entity_layer.get_children():
		ch.queue_free()
	enemies.clear()
	floor_items.clear()
	explored.clear()
	fov_visible.clear()

	# ダンジョン生成
	generator = DungeonGenerator.new()
	generator.generate(current_floor)

	# マップ描画セットアップ（カスタムメソッドは call() で呼ぶ）
	_map_drawer.call("setup", generator, fov_visible, explored)

	# プレイヤーノード生成
	_player_node = _make_tile_node("@", Color(0.10, 0.28, 0.80))
	_entity_layer.add_child(_player_node)
	p_grid = generator.player_start
	_player_node.call("set_grid", p_grid.x, p_grid.y)
	_player_node.call("set_sprite", Assets.PLAYER)

	# 敵・アイテム配置
	_spawn_enemies()
	_spawn_items()

	# FOV更新・カメラ・HUD
	_update_fov()
	_sync_entity_visibility()
	_update_camera()
	_refresh_hud()

	add_message("B%dF に降りた。" % current_floor)

# ─── 敵スポーン ───────────────────────────────────────────
func _spawn_enemies() -> void:
	var pool := EnemyData.for_floor(current_floor)
	if pool.is_empty():
		return
	var occupied: Array = [p_grid]
	for spawn_pos: Vector2i in generator.enemy_spawns:
		if spawn_pos in occupied:
			continue
		var data: Dictionary = pool[randi() % pool.size()].duplicate(true)
		var node := _make_tile_node(data["symbol"], data["color"])
		_entity_layer.add_child(node)
		node.call("set_grid", spawn_pos.x, spawn_pos.y)
		node.call("set_sprite", Assets.enemy_sprite(data.get("id", "")))
		enemies.append({
			"data":     data,
			"hp":       data["hp"],
			"grid_pos": spawn_pos,
			"node":     node,
			"asleep":   false,
			"alerted":  false,
		})
		occupied.append(spawn_pos)

# ─── アイテムスポーン ─────────────────────────────────────
func _spawn_items() -> void:
	var occupied: Array = [p_grid]
	for enemy in enemies:
		occupied.append(enemy["grid_pos"])
	for spawn_pos: Vector2i in generator.item_spawns:
		if spawn_pos in occupied:
			continue
		var item: Dictionary = ItemData.random_item(current_floor)
		_place_floor_item(item, spawn_pos)
		occupied.append(spawn_pos)

func _place_floor_item(item: Dictionary, pos: Vector2i) -> void:
	var sym := ItemData.type_symbol(item.get("type", 0))
	var col := ItemData.type_color(item.get("type", 0))
	var node := _make_tile_node(sym, Color(0.12, 0.12, 0.12), col, 18)
	_entity_layer.add_child(node)
	node.call("set_grid", pos.x, pos.y)
	node.call("set_sprite", Assets.item_type_sprite(item.get("type", 0)))
	floor_items.append({"item": item, "grid_pos": pos, "node": node})

# ─── 入力処理 ─────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var kev := event as InputEventKey

	match game_state:
		"playing":
			# '>' は unicode で判定（Shift+. はkeycodeがKEY_PERIODになるため）
			if kev.unicode == 62:   # '>'
				_try_descend()
				return
			_handle_play_input(kev.keycode)
		"inventory":
			_handle_inv_input(kev.keycode)
		"dead", "victory":
			if kev.keycode == KEY_R:
				get_tree().reload_current_scene()

func _diagonal_held() -> bool:
	return Input.is_key_pressed(KEY_KP_7) or Input.is_key_pressed(KEY_KP_9) \
		or Input.is_key_pressed(KEY_KP_1) or Input.is_key_pressed(KEY_KP_3)

func _handle_play_input(kc: int) -> void:
	# 斜めキーを押しながらの場合、斜め移動以外は受け付けない
	if _diagonal_held() and kc not in [KEY_KP_7, KEY_KP_9, KEY_KP_1, KEY_KP_3]:
		return
	match kc:
		KEY_LEFT,  KEY_H, KEY_KP_4: _try_player_move(Vector2i(-1,  0))
		KEY_RIGHT, KEY_L, KEY_KP_6: _try_player_move(Vector2i( 1,  0))
		KEY_UP,    KEY_K, KEY_KP_8: _try_player_move(Vector2i( 0, -1))
		KEY_DOWN,  KEY_J, KEY_KP_2: _try_player_move(Vector2i( 0,  1))
		KEY_KP_7:                   _try_player_move(Vector2i(-1, -1))
		KEY_KP_9:                   _try_player_move(Vector2i( 1, -1))
		KEY_KP_1:                   _try_player_move(Vector2i(-1,  1))
		KEY_KP_3:                   _try_player_move(Vector2i( 1,  1))
		KEY_PERIOD, KEY_KP_5:       _player_wait()
		KEY_I:                      _open_inventory()
		KEY_G:                      _try_pickup()

func _handle_inv_input(kc: int) -> void:
	match kc:
		KEY_ESCAPE, KEY_I:
			game_state = "playing"
			_refresh_hud()
		KEY_UP, KEY_K:
			inv_cursor = max(0, inv_cursor - 1)
			_refresh_hud()
		KEY_DOWN, KEY_J:
			inv_cursor = min(p_inventory.size() - 1, inv_cursor + 1)
			_refresh_hud()
		KEY_ENTER, KEY_Z, KEY_KP_ENTER:
			_use_selected_item()
		KEY_D:
			_drop_selected_item()

# ─── プレイヤー行動 ───────────────────────────────────────
func _try_player_move(dir: Vector2i) -> void:
	var new_pos: Vector2i = p_grid + dir
	# 敵がいれば攻撃
	var target_enemy = _enemy_at(new_pos)
	if target_enemy != null:
		_player_attack(target_enemy)
		_end_player_turn()
		return
	# 壁チェック
	if not generator.is_walkable(new_pos.x, new_pos.y):
		return
	# 移動
	p_grid = new_pos
	_player_node.call("set_grid", p_grid.x, p_grid.y)
	# アイテム自動拾い
	_auto_pickup()
	# 階段チェック
	if generator.get_tile(p_grid.x, p_grid.y) == DungeonGenerator.TILE_STAIRS:
		add_message("階段を見つけた！ [>] で降りる")
	_end_player_turn()

func _player_wait() -> void:
	add_message("その場で待機した。")
	_end_player_turn()

func _try_descend() -> void:
	if generator.get_tile(p_grid.x, p_grid.y) != DungeonGenerator.TILE_STAIRS:
		add_message("ここに階段はない。")
		return
	if current_floor >= MAX_FLOOR:
		_trigger_victory()
		return
	current_floor += 1
	_start_new_floor()

func _try_pickup() -> void:
	var fi = _item_at(p_grid)
	if fi == null:
		add_message("ここにアイテムはない。")
		return
	_pickup_item(fi)
	_refresh_hud()

func _auto_pickup() -> void:
	var fi = _item_at(p_grid)
	if fi != null:
		_pickup_item(fi)

func _pickup_item(fi: Dictionary) -> void:
	if p_inventory.size() >= MAX_INVENTORY:
		add_message("荷物がいっぱいで拾えない！")
		return
	var item: Dictionary = fi["item"]
	p_inventory.append(item)
	fi["node"].queue_free()
	floor_items.erase(fi)
	add_message("%s を拾った。" % item.get("name", "?"))

func _end_player_turn() -> void:
	# 満腹度
	turn_count += 1
	if turn_count % HUNGER_RATE == 0:
		p_fullness = max(0, p_fullness - 1)
		if p_fullness == 0:
			_apply_damage_to_player(3, "空腹")
		elif p_fullness <= 10:
			add_message("お腹が減って苦しい…")
	# 回復指輪
	if p_ring.get("effect", "") == "regen" and turn_count % 5 == 0:
		p_hp = min(p_hp_max, p_hp + 1)
	_enemy_turns()
	_update_fov()
	_sync_entity_visibility()
	_update_camera()
	_refresh_hud()

# ─── 戦闘：プレイヤー → 敵 ───────────────────────────────
func _player_attack(enemy: Dictionary) -> void:
	var dmg: int = max(1, calc_atk() - int(enemy["data"].get("def", 0)))
	# 炎の剣ボーナス
	if p_weapon.get("effect", "") == "burn":
		dmg += randi_range(1, 4)
	enemy["hp"] -= dmg
	enemy["alerted"] = true
	add_message("%s に %d ダメージ！" % [enemy["data"]["name"], dmg])
	if enemy["hp"] <= 0:
		_kill_enemy(enemy)

func _kill_enemy(enemy: Dictionary) -> void:
	add_message("%s を倒した！" % enemy["data"]["name"])
	var gained_exp: int = enemy["data"].get("exp", 0)
	if p_ring.get("effect", "") == "exp_boost":
		gained_exp = int(gained_exp * 1.5)
	p_exp += gained_exp
	add_message("経験値 %d 獲得。" % gained_exp)
	enemy["node"].queue_free()
	enemies.erase(enemy)
	_check_level_up()

func _check_level_up() -> void:
	while p_exp >= p_exp_next:
		p_exp     -= p_exp_next
		p_level   += 1
		p_exp_next = int(p_exp_next * 1.8)
		p_hp_max  += 8
		p_hp       = min(p_hp + 8, p_hp_max)
		p_atk_base += 1
		p_def_base += 1
		add_message("レベルアップ！ LV %d になった！" % p_level)

# ─── 戦闘：敵 → プレイヤー ───────────────────────────────
func _apply_damage_to_player(dmg: int, source: String) -> void:
	p_hp -= dmg
	if source != "":
		add_message("%s から %d ダメージ！" % [source, dmg])
	if p_hp <= 0:
		p_hp = 0
		_trigger_game_over()

# ─── 敵ターン ─────────────────────────────────────────────
func _enemy_turns() -> void:
	for enemy in enemies.duplicate():   # duplicate でイテレート中の削除を安全に
		if not is_instance_valid(enemy.get("node")):
			continue
		_single_enemy_turn(enemy)

func _single_enemy_turn(enemy: Dictionary) -> void:
	if enemy.get("asleep", false):
		return

	# regen: HPを1回復
	if enemy["data"].get("behavior", "") == "regen":
		enemy["hp"] = min(enemy["hp"] + 1, enemy["data"]["hp"])

	var ep: Vector2i = enemy["grid_pos"] as Vector2i
	var in_sight: bool = fov_visible.has(ep)

	if in_sight or enemy.get("alerted", false):
		enemy["alerted"] = true
		# 隣接していれば攻撃
		if ep.distance_squared_to(p_grid) <= 2:
			_enemy_attack(enemy)
		else:
			# 追いかけ移動
			_enemy_chase(enemy)
			# fast行動：もう1回
			if enemy["data"].get("behavior", "") == "fast":
				if ep.distance_squared_to(p_grid) <= 2:
					_enemy_attack(enemy)
				else:
					_enemy_chase(enemy)
	else:
		_enemy_random_walk(enemy)

func _enemy_attack(enemy: Dictionary) -> void:
	var dmg: int = max(1, int(enemy["data"].get("atk", 1)) - calc_def())
	_apply_damage_to_player(dmg, enemy["data"]["name"])

func _enemy_chase(enemy: Dictionary) -> void:
	var ep: Vector2i = enemy["grid_pos"] as Vector2i
	var best_dir: Vector2i = Vector2i.ZERO
	var best_dist: int = ep.distance_squared_to(p_grid)

	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	dirs.shuffle()

	var is_ghost: bool = enemy["data"].get("behavior", "") == "ghost"
	for dir in dirs:
		var np: Vector2i = ep + dir
		if _enemy_can_walk(np, enemy, is_ghost):
			var d := np.distance_squared_to(p_grid)
			if d < best_dist:
				best_dist = d
				best_dir  = dir

	if best_dir != Vector2i.ZERO:
		_move_enemy(enemy, best_dir)

func _enemy_random_walk(enemy: Dictionary) -> void:
	if randi() % 3 != 0:
		return
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	dirs.shuffle()
	var is_ghost: bool = enemy["data"].get("behavior", "") == "ghost"
	for dir in dirs:
		var np: Vector2i = (enemy["grid_pos"] as Vector2i) + Vector2i(dir)
		if _enemy_can_walk(np, enemy, is_ghost):
			_move_enemy(enemy, dir)
			return

func _move_enemy(enemy: Dictionary, dir: Vector2i) -> void:
	enemy["grid_pos"] = (enemy["grid_pos"] as Vector2i) + dir
	var gp: Vector2i = enemy["grid_pos"] as Vector2i
	enemy["node"].call("set_grid", gp.x, gp.y)

func _enemy_can_walk(pos: Vector2i, self_enemy: Dictionary, is_ghost: bool) -> bool:
	if pos.x < 0 or pos.x >= DungeonGenerator.MAP_W \
			or pos.y < 0 or pos.y >= DungeonGenerator.MAP_H:
		return false
	if not is_ghost and not generator.is_walkable(pos.x, pos.y):
		return false
	if pos == p_grid:
		return false
	for other in enemies:
		if other != self_enemy and (other["grid_pos"] as Vector2i) == pos:
			return false
	return true

# ─── インベントリ操作 ─────────────────────────────────────
func _open_inventory() -> void:
	if p_inventory.is_empty():
		add_message("荷物は空だ。")
		return
	inv_cursor = clamp(inv_cursor, 0, p_inventory.size() - 1)
	game_state = "inventory"
	_refresh_hud()

func _use_selected_item() -> void:
	if p_inventory.is_empty():
		return
	inv_cursor = clamp(inv_cursor, 0, p_inventory.size() - 1)
	var item: Dictionary = p_inventory[inv_cursor]
	var consumed = _apply_item(item)
	if consumed:
		p_inventory.remove_at(inv_cursor)
		inv_cursor = min(inv_cursor, p_inventory.size() - 1)
	if p_inventory.is_empty():
		game_state = "playing"
	_refresh_hud()
	_end_player_turn()

func _apply_item(item: Dictionary) -> bool:
	var t: int = item.get("type", -1)
	match t:
		ItemData.TYPE_WEAPON:
			if p_weapon.get("id","") == item.get("id",""):
				p_weapon = {}
				add_message("%s を外した。" % item.get("name","?"))
			else:
				if item.get("cursed", false):
					add_message("呪われた剣を装備した！外せない…")
				p_weapon = item
				add_message("%s を装備した。" % item.get("name","?"))
			return false   # インベントリに残す

		ItemData.TYPE_SHIELD:
			if p_shield.get("id","") == item.get("id",""):
				p_shield = {}
				add_message("%s を外した。" % item.get("name","?"))
			else:
				p_shield = item
				add_message("%s を装備した。" % item.get("name","?"))
			return false

		ItemData.TYPE_RING:
			if p_ring.get("id","") == item.get("id",""):
				p_ring = {}
				add_message("%s を外した。" % item.get("name","?"))
			else:
				p_ring = item
				add_message("%s を装備した。" % item.get("name","?"))
			return false

		ItemData.TYPE_FOOD:
			var fullness_gain: int = item.get("fullness", 0)
			var heal: int          = item.get("heal", 0)
			if fullness_gain > 0:
				p_fullness = min(100, p_fullness + fullness_gain)
				add_message("%s を食べた。満腹度が回復した。" % item.get("name","?"))
			elif fullness_gain < 0:
				p_fullness = max(0, p_fullness + fullness_gain)
				add_message("腐った食料を食べてしまった！")
			if heal > 0:
				p_hp = min(p_hp_max, p_hp + heal)
				add_message("HP が %d 回復した。" % heal)
			var atk_up: int = item.get("atk_up", 0)
			if atk_up > 0:
				p_atk_base += atk_up
				add_message("力が %d 上がった！" % atk_up)
			return true

		ItemData.TYPE_SCROLL:
			_apply_scroll(item)
			return true

		ItemData.TYPE_POT:
			_apply_pot(item)
			var uses: int = item.get("uses", 1) - 1
			if uses <= 0:
				return true
			item["uses"] = uses
			return false

	return true

func _apply_scroll(item: Dictionary) -> void:
	var effect: String = item.get("effect", "")
	add_message("巻物を読んだ！（%s）" % item.get("name","?"))
	match effect:
		"identify":
			add_message("すべてのアイテムを識別した。（効果なし）")
		"warp":
			p_grid = generator.random_floor_pos()
			_player_node.call("set_grid", p_grid.x, p_grid.y)
			add_message("転移した！")
		"explosion":
			add_message("爆発が起きた！")
			for enemy in enemies.duplicate():
				var dist: int = (enemy["grid_pos"] as Vector2i).distance_squared_to(p_grid)
				if dist <= 9:
					var dmg := randi_range(15, 25)
					enemy["hp"] -= dmg
					add_message("%s に %d ダメージ！" % [enemy["data"]["name"], dmg])
					if enemy["hp"] <= 0:
						_kill_enemy(enemy)
			_apply_damage_to_player(randi_range(3, 8), "爆発の巻物")
		"uncurse":
			if p_weapon.get("cursed", false):
				p_weapon["cursed"] = false
				add_message("剣の呪いが解けた！")
			else:
				add_message("呪いは見つからなかった。")
		"sleep":
			for enemy in enemies:
				if fov_visible.has(enemy["grid_pos"] as Vector2i):
					enemy["asleep"] = true
			add_message("周囲の敵が眠りについた！")
		"map":
			# 全フロアを探索済みにする
			for y in DungeonGenerator.MAP_H:
				for x in DungeonGenerator.MAP_W:
					explored[Vector2i(x, y)] = true
			add_message("フロア全体が明らかになった！")
			_map_drawer.call("queue_redraw")
		"monster":
			_spawn_one_enemy_near_player()
			add_message("モンスターが現れた！")

func _spawn_one_enemy_near_player() -> void:
	var pool := EnemyData.for_floor(current_floor)
	if pool.is_empty():
		return
	var pos := generator.random_floor_pos()
	var data: Dictionary = pool[randi() % pool.size()].duplicate(true)
	var node := _make_tile_node(data["symbol"], data["color"])
	_entity_layer.add_child(node)
	node.call("set_grid", pos.x, pos.y)
	enemies.append({
		"data": data, "hp": data["hp"],
		"grid_pos": pos, "node": node,
		"asleep": false, "alerted": true,
	})

func _apply_pot(item: Dictionary) -> void:
	var effect: String = item.get("effect", "")
	add_message("壺を使った！（%s）" % item.get("name","?"))
	match effect:
		"heal":
			var heal := randi_range(15, 30)
			p_hp = min(p_hp_max, p_hp + heal)
			add_message("HP が %d 回復した。" % heal)
		"poison":
			for enemy in enemies:
				if fov_visible.has(enemy["grid_pos"] as Vector2i):
					var dmg := randi_range(5, 12)
					enemy["hp"] -= dmg
					add_message("%s に %d ダメージ！" % [enemy["data"]["name"], dmg])
					if enemy["hp"] <= 0:
						_kill_enemy(enemy)
		"strength":
			p_atk_base += 3
			add_message("力が 3 上がった！")
		"blind":
			add_message("なぜか自分の目が見えなくなった…（視界1）")
		"storage":
			add_message("何も入っていない壺だった。")

func _drop_selected_item() -> void:
	if p_inventory.is_empty():
		return
	inv_cursor = clamp(inv_cursor, 0, p_inventory.size() - 1)
	var item: Dictionary = p_inventory[inv_cursor]
	# 装備中なら外す
	if p_weapon.get("id","") == item.get("id","") and not item.get("cursed", false):
		p_weapon = {}
	if p_shield.get("id","") == item.get("id",""):
		p_shield = {}
	if p_ring.get("id","") == item.get("id",""):
		p_ring = {}
	_place_floor_item(item, p_grid)
	p_inventory.remove_at(inv_cursor)
	inv_cursor = min(inv_cursor, p_inventory.size() - 1)
	add_message("%s を捨てた。" % item.get("name","?"))
	if p_inventory.is_empty():
		game_state = "playing"
	_refresh_hud()

# ─── FOV（視野計算）──────────────────────────────────────
func _update_fov() -> void:
	fov_visible.clear()
	var radius := FOV_RADIUS
	if p_ring.get("effect", "") == "detection":
		radius = 15
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var tx := p_grid.x + dx
			var ty := p_grid.y + dy
			if tx < 0 or tx >= DungeonGenerator.MAP_W \
					or ty < 0 or ty >= DungeonGenerator.MAP_H:
				continue
			if _has_los(p_grid.x, p_grid.y, tx, ty):
				var vp := Vector2i(tx, ty)
				fov_visible[vp] = true
				explored[vp] = true
	_map_drawer.call("queue_redraw")

func _has_los(x0: int, y0: int, x1: int, y1: int) -> bool:
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
			if generator.get_tile(cx, cy) == DungeonGenerator.TILE_WALL:
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
func _sync_entity_visibility() -> void:
	# 敵：視界外は非表示（.visible は CanvasItem の組み込みプロパティなので直接代入OK）
	for enemy in enemies:
		enemy["node"].visible = fov_visible.has(enemy["grid_pos"] as Vector2i)
	# アイテム：探索済みなら表示
	for fi in floor_items:
		fi["node"].visible = explored.has(fi["grid_pos"] as Vector2i)

# ─── カメラ更新 ───────────────────────────────────────────
func _update_camera() -> void:
	_camera.position = Vector2(
		p_grid.x * TILE_SIZE + TILE_SIZE / 2,
		p_grid.y * TILE_SIZE + TILE_SIZE / 2)

# ─── HUD更新 ─────────────────────────────────────────────
func _refresh_hud() -> void:
	if is_instance_valid(_hud):
		_hud.queue_redraw()

# ─── ゲームオーバー・勝利 ────────────────────────────────
func _trigger_game_over() -> void:
	game_state = "dead"
	add_message("あなたは倒れた…")
	_refresh_hud()

func _trigger_victory() -> void:
	game_state = "victory"
	add_message("古代の守護者を倒し、遺産を持ち帰った！")
	_refresh_hud()

# ─── ユーティリティ ───────────────────────────────────────
func calc_atk() -> int:
	return p_atk_base + p_weapon.get("atk", 0) + p_ring.get("atk", 0)

func calc_def() -> int:
	return p_def_base + p_shield.get("def", 0) + p_ring.get("def", 0)

func add_message(text: String) -> void:
	messages.append(text)
	if messages.size() > 30:
		messages.remove_at(0)

func _enemy_at(pos: Vector2i) -> Variant:
	for enemy in enemies:
		if (enemy["grid_pos"] as Vector2i) == pos:
			return enemy
	return null

func _item_at(pos: Vector2i) -> Variant:
	for fi in floor_items:
		if (fi["grid_pos"] as Vector2i) == pos:
			return fi
	return null

func _make_tile_node(sym: String, bg: Color,
		fg: Color = Color.WHITE, fs: int = 20) -> Node2D:
	var node := Node2D.new()
	node.set_script(load("res://scripts/tile_node.gd"))
	node.call("setup", sym, bg, fg, fs)
	return node
