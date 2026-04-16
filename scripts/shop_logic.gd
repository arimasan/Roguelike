class_name ShopLogic
extends RefCounted

## 店（買う／売る／カーペット陳列）のロジックをまとめる。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態（shop_items / shop_cursor / shop_mode / shop_sell_cursor /
##   _shopkeeper / _shop_traded / _in_shop_area / _shop_entered）はすべて game.gd が所有。
##   このファイルは「ロジックとノード生成」のみを担当し、状態は game 経由で読み書きする。
## * 第1引数に必ず game.gd インスタンス（Node）を受け取る。
## * BGM制御と入退場メッセージは game._update_area_bgm に残す（店・MHの同時判定があるため）。
##
## ── ここに書くべきもの ───────────────────────────────────
## * 店員と商品の初期配置（setup）
## * プレイヤーが店員に接触した時のUI遷移（open）
## * 購入／売却処理（try_buy / try_sell）
## * カーペット上の落下アイテムを売却商品に変換
## * 店UIの入力処理（handle_input）
##
## ── ここに書かないべきもの ─────────────────────────────
## * BGM切り替え／入退場メッセージ（game._update_area_bgm）
## * アイテムスポーン一般（game.gd の _spawn_items）
## * モンスターハウス関連（game.gd）

# ─── 初期化：店員と商品を配置 ─────────────────────────────
static func setup(game: Node) -> void:
	# 店員ノード
	var sk_node: Node2D = game._make_tile_node("店", Color(0.15, 0.10, 0.05), Color(1.0, 0.85, 0.1), 14)
	sk_node.z_index = 1
	game._entity_layer.add_child(sk_node)
	var sk_pos: Vector2i = game.generator.shop_keeper_pos
	sk_node.call("set_grid", sk_pos.x, sk_pos.y)
	sk_node.call("set_sprite", Assets.SHOP_KEEPER)
	game._shopkeeper = {"grid_pos": sk_pos, "node": sk_node}

	# 店アイテム（最大9個）
	for pos in game.generator.shop_item_positions:
		var item: Dictionary = ItemData.random_item(int(game.current_floor))
		item["_iid"] = int(game._next_iid)
		game._next_iid = int(game._next_iid) + 1
		var price: int  = ItemData.shop_price(item)
		var sym: String = ItemData.type_symbol(item.get("type", 0))
		var col: Color  = ItemData.type_color(item.get("type", 0))
		var node: Node2D = game._make_tile_node(sym, Color(0.15, 0.10, 0.05), col, 18)
		game._entity_layer.add_child(node)
		node.call("set_grid", pos.x, pos.y)
		node.call("set_sprite", Assets.item_type_sprite(item.get("type", 0)))
		game.shop_items.append({"item": item, "price": price, "grid_pos": pos, "node": node})

# ─── プレイヤーが店員に接触した時に呼ぶ ────────────────────
static func open(game: Node) -> void:
	game.shop_cursor      = 0
	game.shop_mode        = "buy"
	game.shop_sell_cursor = 0
	# カーペット上に置かれた floor_items を shop_items に変換
	convert_carpet_drops(game)
	game.game_state = "shop"
	game._refresh_hud()

## カーペットタイル上の floor_items を売却商品として shop_items に移す
static func convert_carpet_drops(game: Node) -> void:
	var converted: Array = []
	for fi: Dictionary in game.floor_items:
		var pos: Vector2i = fi["grid_pos"] as Vector2i
		if game.generator.get_tile(pos.x, pos.y) == DungeonGenerator.TILE_SHOP_FLOOR:
			converted.append(fi)
	for fi: Dictionary in converted:
		game.floor_items.erase(fi)
		var price: int = ItemData.sell_price(fi["item"])
		game.shop_items.append({
			"item":     fi["item"],
			"price":    price,
			"grid_pos": fi["grid_pos"],
			"node":     fi["node"],
		})
		game.add_message("%s を引き取った。（買取 %dG）" % [fi["item"].get("name", "?"), price])

## 空いているカーペットタイルを返す。なければ Vector2i(-1,-1)
static func find_free_carpet_tile(game: Node) -> Vector2i:
	if not game.generator.has_shop:
		return Vector2i(-1, -1)
	var p_grid: Vector2i = game.p_grid
	var sk_pos: Vector2i = game._shopkeeper.get("grid_pos", Vector2i(-1, -1))
	var occupied: Array = [p_grid, sk_pos]
	for si: Dictionary in game.shop_items:
		occupied.append(si["grid_pos"] as Vector2i)
	for fi: Dictionary in game.floor_items:
		occupied.append(fi["grid_pos"] as Vector2i)
	var shop_room: Rect2i = game.generator.shop_room
	for y in range(shop_room.position.y, shop_room.end.y):
		for x in range(shop_room.position.x, shop_room.end.x):
			if game.generator.get_tile(x, y) != DungeonGenerator.TILE_SHOP_FLOOR:
				continue
			var pos := Vector2i(x, y)
			if pos not in occupied:
				return pos
	return Vector2i(-1, -1)

