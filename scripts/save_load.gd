class_name SaveLoad
extends RefCounted

## セーブ／ロード処理を担当する。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態はすべて game.gd が所有。ここは JSON への直列化／復元のみを行う。
## * 第1引数に必ず game.gd インスタンス（Node）を受け取る。
## * バージョン管理はキー "version" を持たせるだけ（マイグレーションは未実装）。
##
## ── ここに書くべきもの ───────────────────────────────────
## * `save_game(game)` / `load_game(game)` / `has_save()` / `delete_save()`
## * 敵・アイテム・店・ワナ・MH・音量・キーバインド・FOV探索済みタイルなどの直列化
##
## ── ここに書かないべきもの ─────────────────────────────
## * ロード後の視覚反映（`game._apply_loaded_settings` など game.gd 側で呼ぶ）
## * ゲーム起動時のフローそのもの（`_ready` は game.gd）
## * 個別の状態更新ロジック（各システムのスクリプトへ）

const SAVE_PATH := "user://save.json"

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("save.json")

# ─── 保存 ──────────────────────────────────────────────────
static func save_game(game: Node) -> void:
	# タイルマップをフラット配列化
	var tiles_flat: Array = []
	for y in DungeonGenerator.MAP_H:
		for x in DungeonGenerator.MAP_W:
			tiles_flat.append(game.generator.map[y][x])

	# 探索済みタイル
	var explored_arr: Array = []
	for pos: Vector2i in game.explored:
		explored_arr.append([pos.x, pos.y])

	# 敵
	var enemies_arr: Array = []
	for enemy in game.enemies:
		enemies_arr.append({
			"id":           enemy["data"].get("id", ""),
			"hp":           enemy["hp"],
			"grid_x":       enemy["grid_pos"].x,
			"grid_y":       enemy["grid_pos"].y,
			"alerted":      enemy.get("alerted", false),
			"asleep":       enemy.get("asleep", false),
			"asleep_turns": enemy.get("asleep_turns", 0),
			"poisoned":     enemy.get("poisoned", 0),
			"sealed":       enemy.get("sealed", false),
			"slow_turns":      enemy.get("slow_turns", 0),
			"slow_skip":       enemy.get("slow_skip", false),
			"confused_turns":  enemy.get("confused_turns", 0),
			"paralyzed_turns": enemy.get("paralyzed_turns", 0),
			"interested_turns":enemy.get("interested_turns", 0),
			"mh_asleep":       enemy.get("mh_asleep", false),
			"skill_cooldowns": (enemy.get("skill_cooldowns", {}) as Dictionary).duplicate(true),
		})

	# 仲間
	var comp_arr: Array = []
	for c in game.companions:
		comp_arr.append({
			"id":     c["data"].get("id", ""),
			"hp":     int(c["hp"]),
			"hp_max": int(c.get("hp_max", c["hp"])),
			"grid_x": c["grid_pos"].x,
			"grid_y": c["grid_pos"].y,
		})

	# フロアアイテム
	var items_arr: Array = []
	for fi in game.floor_items:
		items_arr.append({
			"item":   (fi["item"] as Dictionary).duplicate(true),
			"grid_x": fi["grid_pos"].x,
			"grid_y": fi["grid_pos"].y,
		})

	# 金山
	var gold_arr: Array = []
	for gp in game.gold_piles:
		gold_arr.append({
			"amount": gp["amount"],
			"grid_x": gp["grid_pos"].x,
			"grid_y": gp["grid_pos"].y,
		})

	# 店アイテム
	var shop_arr: Array = []
	for si in game.shop_items:
		shop_arr.append({
			"item":   (si["item"] as Dictionary).duplicate(true),
			"price":  si["price"],
			"grid_x": si["grid_pos"].x,
			"grid_y": si["grid_pos"].y,
		})
	var shopkeeper_data := {}
	if not (game._shopkeeper as Dictionary).is_empty():
		shopkeeper_data = {
			"grid_x": game._shopkeeper["grid_pos"].x,
			"grid_y": game._shopkeeper["grid_pos"].y,
		}

	var data := {
		"version":        1,
		"turn_count":     game.turn_count,
		"current_floor":  game.current_floor,
		"elapsed_msec":   Time.get_ticks_msec() - int(game._start_time_msec),
		"next_iid":       game._next_iid,
		"player": {
			"hp":          game.p_hp,
			"hp_max":      game.p_hp_max,
			"atk_base":    game.p_atk_base,
			"def_base":    game.p_def_base,
			"level":       game.p_level,
			"exp":         game.p_exp,
			"exp_next":    game.p_exp_next,
			"fullness":    game.p_fullness,
			"gold":        game.p_gold,
			"blind_turns":    game.p_blind_turns,
			"poisoned_turns": game.p_poisoned_turns,
			"sleep_turns":    game.p_sleep_turns,
			"slow_turns":     game.p_slow_turns,
			"confused_turns": game.p_confused_turns,
			"paralyzed_turns":game.p_paralyzed_turns,
			"slow_skip":      game._p_slow_skip,
			"regen_accum":  game._regen_accum,
			"hunger_accum": game._hunger_accum,
			"grid_x":      game.p_grid.x,
			"grid_y":      game.p_grid.y,
			"weapon":      (game.p_weapon as Dictionary).duplicate(true),
			"shield":      (game.p_shield as Dictionary).duplicate(true),
			"ring":        (game.p_ring as Dictionary).duplicate(true),
			"inventory":   (game.p_inventory as Array).duplicate(true),
		},
		"map_tiles":      tiles_flat,
		"player_start_x": game.generator.player_start.x,
		"player_start_y": game.generator.player_start.y,
		"stairs_x":       game.generator.stairs_pos.x,
		"stairs_y":       game.generator.stairs_pos.y,
		"rooms":          (game.generator.rooms as Array).map(func(r: Rect2i) -> Array:
							return [r.position.x, r.position.y, r.size.x, r.size.y]),
		"explored":       explored_arr,
		"enemies":        enemies_arr,
		"companions":     comp_arr,
		"floor_items":    items_arr,
		"gold_piles":     gold_arr,
		"shop_items":     shop_arr,
		"shopkeeper":     shopkeeper_data,
		"has_shop":       game.generator.has_shop,
		"shop_room":      [game.generator.shop_room.position.x, game.generator.shop_room.position.y,
						   game.generator.shop_room.size.x,     game.generator.shop_room.size.y],
		"shop_entered":   game._shop_entered,
		"vol_master":     game.vol_master,
		"vol_bgm":        game.vol_bgm,
		"vol_se":         game.vol_se,
		"key_bindings":   (game.key_bindings as Dictionary).duplicate(),
		"bgm_key":        game._current_bgm_key,
		"in_shop_area":   game._in_shop_area,
		"mh_triggered":   game._monster_house_triggered,
		"thief_mode":     game._thief_mode,
		"skill_points":   game.skill_points,
		"skills_unlocked": (game.skills_unlocked as Dictionary).duplicate(),
		"skill_survived_fatal": game._skill_survived_fatal,
		"has_mh":         game.generator.has_monster_house,
		"mh_room":        [game.generator.monster_house_room.position.x, game.generator.monster_house_room.position.y,
						   game.generator.monster_house_room.size.x,     game.generator.monster_house_room.size.y],
		"traps":          (game.traps as Array).map(func(t: Dictionary) -> Dictionary:
							return {"type": t["type"], "grid_x": t["grid_pos"].x, "grid_y": t["grid_pos"].y,
									"triggered": t.get("triggered", false)}),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

# ─── 復元 ──────────────────────────────────────────────────
static func load_game(game: Node) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		return false
	var data: Dictionary = json.get_data()
	if not data.has("version"):
		return false
	# マップサイズ互換チェック（旧サイズのセーブは読み込めない）
	var tiles: Array = data.get("map_tiles", [])
	if tiles.size() != DungeonGenerator.MAP_W * DungeonGenerator.MAP_H:
		delete_save()
		return false

	# プレイヤーステータス復元
	var pd: Dictionary = data["player"]
	game.p_hp          = int(pd["hp"])
	game.p_hp_max      = int(pd["hp_max"])
	game.p_atk_base    = int(pd["atk_base"])
	game.p_def_base    = int(pd["def_base"])
	game.p_level       = int(pd["level"])
	game.p_exp         = int(pd["exp"])
	game.p_exp_next    = int(pd["exp_next"])
	game.p_fullness    = int(pd["fullness"])
	game.p_gold        = int(pd["gold"])
	game.p_blind_turns    = int(pd.get("blind_turns", 0))
	game.p_poisoned_turns = int(pd.get("poisoned_turns", 0))
	game.p_sleep_turns    = int(pd.get("sleep_turns", 0))
	game.p_slow_turns      = int(pd.get("slow_turns", 0))
	game.p_confused_turns  = int(pd.get("confused_turns", 0))
	game.p_paralyzed_turns = int(pd.get("paralyzed_turns", 0))
	game._p_slow_skip      = bool(pd.get("slow_skip", false))
	game._regen_accum  = float(pd["regen_accum"])
	game._hunger_accum = float(pd.get("hunger_accum", 0.0))
	game.p_grid        = Vector2i(int(pd["grid_x"]), int(pd["grid_y"]))
	game.p_weapon      = pd.get("weapon", {})
	game.p_shield      = pd.get("shield", {})
	game.p_ring        = pd.get("ring",   {})
	game.p_inventory   = pd.get("inventory", [])
	game.turn_count    = int(data["turn_count"])
	game.current_floor = int(data["current_floor"])
	game._next_iid     = int(data.get("next_iid", 0))
	game._start_time_msec = Time.get_ticks_msec() - int(data.get("elapsed_msec", 0))

	# マップ復元
	game.generator = DungeonGenerator.new()
	game.generator.load_map_data(
		data["map_tiles"],
		int(data["player_start_x"]), int(data["player_start_y"]),
		int(data["stairs_x"]),       int(data["stairs_y"]))
	# 部屋データ復元（FOV判定に必要）
	game.generator.rooms = []
	for rd: Array in data.get("rooms", []):
		game.generator.rooms.append(Rect2i(int(rd[0]), int(rd[1]), int(rd[2]), int(rd[3])))

	# 探索済みタイル復元
	game.explored.clear()
	for pair in data["explored"]:
		game.explored[Vector2i(int(pair[0]), int(pair[1]))] = true

	# エンティティクリア
	for ch in game._entity_layer.get_children():
		ch.queue_free()
	game.enemies.clear()
	game.floor_items.clear()
	game.gold_piles.clear()
	game.fov_visible.clear()

	# マップ描画
	game._map_drawer.call("setup", game.generator, game.fov_visible, game.explored)

	# プレイヤーノード
	game._player_node = game._make_tile_node("@", Color(0.10, 0.28, 0.80))
	game._player_node.z_index = 1
	game._entity_layer.add_child(game._player_node)
	game._player_node.call("set_grid", game.p_grid.x, game.p_grid.y)
	game._player_node.call("set_sprite", Assets.PLAYER)

	# 敵復元
	for ed in data["enemies"]:
		var base_data: Dictionary = EnemyData.get_by_id(ed["id"])
		if base_data.is_empty():
			continue
		var node: Node2D = game._make_tile_node(base_data["symbol"], base_data["color"])
		node.z_index = 1
		game._entity_layer.add_child(node)
		var pos := Vector2i(int(ed["grid_x"]), int(ed["grid_y"]))
		node.call("set_grid", pos.x, pos.y)
		node.call("set_sprite", Assets.enemy_sprite(base_data.get("id", "")))
		var edict := {
			"data":            base_data,
			"hp":              int(ed["hp"]),
			"grid_pos":        pos,
			"node":            node,
			"alerted":         bool(ed.get("alerted", false)),
			"asleep":          bool(ed.get("asleep", false)),
			"asleep_turns":    int(ed.get("asleep_turns", 0)),
			"poisoned":        int(ed.get("poisoned", 0)),
			"sealed":          bool(ed.get("sealed", false)),
			"slow_turns":      int(ed.get("slow_turns", 0)),
			"slow_skip":       bool(ed.get("slow_skip", false)),
			"confused_turns":  int(ed.get("confused_turns", 0)),
			"paralyzed_turns": int(ed.get("paralyzed_turns", 0)),
			"interested_turns":int(ed.get("interested_turns", 0)),
			"mh_asleep":       bool(ed.get("mh_asleep", false)),
			"skill_cooldowns": (ed.get("skill_cooldowns", {}) as Dictionary).duplicate(true),
		}
		game.enemies.append(edict)
		game._refresh_enemy_status_visual(edict)

	# 仲間復元
	game.companions.clear()
	for cd in data.get("companions", []):
		var base_data: Dictionary = EnemyData.get_by_id(cd["id"])
		if base_data.is_empty():
			continue
		var pos: Vector2i = Vector2i(int(cd["grid_x"]), int(cd["grid_y"]))
		var node: Node2D = game._make_tile_node(base_data["symbol"], base_data["color"])
		node.z_index = 1
		game._entity_layer.add_child(node)
		node.call("set_grid", pos.x, pos.y)
		node.call("set_sprite", Assets.enemy_sprite(base_data.get("id", "")))
		node.call("set_status", "仲", Color(0.4, 0.7, 1.0))
		game.companions.append({
			"data":     base_data,
			"hp":       int(cd["hp"]),
			"hp_max":   int(cd.get("hp_max", cd["hp"])),
			"grid_pos": pos,
			"node":     node,
			"skill_cooldowns": {},
		})

	# フロアアイテム復元
	for fi in data["floor_items"]:
		var item: Dictionary = (fi["item"] as Dictionary).duplicate(true)
		var pos := Vector2i(int(fi["grid_x"]), int(fi["grid_y"]))
		game._place_floor_item(item, pos)

	# 金山復元
	for gp in data["gold_piles"]:
		var pos := Vector2i(int(gp["grid_x"]), int(gp["grid_y"]))
		game._place_gold_pile(int(gp["amount"]), pos)

	# 店復元
	game.shop_items.clear()
	game._shopkeeper   = {}
	game._shop_entered = bool(data.get("shop_entered", false))
	game.generator.has_shop = bool(data.get("has_shop", false))
	var sr: Array = data.get("shop_room", [0,0,0,0])
	game.generator.shop_room = Rect2i(int(sr[0]), int(sr[1]), int(sr[2]), int(sr[3]))
	var sk_data: Dictionary = data.get("shopkeeper", {})
	if not sk_data.is_empty():
		var sk_pos := Vector2i(int(sk_data["grid_x"]), int(sk_data["grid_y"]))
		game.generator.shop_keeper_pos = sk_pos
		var sk_node: Node2D = game._make_tile_node("店", Color(0.15, 0.10, 0.05), Color(1.0, 0.85, 0.1), 14)
		sk_node.z_index = 1
		game._entity_layer.add_child(sk_node)
		sk_node.call("set_grid", sk_pos.x, sk_pos.y)
		sk_node.call("set_sprite", Assets.SHOP_KEEPER)
		game._shopkeeper = {"grid_pos": sk_pos, "node": sk_node}
	for si in data.get("shop_items", []):
		var item: Dictionary = (si["item"] as Dictionary).duplicate(true)
		var pos  := Vector2i(int(si["grid_x"]), int(si["grid_y"]))
		var price: int = int(si["price"])
		var sym: String = ItemData.type_symbol(item.get("type", 0))
		var col: Color  = ItemData.type_color(item.get("type", 0))
		var node: Node2D = game._make_tile_node(sym, Color(0.15, 0.10, 0.05), col, 18)
		game._entity_layer.add_child(node)
		node.call("set_grid", pos.x, pos.y)
		node.call("set_sprite", Assets.item_type_sprite(item.get("type", 0)))
		game.shop_items.append({"item": item, "price": price, "grid_pos": pos, "node": node})

	# 音量・キーコンフィグ復元
	if data.has("vol_master"):
		game.vol_master = float(data["vol_master"])
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),
			game._linear_to_db_safe(game.vol_master))
	if data.has("vol_bgm"):
		game.vol_bgm = float(data["vol_bgm"])
	if data.has("vol_se"):
		game.vol_se = float(data["vol_se"])
	if data.has("key_bindings"):
		var saved_kb: Dictionary = data["key_bindings"]
		for action in game.KEY_ACTIONS:
			if saved_kb.has(action):
				game.key_bindings[action] = int(saved_kb[action])
	game._apply_loaded_settings()

	# BGM・エリアフラグ・MH・ワナ復元
	game._in_shop_area            = bool(data.get("in_shop_area", false))
	game._monster_house_triggered = bool(data.get("mh_triggered", false))
	game._thief_mode              = bool(data.get("thief_mode", false))
	game.skill_points             = int(data.get("skill_points", 0))
	game.skills_unlocked          = data.get("skills_unlocked", {})
	game._skill_survived_fatal    = bool(data.get("skill_survived_fatal", false))
	game.generator.has_monster_house = bool(data.get("has_mh", false))
	var mhr: Array = data.get("mh_room", [0, 0, 0, 0])
	game.generator.monster_house_room = Rect2i(int(mhr[0]), int(mhr[1]), int(mhr[2]), int(mhr[3]))
	game.traps.clear()
	for td: Dictionary in data.get("traps", []):
		var tp: Vector2i = Vector2i(int(td["grid_x"]), int(td["grid_y"]))
		var tt: String   = str(td["type"])
		var triggered: bool = bool(td.get("triggered", false))
		var tnode: Node2D = game._make_tile_node("", Color(0.15, 0.08, 0.08), Color.WHITE, 0)
		tnode.z_index = 0
		tnode.visible = false
		game._entity_layer.add_child(tnode)
		tnode.call("set_grid", tp.x, tp.y)
		tnode.call("set_sprite", Assets.TRAP)
		if triggered:
			tnode.visible = true
		game.traps.append({"type": tt, "grid_pos": tp, "node": tnode, "triggered": triggered})
	var saved_bgm: String = data.get("bgm_key", "explore")
	if saved_bgm.is_empty():
		saved_bgm = "explore"

	# FOV・カメラ・HUD
	Fov.update(game)
	Fov.sync_entity_visibility(game)
	game._update_camera()
	game._refresh_hud()
	game._refresh_player_status_visual()
	game._play_bgm(saved_bgm)
	game.add_message("セーブデータを読み込みました。（B%dF / Turn%d）" % [game.current_floor, game.turn_count])
	return true
