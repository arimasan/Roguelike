class_name InventoryUI
extends RefCounted

## インベントリ／アクションメニュー／保存の箱 の入力処理と状態遷移を担当する。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態（inv_cursor / action_cursor / _action_list / _storage_pot_iid / storage_cursor /
##   game_state / p_inventory / p_weapon / p_shield / p_ring）はすべて game.gd が所有。
##   このファイルは「入力解釈→状態書き換え」のみを担当する。
## * 第1引数に必ず game.gd インスタンス（Node）を受け取る。
## * 描画（HUD側）は hud.gd が担当、ここは描画しない。
##
## ── ここに書くべきもの ───────────────────────────────────
## * game_state が "inventory" / "inv_action" / "storage_pot" / "storage_select" のときの入力処理
## * アクションメニューの一覧生成（build_actions）
## * 各アクションの分岐（使う・装備・投げる・置く・見る・入れる）
## * 保存の箱の取り出し／しまう操作ロジック
##
## ── ここに書かないべきもの ─────────────────────────────
## * アイテム使用効果そのもの（ItemEffects）
## * 投擲ロジック（ThrowSystem）
## * 床アイテム取得・落下位置探索（game.gd の _drop_selected_item / _find_free_drop_pos）
## * 描画（hud.gd）

# ─── インベントリ画面の開閉 ────────────────────────────────
static func open(game: Node) -> void:
	var list: Array = game._inventory_display_list()
	if list.is_empty():
		game.add_message("荷物は空だ。")
		return
	game.inv_cursor = clamp(int(game.inv_cursor), 0, list.size() - 1)
	game.game_state = "inventory"
	game._refresh_hud()

static func handle_input(game: Node, kc: int, shift: bool = false) -> void:
	var list_size: int = game._inventory_display_list().size()
	match kc:
		KEY_ESCAPE, KEY_I:
			game.game_state = "playing"
			game._refresh_hud()
		KEY_UP, KEY_K:
			game.inv_cursor = max(0, int(game.inv_cursor) - 1)
			game._refresh_hud()
		KEY_DOWN, KEY_J:
			game.inv_cursor = min(list_size - 1, int(game.inv_cursor) + 1)
			game._refresh_hud()
		KEY_ENTER, KEY_Z, KEY_KP_ENTER:
			if shift:
				use_selected(game)                 # 即時使用ショートカット
			else:
				open_action_menu(game)
		KEY_D:
			# 足元アイテムは既に床にあるので drop 不可
			if game._is_floor_entry(int(game.inv_cursor)):
				return
			game._drop_selected_item()

# ─── アイテムアクションメニュー ────────────────────────────
## 選択アイテムの種別に応じたアクション一覧。要素は [action_id, label] のペア。
static func build_actions(item: Dictionary) -> Array:
	var t: int = item.get("type", -1)
	match t:
		ItemData.TYPE_WEAPON:  return [["equip","装備する"], ["throw","投げる"], ["drop","置く"]]
		ItemData.TYPE_SHIELD:  return [["equip","装備する"], ["throw","投げる"], ["drop","置く"]]
		ItemData.TYPE_RING:    return [["equip","装備する"], ["throw","投げる"], ["drop","置く"]]
		ItemData.TYPE_FOOD:    return [["eat","食べる"],     ["throw","投げる"], ["drop","置く"]]
		ItemData.TYPE_POTION:  return [["drink","飲む"],     ["throw","投げる"], ["drop","置く"]]
		ItemData.TYPE_SCROLL:  return [["read","読む"],      ["throw","投げる"], ["drop","置く"]]
		ItemData.TYPE_STAFF:   return [["swing","振る"],     ["throw","投げる"], ["drop","置く"]]
		ItemData.TYPE_POT:
			if item.get("effect","") == "storage":
				return [["view","見る"], ["store","入れる"], ["throw","投げる"], ["drop","置く"]]
			if item.get("effect","") == "synthesis":
				return [["view","見る"], ["store","入れる"], ["throw","投げる"], ["drop","置く"]]
			return [["use","使う"], ["throw","投げる"], ["drop","置く"]]
	return [["use","使う"], ["throw","投げる"], ["drop","置く"]]