# ─── 売却 ──────────────────────────────────────────────────
## インベントリの index のアイテムを売却（カーペット上に商品として置く）
static func try_sell(game: Node, index: int) -> void:
	if index < 0 or index >= game.p_inventory.size():
		return
	var item: Dictionary = game.p_inventory[index]
	var carpet: Vector2i = find_free_carpet_tile(game)
	if carpet == Vector2i(-1, -1):
		game.add_message("置けるカーペットの空きがない。")
		return
	var price: int = ItemData.sell_price(item)
	# 装備中なら外す
	if game.p_weapon.get("_iid", -1) == item.get("_iid", -2) and not item.get("cursed", false):
		game.p_weapon = {}
	if game.p_shield.get("_iid", -1) == item.get("_iid", -2):
		game.p_shield = {}
	if game.p_ring.get("_iid", -1) == item.get("_iid", -2):
		game.p_ring = {}
	# ノードを作成して床に置く（shop_item として登録）
	var sym: String = ItemData.type_symbol(item.get("type", 0))
	var col: Color  = ItemData.type_color(item.get("type", 0))
	var node: Node2D = game._make_tile_node(sym, Color(0.15, 0.10, 0.05), col, 18)
	game._entity_layer.add_child(node)
	node.call("set_grid", carpet.x, carpet.y)
	node.call("set_sprite", Assets.item_type_sprite(item.get("type", 0)))
	game.shop_items.append({"item": item, "price": price, "grid_pos": carpet, "node": node})
	game.p_inventory.remove_at(index)
	game.shop_sell_cursor = min(int(game.shop_sell_cursor), max(0, game.p_inventory.size() - 1))
	game._shop_traded = true
	game.add_message("%s を %dG で売りに出した。" % [item.get("name", "?"), price])
	game._play_se("coin")
	game._refresh_hud()

# ─── 購入 ──────────────────────────────────────────────────
static func try_buy(game: Node, index: int) -> void:
	if index < 0 or index >= game.shop_items.size():
		return
	var si: Dictionary = game.shop_items[index]
	var price: int     = int(si["price"])
	if int(game.p_gold) < price:
		game.add_message("所持金が足りない。（%dG 必要 / 所持 %dG）" % [price, int(game.p_gold)])
		return
	if game.p_inventory.size() >= int(game.MAX_INVENTORY):
		game.add_message("持ち物がいっぱいで買えない。")
		return
	game.p_gold = int(game.p_gold) - price
	var item: Dictionary = (si["item"] as Dictionary).duplicate(true)
	game.p_inventory.append(item)
	si["node"].queue_free()
	game.shop_items.remove_at(index)
	game.shop_cursor = min(int(game.shop_cursor), max(0, game.shop_items.size() - 1))
	game._shop_traded = true
	game.add_message("%s を %dG で購入した。（残金: %dG）" % [item.get("name", "?"), price, int(game.p_gold)])
	game._play_se("coin")
	if game.game_state == "shop":
		game._refresh_hud()
	else:
		game._end_player_turn()

# ─── 店UIの入力 ────────────────────────────────────────────
static func handle_input(game: Node, kc: int) -> void:
	match kc:
		KEY_ESCAPE, KEY_I:
			game.game_state = "playing"
			game._refresh_hud()
		KEY_TAB:
			# 購入 / 売却 タブ切り替え
			game.shop_mode = "sell" if game.shop_mode == "buy" else "buy"
			game.shop_cursor      = clamp(int(game.shop_cursor),      0, max(0, game.shop_items.size()  - 1))
			game.shop_sell_cursor = clamp(int(game.shop_sell_cursor), 0, max(0, game.p_inventory.size() - 1))
			game._refresh_hud()
		KEY_UP, KEY_K:
			if game.shop_mode == "buy":
				if game.shop_items.size() > 0:
					game.shop_cursor = max(0, int(game.shop_cursor) - 1)
					game._refresh_hud()
			else:
				if game.p_inventory.size() > 0:
					game.shop_sell_cursor = max(0, int(game.shop_sell_cursor) - 1)
					game._refresh_hud()
		KEY_DOWN, KEY_J:
			if game.shop_mode == "buy":
				if game.shop_items.size() > 0:
					game.shop_cursor = min(game.shop_items.size() - 1, int(game.shop_cursor) + 1)
					game._refresh_hud()
			else:
				if game.p_inventory.size() > 0:
					game.shop_sell_cursor = min(game.p_inventory.size() - 1, int(game.shop_sell_cursor) + 1)
					game._refresh_hud()
		KEY_ENTER, KEY_Z, KEY_KP_ENTER:
			if game.shop_mode == "buy":
				if game.shop_items.size() > 0:
					try_buy(game, int(game.shop_cursor))
			else:
				try_sell(game, int(game.shop_sell_cursor))