static func open_action_menu(game: Node) -> void:
	var list: Array = game._inventory_display_list()
	if list.is_empty():
		return
	game.inv_cursor = clamp(int(game.inv_cursor), 0, list.size() - 1)
	var item: Dictionary = list[int(game.inv_cursor)]
	var actions: Array = build_actions(item)
	# 足元アイテムは「置く」を除外（既に床にある）
	if game._is_floor_entry(int(game.inv_cursor)):
		var filtered: Array = []
		for a in actions:
			if a[0] != "drop":
				filtered.append(a)
		actions = filtered
	game._action_list = actions
	game.action_cursor = 0
	game.game_state = "inv_action"
	game._refresh_hud()

## 足元アイテムを拾わずにその場で使用して、床から消す。
## ItemEffects.apply_item で消費判定（消費=true）されたら floor_items から削除。
## 多用途の箱（uses が残る）は uses を更新しつつ床に残る。
static func _use_floor_item_direct(game: Node) -> void:
	var fi = game._item_at(game.p_grid)
	if fi == null:
		game.game_state = "playing"
		game._refresh_hud()
		return
	var item: Dictionary = fi["item"]
	# _iid 未付与なら付与（装備照合や再参照のため）
	if not item.has("_iid"):
		item["_iid"] = int(game._next_iid)
		game._next_iid = int(game._next_iid) + 1
	var consumed: bool = ItemEffects.apply_item(game, item)
	if consumed:
		fi["node"].queue_free()
		(game.floor_items as Array).erase(fi)
	# ItemEffects が game_state を変えるケース（例: storage_pot）に備えて、
	# まだ inv_action のままなら playing に戻す
	if game.game_state == "inv_action":
		game.game_state = "playing"
	game._refresh_hud()
	game._end_player_turn()

## 足元アイテムが対象の場合、アクション実行前に自動で拾ってインベントリに移す。
## 成功で true（cursor は拾得後の p_inventory 末尾）、満杯などで失敗なら false。
static func _ensure_picked_up(game: Node) -> bool:
	if int(game.inv_cursor) < game.p_inventory.size():
		return true
	# 足元アイテム
	if game.p_inventory.size() >= int(game.MAX_INVENTORY):
		game.add_message("荷物がいっぱいで拾えない。")
		return false
	var fi = game._item_at(game.p_grid)
	if fi == null:
		return false
	game._pickup_item(fi)
	game.inv_cursor = game.p_inventory.size() - 1
	return true

static func handle_action_input(game: Node, kc: int) -> void:
	var list: Array = game._action_list
	match kc:
		KEY_ESCAPE:
			game.game_state = "inventory"
			game._refresh_hud()
		KEY_UP, KEY_K:
			game.action_cursor = max(0, int(game.action_cursor) - 1)
			game._refresh_hud()
		KEY_DOWN, KEY_J:
			game.action_cursor = min(list.size() - 1, int(game.action_cursor) + 1)
			game._refresh_hud()
		KEY_ENTER, KEY_Z, KEY_KP_ENTER:
			if list.is_empty():
				return
			var action_id: String = list[int(game.action_cursor)][0]
			execute_action(game, action_id)

static func execute_action(game: Node, action_id: String) -> void:
	var from_floor: bool = game._is_floor_entry(int(game.inv_cursor))
	# 足元アイテムでインベントリ枠を使わずに直接実行できるアクション
	if from_floor:
		match action_id:
			"eat", "drink", "read", "swing", "use":
				_use_floor_item_direct(game)
				return
			"throw":
				ThrowSystem.start_aim_from_floor(game, false)
				return
			"shoot":
				ThrowSystem.start_aim_from_floor(game, true)
				return
	# equip / view / store / 通常経路は事前にインベントリへ取り込む必要がある
	if action_id != "drop":
		if not _ensure_picked_up(game):
			game.game_state = "playing"
			game._refresh_hud()
			return
	match action_id:
		"equip", "eat", "drink", "read", "swing", "use":
			use_selected(game)                             # ItemEffects.apply_item 経由
			if game.game_state == "inv_action":
				game.game_state = "playing"
				game._refresh_hud()
		"view":
			game.inv_cursor = clamp(int(game.inv_cursor), 0, game.p_inventory.size() - 1)
			var item: Dictionary = game.p_inventory[int(game.inv_cursor)]
			open_storage_pot(game, item)
			game._end_player_turn()
		"store":
			game.inv_cursor = clamp(int(game.inv_cursor), 0, game.p_inventory.size() - 1)
			var pot: Dictionary = game.p_inventory[int(game.inv_cursor)]
			var capacity: int = int(pot.get("capacity", 3))
			var contents: Array = pot.get("contents", [])
			if contents.size() >= capacity:
				game.add_message("箱はいっぱいだ。")
				game.game_state = "inventory"
				game._refresh_hud()
				return
			game._storage_pot_iid = int(pot.get("_iid", -1))
			game.storage_cursor   = 0
			game.game_state       = "storage_select"
			game.inv_cursor       = 0
			game._refresh_hud()
			game._end_player_turn()
		"throw":
			ThrowSystem.start_aim(game, false)
		"shoot":
			ThrowSystem.start_aim(game, true)
		"drop":
			game._drop_selected_item()
			if game.game_state == "inv_action":
				game.game_state = "playing"
			game._refresh_hud()

# ─── アイテムの即時使用 ────────────────────────────────────
static func use_selected(game: Node) -> void:
	# 足元アイテムを選択中の場合は先に拾う（Shift+Enter 即時使用ショートカットでも対応）
	if not _ensure_picked_up(game):
		return
	if game.p_inventory.is_empty():
		return
	game.inv_cursor = clamp(int(game.inv_cursor), 0, game.p_inventory.size() - 1)
	var item: Dictionary = game.p_inventory[int(game.inv_cursor)]
	var consumed: bool = ItemEffects.apply_item(game, item)
	if consumed:
		game.p_inventory.remove_at(int(game.inv_cursor))
		game.inv_cursor = min(int(game.inv_cursor), game.p_inventory.size() - 1)
	if game.p_inventory.is_empty():
		game.game_state = "playing"
	game._refresh_hud()
	game._end_player_turn()

# ─── 保存の箱：メニューを開く ─────────────────────────────
## ItemEffects.apply_item からも呼ばれる（TYPE_POT / effect=="storage"）
static func open_storage_pot(game: Node, item: Dictionary) -> bool:
	game._storage_pot_iid = int(item.get("_iid", -1))
	game.storage_cursor   = 0
	game.game_state       = "storage_pot"
	game._refresh_hud()
	return false   # 箱は消費しない

## _storage_pot_iid に対応する箱 Dictionary を取得
static func _find_pot(game: Node) -> Dictionary:
	var iid: int = int(game._storage_pot_iid)
	for it in game.p_inventory:
		if int(it.get("_iid", -1)) == iid:
			return it
	return {}

# ─── 保存の箱メイン画面：取り出し／しまう切替 ────────────
static func handle_storage_pot_input(game: Node, kc: int) -> void:
	var pot: Dictionary = _find_pot(game)
	if pot.is_empty():
		game.game_state = "playing"
		game._refresh_hud()
		return
	var contents: Array = pot.get("contents", [])
	match kc:
		KEY_ESCAPE, KEY_I:
			game.game_state = "inventory"
			game._storage_pot_iid = -1
			game._refresh_hud()
		KEY_UP, KEY_K:
			if not contents.is_empty():
				game.storage_cursor = max(0, int(game.storage_cursor) - 1)
				game._refresh_hud()
		KEY_DOWN, KEY_J:
			if not contents.is_empty():
				game.storage_cursor = min(contents.size() - 1, int(game.storage_cursor) + 1)
				game._refresh_hud()
		KEY_ENTER, KEY_Z, KEY_KP_ENTER:
			# 取り出し
			if contents.is_empty():
				return
			if game.p_inventory.size() >= game.MAX_INVENTORY:
				game.add_message("荷物がいっぱいで取り出せない。")
				return
			var cur: int = int(game.storage_cursor)
			var stored: Dictionary = contents[cur]
			game.p_inventory.append(stored)
			contents.remove_at(cur)
			game.storage_cursor = clamp(cur, 0, max(0, contents.size() - 1))
			game.add_message("%s を取り出した。" % stored.get("name", "?"))
			game._refresh_hud()
		KEY_P:
			# しまうモードへ
			var capacity: int = int(pot.get("capacity", 3))
			if contents.size() >= capacity:
				game.add_message("箱はいっぱいだ。")
				return
			if game.p_inventory.is_empty():
				game.add_message("しまえるアイテムがない。")
				return
			game.inv_cursor = clamp(int(game.inv_cursor), 0, game.p_inventory.size() - 1)
			game.game_state = "storage_select"
			game._refresh_hud()

# ─── 保存の箱：しまうモード（インベントリから選択して入れる）─
static func handle_storage_select_input(game: Node, kc: int) -> void:
	match kc:
		KEY_ESCAPE:
			game.game_state = "storage_pot"
			game._refresh_hud()
			return
		KEY_UP, KEY_K:
			game.inv_cursor = max(0, int(game.inv_cursor) - 1)
			game._refresh_hud()
			return
		KEY_DOWN, KEY_J:
			game.inv_cursor = min(game.p_inventory.size() - 1, int(game.inv_cursor) + 1)
			game._refresh_hud()
			return
		KEY_ENTER, KEY_Z, KEY_KP_ENTER:
			pass
		_:
			return

	# 選択アイテムを箱に入れる
	game.inv_cursor = clamp(int(game.inv_cursor), 0, game.p_inventory.size() - 1)
	var cur: int = int(game.inv_cursor)
	var target_item: Dictionary = game.p_inventory[cur]
	var pot_iid: int = int(game._storage_pot_iid)
	# 箱自身は入れられない
	if int(target_item.get("_iid", -2)) == pot_iid:
		game.add_message("箱に箱は入れられない。")
		return
	# 装備中は入れられない
	if game.p_weapon.get("_iid", -1) == target_item.get("_iid", -2) \
			or game.p_shield.get("_iid", -1) == target_item.get("_iid", -2) \
			or game.p_ring.get("_iid",   -1) == target_item.get("_iid", -2):
		game.add_message("装備中のアイテムはしまえない。")
		return
	# 箱を探して contents に追加（容量チェック込み）
	var pot: Dictionary = _find_pot(game)
	if pot.is_empty():
		game.game_state = "playing"
		game._refresh_hud()
		return
	if not pot.has("contents"):
		pot["contents"] = []
	var capacity: int = int(pot.get("capacity", 3))
	if (pot["contents"] as Array).size() >= capacity:
		game.add_message("箱はいっぱいだ。")
		game.game_state = "storage_pot"
		game._refresh_hud()
		return
	# 合成の箱: 同タイプの武器/盾が既にあれば自動合成（素材は消費、ベースを更新）
	if pot.get("effect", "") == "synthesis":
		var result: Dictionary = SealSystem.try_merge_in_pot(pot["contents"] as Array, target_item)
		if result.get("merged", false):
			game.p_inventory.remove_at(cur)
			game.inv_cursor = min(cur, max(0, game.p_inventory.size() - 1))
			for msg: String in result.get("messages", []):
				game.add_message(msg)
			game.add_message("合成完了！")
			game._play_se("general_item")
			# 合成後は storage_select に留まる（さらに素材追加可能）
			if game.p_inventory.is_empty():
				game.game_state = "storage_pot"
			game._refresh_hud()
			return
	(pot["contents"] as Array).append(target_item)
	game.p_inventory.remove_at(cur)
	game.inv_cursor = min(cur, max(0, game.p_inventory.size() - 1))
	game.add_message("%s を箱にしまった。" % SealSystem.display_name(target_item))
	# 容量に空きがあり、インベントリにもまだアイテムがあれば storage_select に留まる
	var new_cap: int = int(pot.get("capacity", 3))
	if (pot["contents"] as Array).size() >= new_cap:
		game.add_message("箱がいっぱいになった。")
		game.game_state = "storage_pot"
	elif game.p_inventory.is_empty():
		game.game_state = "storage_pot"
	else:
		game.game_state = "storage_select"
	game._refresh_hud()
