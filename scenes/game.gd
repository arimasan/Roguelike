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
var p_gold:      int   = 0
var p_blind_turns: int  = 0    # 盲目ターン残数（0=通常視界）
var _regen_accum: float = 0.0  # 自然回復の積み立て（整数になった分だけ回復）

# ─── エンティティ ─────────────────────────────────────────
# enemies: Array of { "data": dict, "hp": int, "grid_pos": V2i,
#                     "node": Node2D, "asleep": bool, "alerted": bool }
var enemies:     Array = []
# floor_items: Array of { "item": dict, "grid_pos": V2i, "node": Node2D }
var floor_items: Array = []
# gold_piles: Array of { "amount": int, "grid_pos": V2i, "node": Node2D }
var gold_piles:  Array = []

# ─── メッセージ ───────────────────────────────────────────
var messages: Array = []

# ─── インベントリカーソル ─────────────────────────────────
var inv_cursor: int = 0

# ─── アイテム個体ID ───────────────────────────────────────
# インベントリに入る際に採番。同名アイテムを個別に識別するために使用。
var _next_iid: int = 0

# ─── 保存の箱 ─────────────────────────────────────────────
var _storage_pot_iid: int = -1   # storage_select 中の箱の _iid

# ─── ズーム ───────────────────────────────────────────────
const ZOOM_LEVELS: Array[float] = [1.0, 2.0, 4.0]
var _zoom_index: int = 1   # デフォルト x2

# ─── ミニマップ ───────────────────────────────────────────
var show_minimap: bool = true   # M キーでトグル

# ─── 店 ───────────────────────────────────────────────────
# shop_items: Array of { "item": dict, "price": int, "grid_pos": V2i, "node": Node2D }
var shop_items:       Array      = []
var _shopkeeper:      Dictionary = {}   # { "grid_pos": V2i, "node": Node2D }
var shop_cursor:      int        = 0
var shop_mode:        String     = "buy"   # "buy" or "sell"
var shop_sell_cursor: int        = 0
var _shop_entered:    bool       = false   # 入店メッセージ表示済みフラグ

# ─── セーブ ───────────────────────────────────────────────
const SAVE_PATH := "user://save.json"

# ─── リザルト ─────────────────────────────────────────────
var death_cause:     String = ""   # ゲームオーバー時の死因テキスト
var _start_time_msec: int   = 0    # ゲーム開始時刻（msec）

# ─── ノード参照 ───────────────────────────────────────────
var _map_drawer    = null   # map_drawer.gd スクリプト付き Node2D
var _entity_layer: Node2D  = null
var _player_node   = null   # tile_node.gd スクリプト付き Node2D
var _camera:       Camera2D = null
var _hud           = null   # hud.gd スクリプト付き Control
var _bgm_player:   AudioStreamPlayer = null
var _options_layer: CanvasLayer = null
var _lbl_master_pct: Label = null
var _lbl_bgm_pct:    Label = null
var _lbl_se_pct:     Label = null

# ─── 音量設定 ────────────────────────────────────────────
var vol_master: float = 0.0   # デバッグ用 0%
var vol_bgm:    float = 0.0   # デバッグ用 0%
var vol_se:     float = 0.0   # デバッグ用 0%

# ─── キーコンフィグ ──────────────────────────────────────
const KEY_ACTIONS: Dictionary = {
	"move_up":    {"label": "上移動",             "default": KEY_UP},
	"move_down":  {"label": "下移動",             "default": KEY_DOWN},
	"move_left":  {"label": "左移動",             "default": KEY_LEFT},
	"move_right": {"label": "右移動",             "default": KEY_RIGHT},
	"diag_mod":   {"label": "斜め移動モディファイア", "default": KEY_SHIFT},
	"wait":       {"label": "待機/階段を降りる",   "default": KEY_SPACE},
	"inventory":  {"label": "インベントリ",        "default": KEY_I},
	"pickup":     {"label": "拾う",               "default": KEY_G},
	"zoom_in":    {"label": "ズームイン",          "default": KEY_EQUAL},
	"zoom_out":   {"label": "ズームアウト",        "default": KEY_MINUS},
}
var key_bindings:      Dictionary = {}
var _rebinding_action: String     = ""
var _rebind_button:    Button     = null

# ─── BGM パス定義 ────────────────────────────────────────
## 楽曲を差し替える際はここのパスを変更する（素材：MusMus https://musmus.work）
const BGM := {
	"explore":  "res://assets/bgm/explore.mp3",
	# "boss":   "res://assets/bgm/boss.mp3",
	# "gameover":"res://assets/bgm/gameover.mp3",
	# "victory": "res://assets/bgm/victory.mp3",
}

# ─── SE パス定義 ─────────────────────────────────────────
## 効果音を差し替える際はここのパスを変更する（素材：効果音ラボ https://soundeffect-lab.info）
const SE := {
	"attack": "res://assets/se/attack.mp3",
	"hit":    "res://assets/se/hit.mp3",
	"stairs": "res://assets/se/stairs.mp3",
	"coin":   "res://assets/se/coin.mp3",
	"pickup": "res://assets/se/pickup.mp3",
}

# ─── 初期化 ───────────────────────────────────────────────
func _ready() -> void:
	_start_time_msec = Time.get_ticks_msec()
	get_tree().set_auto_accept_quit(false)   # 手動でquit処理してセーブする
	for action: String in KEY_ACTIONS:
		key_bindings[action] = KEY_ACTIONS[action]["default"]
	_build_scene_nodes()
	if has_save():
		if not load_game():
			_start_new_floor()   # 読み込み失敗時は新規
	else:
		_start_new_floor()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game_state in ["playing", "inventory", "storage_select", "shop"]:
			save_game()
		get_tree().quit()

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
	_apply_zoom()

	# BGM プレイヤー
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	add_child(_bgm_player)

	# オプションパネル
	_build_options_panel()

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
	gold_piles.clear()
	shop_items.clear()
	_shopkeeper    = {}
	_shop_entered  = false
	explored.clear()
	fov_visible.clear()

	# ダンジョン生成
	generator = DungeonGenerator.new()
	generator.generate(current_floor)

	# マップ描画セットアップ（カスタムメソッドは call() で呼ぶ）
	_map_drawer.call("setup", generator, fov_visible, explored)

	# プレイヤーノード生成
	_player_node = _make_tile_node("@", Color(0.10, 0.28, 0.80))
	_player_node.z_index = 1
	_entity_layer.add_child(_player_node)
	p_grid = generator.player_start
	_player_node.call("set_grid", p_grid.x, p_grid.y)
	_player_node.call("set_sprite", Assets.PLAYER)

	# 敵・アイテム・お金配置
	_spawn_enemies()
	_spawn_items()
	_spawn_gold()
	if generator.has_shop:
		_setup_shop()

	# FOV更新・カメラ・HUD
	_update_fov()
	_sync_entity_visibility()
	_update_camera()
	_refresh_hud()

	_play_bgm("explore")
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
		node.z_index = 1
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

func _spawn_gold() -> void:
	var occupied: Array = [p_grid]
	for enemy in enemies:
		occupied.append(enemy["grid_pos"])
	for fi in floor_items:
		occupied.append(fi["grid_pos"])
	var count: int = randi_range(2, 4)
	for _i in count:
		var pos: Vector2i = generator.random_floor_pos()
		if pos in occupied:
			continue
		var amount: int = randi_range(current_floor * 3, current_floor * 10)
		_place_gold_pile(amount, pos)
		occupied.append(pos)

func _place_gold_pile(amount: int, pos: Vector2i) -> void:
	var node := _make_tile_node("$", Color(0.12, 0.12, 0.12), Color(1.0, 0.85, 0.0), 16)
	_entity_layer.add_child(node)
	node.call("set_grid", pos.x, pos.y)
	node.call("set_sprite", "res://assets/sprites/items/gold.png")
	gold_piles.append({"amount": amount, "grid_pos": pos, "node": node})

# ─── 店セットアップ ───────────────────────────────────────
func _setup_shop() -> void:
	# 店員ノード
	var sk_node := _make_tile_node("店", Color(0.15, 0.10, 0.05), Color(1.0, 0.85, 0.1), 14)
	sk_node.z_index = 1
	_entity_layer.add_child(sk_node)
	sk_node.call("set_grid", generator.shop_keeper_pos.x, generator.shop_keeper_pos.y)
	sk_node.call("set_sprite", Assets.SHOP_KEEPER)
	_shopkeeper = {"grid_pos": generator.shop_keeper_pos, "node": sk_node}

	# 店アイテム（最大9個）
	for pos in generator.shop_item_positions:
		var item: Dictionary = ItemData.random_item(current_floor)
		item["_iid"] = _next_iid
		_next_iid += 1
		var price: int  = ItemData.shop_price(item)
		var sym: String = ItemData.type_symbol(item.get("type", 0))
		var col: Color  = ItemData.type_color(item.get("type", 0))
		var node := _make_tile_node(sym, Color(0.15, 0.10, 0.05), col, 18)
		_entity_layer.add_child(node)
		node.call("set_grid", pos.x, pos.y)
		node.call("set_sprite", Assets.item_type_sprite(item.get("type", 0)))
		shop_items.append({"item": item, "price": price, "grid_pos": pos, "node": node})

func _open_shop() -> void:
	shop_cursor      = 0
	shop_mode        = "buy"
	shop_sell_cursor = 0
	# Method1: カーペット上に置かれた floor_items を shop_items に変換
	_convert_carpet_drops_to_shop_items()
	game_state = "shop"
	_refresh_hud()

## カーペットタイル上の floor_items を売却商品として shop_items に移す
func _convert_carpet_drops_to_shop_items() -> void:
	var converted: Array = []
	for fi: Dictionary in floor_items:
		var pos: Vector2i = fi["grid_pos"] as Vector2i
		if generator.get_tile(pos.x, pos.y) == DungeonGenerator.TILE_SHOP_FLOOR:
			converted.append(fi)
	for fi: Dictionary in converted:
		floor_items.erase(fi)
		var price: int = ItemData.sell_price(fi["item"])
		shop_items.append({
			"item":     fi["item"],
			"price":    price,
			"grid_pos": fi["grid_pos"],
			"node":     fi["node"],
		})
		add_message("%s を引き取った。（買取 %dG）" % [fi["item"].get("name", "?"), price])

## 空いているカーペットタイルを返す。なければ Vector2i(-1,-1)
func _find_free_carpet_tile() -> Vector2i:
	if not generator.has_shop:
		return Vector2i(-1, -1)
	var occupied: Array = [p_grid, _shopkeeper.get("grid_pos", Vector2i(-1, -1))]
	for si: Dictionary in shop_items:
		occupied.append(si["grid_pos"] as Vector2i)
	for fi: Dictionary in floor_items:
		occupied.append(fi["grid_pos"] as Vector2i)
	var shop_room: Rect2i = generator.shop_room
	for y in range(shop_room.position.y, shop_room.end.y):
		for x in range(shop_room.position.x, shop_room.end.x):
			if generator.get_tile(x, y) != DungeonGenerator.TILE_SHOP_FLOOR:
				continue
			var pos := Vector2i(x, y)
			if pos not in occupied:
				return pos
	return Vector2i(-1, -1)

## インベントリの index のアイテムを売却（カーペット上に商品として置く）
func _try_sell(index: int) -> void:
	if index < 0 or index >= p_inventory.size():
		return
	var item: Dictionary = p_inventory[index]
	var carpet := _find_free_carpet_tile()
	if carpet == Vector2i(-1, -1):
		add_message("置けるカーペットの空きがない。")
		return
	var price: int = ItemData.sell_price(item)
	# 装備中なら外す
	if p_weapon.get("_iid", -1) == item.get("_iid", -2) and not item.get("cursed", false):
		p_weapon = {}
	if p_shield.get("_iid", -1) == item.get("_iid", -2):
		p_shield = {}
	if p_ring.get("_iid", -1) == item.get("_iid", -2):
		p_ring = {}
	# ノードを作成して床に置く（shop_item として登録）
	var sym := ItemData.type_symbol(item.get("type", 0))
	var col := ItemData.type_color(item.get("type", 0))
	var node := _make_tile_node(sym, Color(0.15, 0.10, 0.05), col, 18)
	_entity_layer.add_child(node)
	node.call("set_grid", carpet.x, carpet.y)
	node.call("set_sprite", Assets.item_type_sprite(item.get("type", 0)))
	shop_items.append({"item": item, "price": price, "grid_pos": carpet, "node": node})
	p_inventory.remove_at(index)
	shop_sell_cursor = min(shop_sell_cursor, max(0, p_inventory.size() - 1))
	add_message("%s を %dG で売りに出した。" % [item.get("name", "?"), price])
	_play_se("coin")
	_refresh_hud()

func _handle_shop_input(kc: int) -> void:
	match kc:
		KEY_ESCAPE, KEY_I:
			game_state = "playing"
			_refresh_hud()
		KEY_TAB:
			# 購入 / 売却 タブ切り替え
			shop_mode = "sell" if shop_mode == "buy" else "buy"
			shop_cursor      = clamp(shop_cursor,      0, max(0, shop_items.size()    - 1))
			shop_sell_cursor = clamp(shop_sell_cursor, 0, max(0, p_inventory.size()   - 1))
			_refresh_hud()
		KEY_UP, KEY_K:
			if shop_mode == "buy":
				if shop_items.size() > 0:
					shop_cursor = max(0, shop_cursor - 1)
					_refresh_hud()
			else:
				if p_inventory.size() > 0:
					shop_sell_cursor = max(0, shop_sell_cursor - 1)
					_refresh_hud()
		KEY_DOWN, KEY_J:
			if shop_mode == "buy":
				if shop_items.size() > 0:
					shop_cursor = min(shop_items.size() - 1, shop_cursor + 1)
					_refresh_hud()
			else:
				if p_inventory.size() > 0:
					shop_sell_cursor = min(p_inventory.size() - 1, shop_sell_cursor + 1)
					_refresh_hud()
		KEY_ENTER, KEY_Z, KEY_KP_ENTER:
			if shop_mode == "buy":
				if shop_items.size() > 0:
					_try_buy(shop_cursor)
			else:
				_try_sell(shop_sell_cursor)

func _try_buy(index: int) -> void:
	if index < 0 or index >= shop_items.size():
		return
	var si: Dictionary = shop_items[index]
	var price: int     = si["price"]
	if p_gold < price:
		add_message("所持金が足りない。（%dG 必要 / 所持 %dG）" % [price, p_gold])
		return
	if p_inventory.size() >= MAX_INVENTORY:
		add_message("持ち物がいっぱいで買えない。")
		return
	p_gold -= price
	var item: Dictionary = si["item"].duplicate(true)
	p_inventory.append(item)
	si["node"].queue_free()
	shop_items.remove_at(index)
	shop_cursor = min(shop_cursor, max(0, shop_items.size() - 1))
	add_message("%s を %dG で購入した。（残金: %dG）" % [item.get("name", "?"), price, p_gold])
	_play_se("coin")
	if game_state == "shop":
		_refresh_hud()
	else:
		_end_player_turn()

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

	var kc := kev.keycode

	# リバインド待ち受け中
	if game_state == "rebinding":
		if kc == KEY_ESCAPE:
			_cancel_rebind()
		else:
			_finish_rebind(kc)
		return

	# ズーム操作はゲーム状態に関わらず有効
	if kc == key_bindings.get("zoom_in", KEY_EQUAL) or kc == KEY_KP_ADD:
		_zoom_index = min(_zoom_index + 1, ZOOM_LEVELS.size() - 1)
		_apply_zoom()
		return
	if kc == key_bindings.get("zoom_out", KEY_MINUS) or kc == KEY_KP_SUBTRACT:
		_zoom_index = max(_zoom_index - 1, 0)
		_apply_zoom()
		return

	match game_state:
		"playing":
			if kc == KEY_ESCAPE:
				_open_options()
				return
			if kc == KEY_M:
				show_minimap = not show_minimap
				_refresh_hud()
				return
			_handle_play_input(kc)
		"inventory":
			_handle_inv_input(kc)
		"storage_select":
			_handle_storage_input(kc)
		"shop":
			_handle_shop_input(kc)
		"options":
			if kc == KEY_ESCAPE:
				_close_options()
				return
		"dead", "victory":
			if kc == KEY_R:
				get_tree().reload_current_scene()

func _apply_zoom() -> void:
	var z: float = ZOOM_LEVELS[_zoom_index]
	_camera.zoom = Vector2(z, z)

func _handle_play_input(kc: int) -> void:
	var mod: int = key_bindings.get("diag_mod", KEY_SHIFT)

	# 斜め移動：モディファイア + 2方向キー同時押し
	# モディファイア押下中は通常移動を一切発火させない（桂馬移動防止）
	if Input.is_key_pressed(mod):
		var up_h    := Input.is_key_pressed(key_bindings.get("move_up",    KEY_UP))
		var down_h  := Input.is_key_pressed(key_bindings.get("move_down",  KEY_DOWN))
		var left_h  := Input.is_key_pressed(key_bindings.get("move_left",  KEY_LEFT))
		var right_h := Input.is_key_pressed(key_bindings.get("move_right", KEY_RIGHT))
		if   up_h   and left_h:  _try_player_move(Vector2i(-1, -1))
		elif up_h   and right_h: _try_player_move(Vector2i( 1, -1))
		elif down_h and left_h:  _try_player_move(Vector2i(-1,  1))
		elif down_h and right_h: _try_player_move(Vector2i( 1,  1))
		return  # 2方向揃っていない場合も含め、常にここで止める

	# 4方向移動・その他
	if   kc == key_bindings.get("move_left",  KEY_LEFT):  _try_player_move(Vector2i(-1,  0))
	elif kc == key_bindings.get("move_right", KEY_RIGHT): _try_player_move(Vector2i( 1,  0))
	elif kc == key_bindings.get("move_up",    KEY_UP):    _try_player_move(Vector2i( 0, -1))
	elif kc == key_bindings.get("move_down",  KEY_DOWN):  _try_player_move(Vector2i( 0,  1))
	elif kc == key_bindings.get("wait",       KEY_SPACE): _player_wait_or_descend()
	elif kc == key_bindings.get("inventory",  KEY_I):     _open_inventory()
	elif kc == key_bindings.get("pickup",     KEY_G):     _try_pickup()

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
	# 店員への移動 → 店を開く
	if not _shopkeeper.is_empty() and _shopkeeper["grid_pos"] == new_pos:
		_open_shop()
		return
	# 壁チェック
	if not generator.is_walkable(new_pos.x, new_pos.y):
		return
	# 移動
	p_grid = new_pos
	_player_node.call("set_grid", p_grid.x, p_grid.y)
	# 入店チェック（初回のみメッセージ）
	if generator.has_shop and not _shop_entered and generator.shop_room.has_point(p_grid):
		_shop_entered = true
		add_message("いらっしゃいませ！店員に話しかけると購入・売却ができます。カーペットに置いてから話しかけても売れます。")
	# 店アイテム踏んだ時：名前と価格を表示
	for si in shop_items:
		if si["grid_pos"] == p_grid:
			var pickup_key := OS.get_keycode_string(key_bindings.get("pickup", KEY_G))
			add_message("【%s】  %dG  [%s] で購入" % [si["item"].get("name", "?"), si["price"], pickup_key])
			break
	# アイテム自動拾い
	_auto_pickup()
	# 階段チェック
	if generator.get_tile(p_grid.x, p_grid.y) == DungeonGenerator.TILE_STAIRS:
		var descend_key := OS.get_keycode_string(key_bindings.get("wait", KEY_SPACE))
		add_message("階段を見つけた！ [%s] で降りる" % descend_key)
	_end_player_turn()

func _player_wait_or_descend() -> void:
	if generator.get_tile(p_grid.x, p_grid.y) == DungeonGenerator.TILE_STAIRS:
		_try_descend()
	else:
		add_message("その場で待機した。")
		_end_player_turn()

func _try_descend() -> void:
	if generator.get_tile(p_grid.x, p_grid.y) != DungeonGenerator.TILE_STAIRS:
		add_message("ここに階段はない。")
		return
	if current_floor >= MAX_FLOOR:
		_trigger_victory()
		return
	_play_se("stairs")
	current_floor += 1
	save_game()
	_start_new_floor()

func _try_pickup() -> void:
	# 店アイテムが足元にあれば購入
	for i in shop_items.size():
		if shop_items[i]["grid_pos"] == p_grid:
			_try_buy(i)
			return
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
	_collect_gold(p_grid)

func _collect_gold(pos: Vector2i) -> void:
	for pile in gold_piles:
		if (pile["grid_pos"] as Vector2i) == pos:
			p_gold += pile["amount"]
			add_message("お金を %d G 拾った。（所持金: %d G）" % [pile["amount"], p_gold])
			pile["node"].queue_free()
			gold_piles.erase(pile)
			_play_se("coin")
			return

func _pickup_item(fi: Dictionary) -> void:
	if p_inventory.size() >= MAX_INVENTORY:
		add_message("荷物がいっぱいで拾えない！")
		return
	var item: Dictionary = fi["item"]
	# インベントリ入りのタイミングで個体IDを付与（未付与の場合のみ）
	if not item.has("_iid"):
		item["_iid"] = _next_iid
		_next_iid += 1
	p_inventory.append(item)
	fi["node"].queue_free()
	floor_items.erase(fi)
	add_message("%s を拾った。" % item.get("name", "?"))
	_play_se("pickup")

func _end_player_turn() -> void:
	# 満腹度
	turn_count += 1
	if turn_count % HUNGER_RATE == 0:
		p_fullness = max(0, p_fullness - 1)
		if p_fullness == 0:
			_apply_damage_to_player(3, "空腹")
		elif p_fullness <= 10:
			add_message("お腹が減って苦しい…")
	# 自然回復（200ターンで最大HP分を回復。小数積み立て）
	if p_hp > 0 and p_hp < p_hp_max:
		_regen_accum += float(p_hp_max) / 200.0
		var regen_int := int(_regen_accum)
		if regen_int >= 1:
			p_hp = min(p_hp_max, p_hp + regen_int)
			_regen_accum -= float(regen_int)
	# 回復指輪
	if p_ring.get("effect", "") == "regen" and turn_count % 5 == 0:
		p_hp = min(p_hp_max, p_hp + 1)
	# 盲目カウントダウン
	if p_blind_turns > 0:
		p_blind_turns -= 1
		if p_blind_turns == 0:
			add_message("目が見えるようになった。")
	# 敵の追加スポーン（50ターンに1体、視界外）
	if turn_count % 50 == 0:
		_spawn_wandering_enemy()
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
	enemy["node"].call("flash", Color(1.0, 0.2, 0.2))
	_show_damage_number(enemy["grid_pos"] as Vector2i, str(dmg), Color(1.0, 0.4, 0.4))
	_play_se("attack")
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
	_player_node.call("flash", Color(1.0, 0.2, 0.2))
	_show_damage_number(p_grid, str(dmg), Color(1.0, 0.7, 0.7))
	_camera_shake()
	_play_se("hit")
	if source != "":
		add_message("%s から %d ダメージ！" % [source, dmg])
	if p_hp <= 0:
		p_hp = 0
		var cause: String
		if source == "空腹":
			cause = "餓死"
		elif source == "爆発の本":
			cause = "爆発の本で自滅"
		elif source != "":
			cause = "%s に倒された" % source
		else:
			cause = "力尽きた"
		_trigger_game_over(cause)

# ─── 敵ターン ─────────────────────────────────────────────
func _enemy_turns() -> void:
	for enemy in enemies.duplicate():   # duplicate でイテレート中の削除を安全に
		if not is_instance_valid(enemy.get("node")):
			continue
		_single_enemy_turn(enemy)

func _single_enemy_turn(enemy: Dictionary) -> void:
	# 一時的な睡眠・封印のカウントダウン
	if enemy.get("asleep_turns", 0) > 0:
		enemy["asleep_turns"] -= 1
		if enemy["asleep_turns"] <= 0:
			enemy["asleep"] = false
	if enemy.get("asleep", false):
		return

	# 毒DoT：毎ターン2ダメージ
	if enemy.get("poisoned", 0) > 0:
		enemy["poisoned"] -= 1
		enemy["hp"] -= 2
		enemy["node"].call("flash", Color(0.5, 1.0, 0.2))
		add_message("%s は毒で 2 ダメージ！" % enemy["data"]["name"])
		if enemy["hp"] <= 0:
			_kill_enemy(enemy)
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
			if p_weapon.get("_iid", -1) == item.get("_iid", -2):
				p_weapon = {}
				add_message("%s を外した。" % item.get("name","?"))
			else:
				if item.get("cursed", false):
					add_message("呪われた剣を装備した！外せない…")
				p_weapon = item
				add_message("%s を装備した。" % item.get("name","?"))
			return false   # インベントリに残す

		ItemData.TYPE_SHIELD:
			if p_shield.get("_iid", -1) == item.get("_iid", -2):
				p_shield = {}
				add_message("%s を外した。" % item.get("name","?"))
			else:
				p_shield = item
				add_message("%s を装備した。" % item.get("name","?"))
			return false

		ItemData.TYPE_RING:
			if p_ring.get("_iid", -1) == item.get("_iid", -2):
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
			if item.get("effect", "") == "storage":
				return _apply_pot_storage(item)
			_apply_pot(item)
			var uses: int = item.get("uses", 1) - 1
			if uses <= 0:
				return true
			item["uses"] = uses
			return false

		ItemData.TYPE_STAFF:
			_apply_staff(item)
			var uses: int = item.get("uses", 1) - 1
			if uses <= 0:
				add_message("%s は砕け散った。" % item.get("name","?"))
				return true
			item["uses"] = uses
			return false

	return true

func _apply_scroll(item: Dictionary) -> void:
	var effect: String = item.get("effect", "")
	add_message("本を読んだ！（%s）" % item.get("name","?"))
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
			_apply_damage_to_player(randi_range(3, 8), "爆発の本")
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

## ターン経過による追加スポーン（視界外のランダム位置に1体）
func _spawn_wandering_enemy() -> void:
	var pool := EnemyData.for_floor(current_floor)
	if pool.is_empty():
		return
	# 視界外・プレイヤー位置・既存敵と重複しない位置を探す（最大10回）
	var occupied: Array = [p_grid]
	for e in enemies:
		occupied.append(e["grid_pos"] as Vector2i)
	for _attempt in 10:
		var pos := generator.random_floor_pos()
		if pos in occupied:
			continue
		if fov_visible.has(pos):
			continue
		var data: Dictionary = pool[randi() % pool.size()].duplicate(true)
		var node := _make_tile_node(data["symbol"], data["color"])
		node.z_index = 1
		_entity_layer.add_child(node)
		node.call("set_grid", pos.x, pos.y)
		node.call("set_sprite", Assets.enemy_sprite(data.get("id", "")))
		enemies.append({
			"data": data, "hp": data["hp"],
			"grid_pos": pos, "node": node,
			"asleep": false, "alerted": false,
		})
		return   # 1体沸いたら終了

func _spawn_one_enemy_near_player() -> void:
	var pool := EnemyData.for_floor(current_floor)
	if pool.is_empty():
		return
	var pos := generator.random_floor_pos()
	var data: Dictionary = pool[randi() % pool.size()].duplicate(true)
	var node := _make_tile_node(data["symbol"], data["color"])
	node.z_index = 1
	_entity_layer.add_child(node)
	node.call("set_grid", pos.x, pos.y)
	enemies.append({
		"data": data, "hp": data["hp"],
		"grid_pos": pos, "node": node,
		"asleep": false, "alerted": true,
	})

func _apply_pot(item: Dictionary) -> void:
	var effect: String = item.get("effect", "")
	add_message("箱を使った！（%s）" % item.get("name","?"))
	match effect:
		"heal":
			var heal := randi_range(15, 30)
			p_hp = min(p_hp_max, p_hp + heal)
			add_message("HP が %d 回復した。" % heal)
		"poison":
			var hit_count := 0
			for enemy in enemies:
				if fov_visible.has(enemy["grid_pos"] as Vector2i):
					enemy["poisoned"] = 8
					enemy["node"].call("flash", Color(0.5, 1.0, 0.2))
					add_message("%s に毒を浴びせた！" % enemy["data"]["name"])
					hit_count += 1
			if hit_count == 0:
				add_message("しかし周囲に敵はいない。")
		"strength":
			p_atk_base += 3
			add_message("力が 3 上がった！")
		"blind":
			p_blind_turns = 10
			add_message("目の前が真っ暗になった！（10ターン視界1）")

## 保存の箱：中身があれば取り出し、空ならしまうモードへ移行
func _apply_pot_storage(item: Dictionary) -> bool:
	var contents: Array = item.get("contents", [])
	if not contents.is_empty():
		add_message("箱からアイテムを取り出した！")
		for stored in contents:
			if p_inventory.size() < MAX_INVENTORY:
				p_inventory.append(stored)
				add_message("  %s を取り出した。" % stored.get("name", "?"))
			else:
				_place_floor_item(stored, p_grid)
				add_message("  %s は荷物がいっぱいで床に落ちた。" % stored.get("name", "?"))
		return true   # 箱を消費
	# 空箱：しまう操作モードへ
	_storage_pot_iid = item.get("_iid", -1)
	game_state = "storage_select"
	add_message("何をしまいますか？ [Enter/Z] しまう  [Esc] キャンセル")
	_refresh_hud()
	return false   # インベントリに残す

## 保存の箱しまうモードの入力処理
func _handle_storage_input(kc: int) -> void:
	match kc:
		KEY_ESCAPE:
			game_state = "playing"
			add_message("キャンセルした。")
			_refresh_hud()
			return
		KEY_UP, KEY_K:
			inv_cursor = max(0, inv_cursor - 1)
			_refresh_hud()
			return
		KEY_DOWN, KEY_J:
			inv_cursor = min(p_inventory.size() - 1, inv_cursor + 1)
			_refresh_hud()
			return
		KEY_ENTER, KEY_Z, KEY_KP_ENTER:
			pass   # 以下で処理
		_:
			return

	# 選択アイテムを箱に入れる
	inv_cursor = clamp(inv_cursor, 0, p_inventory.size() - 1)
	var target_item: Dictionary = p_inventory[inv_cursor]
	# 箱自身は入れられない
	if target_item.get("_iid", -2) == _storage_pot_iid:
		add_message("箱に箱は入れられない。")
		return
	# 装備中は入れられない
	if p_weapon.get("_iid", -1) == target_item.get("_iid", -2) \
			or p_shield.get("_iid", -1) == target_item.get("_iid", -2) \
			or p_ring.get("_iid",   -1) == target_item.get("_iid", -2):
		add_message("装備中のアイテムはしまえない。")
		return
	# 箱を探してcontentsに追加
	for pot in p_inventory:
		if pot.get("_iid", -1) == _storage_pot_iid:
			if not pot.has("contents"):
				pot["contents"] = []
			pot["contents"].append(target_item)
			p_inventory.remove_at(inv_cursor)
			inv_cursor = min(inv_cursor, p_inventory.size() - 1)
			add_message("%s を箱にしまった。" % target_item.get("name", "?"))
			break
	game_state = "playing"
	_end_player_turn()
	_refresh_hud()

func _apply_staff(item: Dictionary) -> void:
	var effect: String = item.get("effect", "")
	add_message("%s を振った！" % item.get("name","?"))
	match effect:
		"fire":
			var target = _nearest_visible_enemy()
			if target == null:
				add_message("しかし周囲に敵はいない。")
				return
			var dmg := randi_range(20, 35)
			target["hp"] -= dmg
			add_message("%s に炎が燃え上がった！%d ダメージ！" % [target["data"]["name"], dmg])
			if target["hp"] <= 0:
				_kill_enemy(target)

		"thunder":
			var hit := false
			for enemy in enemies.duplicate():
				if fov_visible.has(enemy["grid_pos"] as Vector2i):
					var dmg := randi_range(10, 18)
					enemy["hp"] -= dmg
					add_message("%s に雷が落ちた！%d ダメージ！" % [enemy["data"]["name"], dmg])
					if enemy["hp"] <= 0:
						_kill_enemy(enemy)
					hit = true
			if not hit:
				add_message("しかし周囲に敵はいない。")

		"freeze":
			var hit := false
			for enemy in enemies:
				if fov_visible.has(enemy["grid_pos"] as Vector2i):
					enemy["asleep"]       = true
					enemy["asleep_turns"] = 3
					add_message("%s が凍りついた！" % enemy["data"]["name"])
					hit = true
			if not hit:
				add_message("しかし周囲に敵はいない。")

		"knockback":
			var target = _nearest_visible_enemy()
			if target == null:
				add_message("しかし周囲に敵はいない。")
				return
			_knockback_enemy(target, 5)
			add_message("%s を吹き飛ばした！" % target["data"]["name"])

		"seal":
			var target = _nearest_visible_enemy()
			if target == null:
				add_message("しかし周囲に敵はいない。")
				return
			target["asleep"]       = true
			target["asleep_turns"] = 5
			add_message("%s を封印した！" % target["data"]["name"])

		"magic":
			var target = _nearest_visible_enemy()
			if target == null:
				add_message("しかし周囲に敵はいない。")
				return
			target["hp"] = max(1, target["hp"] / 2)
			add_message("%s のHPが半分になった！" % target["data"]["name"])

## 視界内で最も近い敵を返す
func _nearest_visible_enemy() -> Variant:
	var best: Variant = null
	var best_dist: int = 999999
	for enemy in enemies:
		var ep := enemy["grid_pos"] as Vector2i
		if fov_visible.has(ep):
			var d: int = ep.distance_squared_to(p_grid)
			if d < best_dist:
				best_dist = d
				best      = enemy
	return best

## 敵をプレイヤーから遠ざける方向に steps マス押し飛ばす
func _knockback_enemy(enemy: Dictionary, steps: int) -> void:
	var diff := (enemy["grid_pos"] as Vector2i) - p_grid
	var dx: int = sign(diff.x)
	var dy: int = sign(diff.y)
	if dx == 0 and dy == 0:
		return
	for _i in steps:
		var np := (enemy["grid_pos"] as Vector2i) + Vector2i(dx, dy)
		if np.x < 0 or np.x >= DungeonGenerator.MAP_W \
				or np.y < 0 or np.y >= DungeonGenerator.MAP_H:
			break
		if not generator.is_walkable(np.x, np.y):
			break
		if _enemy_at(np) != null:
			break
		enemy["grid_pos"] = np
		enemy["node"].call("set_grid", np.x, np.y)

## アイテムが置かれていない最寄りの床タイルを返す（見つからなければ Vector2i(-1,-1)）
func _find_free_drop_pos(origin: Vector2i) -> Vector2i:
	var occupied: Array = []
	for fi in floor_items:
		occupied.append(fi["grid_pos"] as Vector2i)
	for si in shop_items:
		occupied.append(si["grid_pos"] as Vector2i)

	# 足元 → 8近傍の順で探す
	var candidates: Array = [origin]
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			candidates.append(origin + Vector2i(dx, dy))

	for pos: Vector2i in candidates:
		if not generator.is_walkable(pos.x, pos.y):
			continue
		if pos in occupied:
			continue
		return pos
	return Vector2i(-1, -1)

func _drop_selected_item() -> void:
	if p_inventory.is_empty():
		return
	inv_cursor = clamp(inv_cursor, 0, p_inventory.size() - 1)
	var item: Dictionary = p_inventory[inv_cursor]

	var drop_pos := _find_free_drop_pos(p_grid)
	if drop_pos == Vector2i(-1, -1):
		add_message("周囲に捨てる場所がない。")
		return

	# 装備中なら外す（_iid で個体一致を確認）
	if p_weapon.get("_iid", -1) == item.get("_iid", -2) and not item.get("cursed", false):
		p_weapon = {}
	if p_shield.get("_iid", -1) == item.get("_iid", -2):
		p_shield = {}
	if p_ring.get("_iid", -1) == item.get("_iid", -2):
		p_ring = {}
	_place_floor_item(item, drop_pos)
	p_inventory.remove_at(inv_cursor)
	inv_cursor = min(inv_cursor, p_inventory.size() - 1)
	var loc_msg := "足元に" if drop_pos == p_grid else "近くに"
	add_message("%s を%s捨てた。" % [item.get("name","?"), loc_msg])
	if p_inventory.is_empty():
		game_state = "playing"
	_refresh_hud()

# ─── FOV（視野計算）──────────────────────────────────────
func _update_fov() -> void:
	fov_visible.clear()
	var radius := FOV_RADIUS
	if p_blind_turns > 0:
		radius = 1
	elif p_ring.get("effect", "") == "detection":
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
	# ゴールド：探索済みなら表示
	for pile in gold_piles:
		pile["node"].visible = explored.has(pile["grid_pos"] as Vector2i)
	# 店員・店アイテム：探索済みなら表示
	if not _shopkeeper.is_empty():
		_shopkeeper["node"].visible = explored.has(_shopkeeper["grid_pos"] as Vector2i)
	for si in shop_items:
		si["node"].visible = explored.has(si["grid_pos"] as Vector2i)

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
func _trigger_game_over(cause: String = "") -> void:
	death_cause = cause
	game_state  = "dead"
	delete_save()   # ローグライク：死んだらセーブ削除
	add_message("あなたは倒れた…")
	_refresh_hud()

func _trigger_victory() -> void:
	game_state = "victory"
	delete_save()   # クリア後もセーブ削除
	add_message("古代の守護者を倒し、遺産を持ち帰った！")
	_refresh_hud()

# ─── セーブ・ロード ───────────────────────────────────────
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("save.json")

func save_game() -> void:
	# タイルマップをフラット配列化
	var tiles_flat: Array = []
	for y in DungeonGenerator.MAP_H:
		for x in DungeonGenerator.MAP_W:
			tiles_flat.append(generator.map[y][x])

	# 探索済みタイル
	var explored_arr: Array = []
	for pos: Vector2i in explored:
		explored_arr.append([pos.x, pos.y])

	# 敵
	var enemies_arr: Array = []
	for enemy in enemies:
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
		})

	# フロアアイテム
	var items_arr: Array = []
	for fi in floor_items:
		items_arr.append({
			"item":   fi["item"].duplicate(true),
			"grid_x": fi["grid_pos"].x,
			"grid_y": fi["grid_pos"].y,
		})

	# 金山
	var gold_arr: Array = []
	for gp in gold_piles:
		gold_arr.append({
			"amount": gp["amount"],
			"grid_x": gp["grid_pos"].x,
			"grid_y": gp["grid_pos"].y,
		})

	# 店アイテム
	var shop_arr: Array = []
	for si in shop_items:
		shop_arr.append({
			"item":   si["item"].duplicate(true),
			"price":  si["price"],
			"grid_x": si["grid_pos"].x,
			"grid_y": si["grid_pos"].y,
		})
	var shopkeeper_data := {}
	if not _shopkeeper.is_empty():
		shopkeeper_data = {
			"grid_x": _shopkeeper["grid_pos"].x,
			"grid_y": _shopkeeper["grid_pos"].y,
		}

	var data := {
		"version":        1,
		"turn_count":     turn_count,
		"current_floor":  current_floor,
		"elapsed_msec":   Time.get_ticks_msec() - _start_time_msec,
		"next_iid":       _next_iid,
		"player": {
			"hp":          p_hp,
			"hp_max":      p_hp_max,
			"atk_base":    p_atk_base,
			"def_base":    p_def_base,
			"level":       p_level,
			"exp":         p_exp,
			"exp_next":    p_exp_next,
			"fullness":    p_fullness,
			"gold":        p_gold,
			"blind_turns": p_blind_turns,
			"regen_accum": _regen_accum,
			"grid_x":      p_grid.x,
			"grid_y":      p_grid.y,
			"weapon":      p_weapon.duplicate(true),
			"shield":      p_shield.duplicate(true),
			"ring":        p_ring.duplicate(true),
			"inventory":   p_inventory.duplicate(true),
		},
		"map_tiles":      tiles_flat,
		"player_start_x": generator.player_start.x,
		"player_start_y": generator.player_start.y,
		"stairs_x":       generator.stairs_pos.x,
		"stairs_y":       generator.stairs_pos.y,
		"explored":       explored_arr,
		"enemies":        enemies_arr,
		"floor_items":    items_arr,
		"gold_piles":     gold_arr,
		"shop_items":     shop_arr,
		"shopkeeper":     shopkeeper_data,
		"has_shop":       generator.has_shop,
		"shop_room":      [generator.shop_room.position.x, generator.shop_room.position.y,
						   generator.shop_room.size.x,     generator.shop_room.size.y],
		"shop_entered":   _shop_entered,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> bool:
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

	# プレイヤーステータス復元
	var pd: Dictionary = data["player"]
	p_hp          = int(pd["hp"])
	p_hp_max      = int(pd["hp_max"])
	p_atk_base    = int(pd["atk_base"])
	p_def_base    = int(pd["def_base"])
	p_level       = int(pd["level"])
	p_exp         = int(pd["exp"])
	p_exp_next    = int(pd["exp_next"])
	p_fullness    = int(pd["fullness"])
	p_gold        = int(pd["gold"])
	p_blind_turns = int(pd["blind_turns"])
	_regen_accum  = float(pd["regen_accum"])
	p_grid        = Vector2i(int(pd["grid_x"]), int(pd["grid_y"]))
	p_weapon      = pd.get("weapon", {})
	p_shield      = pd.get("shield", {})
	p_ring        = pd.get("ring",   {})
	p_inventory   = pd.get("inventory", [])
	turn_count    = int(data["turn_count"])
	current_floor = int(data["current_floor"])
	_next_iid     = int(data.get("next_iid", 0))
	_start_time_msec = Time.get_ticks_msec() - int(data.get("elapsed_msec", 0))

	# マップ復元
	generator = DungeonGenerator.new()
	generator.load_map_data(
		data["map_tiles"],
		int(data["player_start_x"]), int(data["player_start_y"]),
		int(data["stairs_x"]),       int(data["stairs_y"]))

	# 探索済みタイル復元
	explored.clear()
	for pair in data["explored"]:
		explored[Vector2i(int(pair[0]), int(pair[1]))] = true

	# エンティティクリア
	for ch in _entity_layer.get_children():
		ch.queue_free()
	enemies.clear()
	floor_items.clear()
	gold_piles.clear()
	fov_visible.clear()

	# マップ描画
	_map_drawer.call("setup", generator, fov_visible, explored)

	# プレイヤーノード
	_player_node = _make_tile_node("@", Color(0.10, 0.28, 0.80))
	_player_node.z_index = 1
	_entity_layer.add_child(_player_node)
	_player_node.call("set_grid", p_grid.x, p_grid.y)
	_player_node.call("set_sprite", Assets.PLAYER)

	# 敵復元
	for ed in data["enemies"]:
		var base_data: Dictionary = EnemyData.get_by_id(ed["id"])
		if base_data.is_empty():
			continue
		var node := _make_tile_node(base_data["symbol"], base_data["color"])
		node.z_index = 1
		_entity_layer.add_child(node)
		var pos := Vector2i(int(ed["grid_x"]), int(ed["grid_y"]))
		node.call("set_grid", pos.x, pos.y)
		node.call("set_sprite", Assets.enemy_sprite(base_data.get("id", "")))
		enemies.append({
			"data":         base_data,
			"hp":           int(ed["hp"]),
			"grid_pos":     pos,
			"node":         node,
			"alerted":      bool(ed.get("alerted", false)),
			"asleep":       bool(ed.get("asleep", false)),
			"asleep_turns": int(ed.get("asleep_turns", 0)),
			"poisoned":     int(ed.get("poisoned", 0)),
			"sealed":       bool(ed.get("sealed", false)),
		})

	# フロアアイテム復元
	for fi in data["floor_items"]:
		var item: Dictionary = fi["item"].duplicate(true)
		var pos := Vector2i(int(fi["grid_x"]), int(fi["grid_y"]))
		_place_floor_item(item, pos)

	# 金山復元
	for gp in data["gold_piles"]:
		var pos := Vector2i(int(gp["grid_x"]), int(gp["grid_y"]))
		_place_gold_pile(int(gp["amount"]), pos)

	# 店復元
	shop_items.clear()
	_shopkeeper   = {}
	_shop_entered = bool(data.get("shop_entered", false))
	generator.has_shop = bool(data.get("has_shop", false))
	var sr: Array = data.get("shop_room", [0,0,0,0])
	generator.shop_room = Rect2i(int(sr[0]), int(sr[1]), int(sr[2]), int(sr[3]))
	var sk_data: Dictionary = data.get("shopkeeper", {})
	if not sk_data.is_empty():
		var sk_pos := Vector2i(int(sk_data["grid_x"]), int(sk_data["grid_y"]))
		generator.shop_keeper_pos = sk_pos
		var sk_node := _make_tile_node("店", Color(0.15, 0.10, 0.05), Color(1.0, 0.85, 0.1), 14)
		sk_node.z_index = 1
		_entity_layer.add_child(sk_node)
		sk_node.call("set_grid", sk_pos.x, sk_pos.y)
		sk_node.call("set_sprite", Assets.SHOP_KEEPER)
		_shopkeeper = {"grid_pos": sk_pos, "node": sk_node}
	for si in data.get("shop_items", []):
		var item: Dictionary = si["item"].duplicate(true)
		var pos  := Vector2i(int(si["grid_x"]), int(si["grid_y"]))
		var price: int = int(si["price"])
		var sym: String = ItemData.type_symbol(item.get("type", 0))
		var col: Color  = ItemData.type_color(item.get("type", 0))
		var node := _make_tile_node(sym, Color(0.15, 0.10, 0.05), col, 18)
		_entity_layer.add_child(node)
		node.call("set_grid", pos.x, pos.y)
		node.call("set_sprite", Assets.item_type_sprite(item.get("type", 0)))
		shop_items.append({"item": item, "price": price, "grid_pos": pos, "node": node})

	# FOV・カメラ・HUD
	_update_fov()
	_sync_entity_visibility()
	_update_camera()
	_refresh_hud()
	_play_bgm("explore")
	add_message("セーブデータを読み込みました。（B%dF / Turn%d）" % [current_floor, turn_count])
	return true

# ─── BGM ─────────────────────────────────────────────────
func _play_bgm(key: String) -> void:
	if not BGM.has(key):
		return
	var path: String = BGM[key]
	if not ResourceLoader.exists(path):
		return
	# 同じ曲が再生中なら何もしない
	var stream := load(path) as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	_bgm_player.stream    = stream
	_bgm_player.volume_db = _linear_to_db_safe(vol_bgm)
	_bgm_player.play()

func _stop_bgm() -> void:
	_bgm_player.stop()

# ─── オプション ───────────────────────────────────────────
func _build_options_panel() -> void:
	_options_layer = CanvasLayer.new()
	_options_layer.layer   = 10
	_options_layer.visible = false
	add_child(_options_layer)

	# 背景オーバーレイ
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_options_layer.add_child(overlay)

	# パネル本体（中央固定）
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(500, 440)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left   = -250.0
	panel.offset_top    = -220.0
	panel.offset_right  =  250.0
	panel.offset_bottom =  220.0
	_options_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "─── オプション ───"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)

	# タブコンテナ
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tabs)

	# ── タブ1: 音量設定 ──
	var vol_container := VBoxContainer.new()
	vol_container.name = "音量設定"
	vol_container.add_theme_constant_override("separation", 14)
	tabs.add_child(vol_container)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vol_container.add_child(spacer)

	_lbl_master_pct = _add_volume_row(vol_container, "マスター音量", vol_master, func(v: float) -> void:
		vol_master = v
		_lbl_master_pct.text = "%d%%" % int(v * 100)
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Master"), _linear_to_db_safe(vol_master))
	)
	_lbl_bgm_pct = _add_volume_row(vol_container, "BGM 音量", vol_bgm, func(v: float) -> void:
		vol_bgm = v
		_lbl_bgm_pct.text = "%d%%" % int(v * 100)
		if is_instance_valid(_bgm_player):
			_bgm_player.volume_db = _linear_to_db_safe(vol_bgm)
	)
	_lbl_se_pct = _add_volume_row(vol_container, "SE 音量", vol_se, func(v: float) -> void:
		vol_se = v
		_lbl_se_pct.text = "%d%%" % int(v * 100)
	)

	# ── タブ2: キーコンフィグ ──
	var key_outer := VBoxContainer.new()
	key_outer.name = "キーコンフィグ"
	key_outer.add_theme_constant_override("separation", 6)
	tabs.add_child(key_outer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	key_outer.add_child(scroll)

	var key_vbox := VBoxContainer.new()
	key_vbox.add_theme_constant_override("separation", 4)
	key_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(key_vbox)

	for action: String in KEY_ACTIONS:
		_add_key_row(key_vbox, action)

	var reset_btn := Button.new()
	reset_btn.text = "デフォルトに戻す"
	reset_btn.pressed.connect(_reset_key_bindings)
	key_outer.add_child(reset_btn)

	# 閉じるボタン
	var close_btn := Button.new()
	close_btn.text = "閉じる  [ Esc ]"
	close_btn.pressed.connect(_close_options)
	vbox.add_child(close_btn)

## スライダー行を生成して追加。パーセント表示ラベルを返す
func _add_volume_row(parent: Control, label_text: String,
		initial: float, on_change: Callable) -> Label:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(110, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step      = 0.01
	slider.value     = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)

	var pct := Label.new()
	pct.text = "%d%%" % int(initial * 100)
	pct.custom_minimum_size    = Vector2(44, 0)
	pct.horizontal_alignment   = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_font_size_override("font_size", 14)
	hbox.add_child(pct)

	slider.value_changed.connect(on_change)
	return pct

## キーコンフィグ行を生成する
func _add_key_row(parent: Control, action: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = KEY_ACTIONS[action]["label"]
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)

	var btn := Button.new()
	btn.text = OS.get_keycode_string(key_bindings.get(action, 0))
	btn.custom_minimum_size = Vector2(160, 0)
	btn.name = "keybind_" + action
	btn.pressed.connect(_start_rebind.bind(action, btn))
	hbox.add_child(btn)

## リバインド開始
func _start_rebind(action: String, btn: Button) -> void:
	_rebinding_action = action
	_rebind_button    = btn
	btn.text          = "--- 押してください ---"
	game_state        = "rebinding"

## リバインド確定
func _finish_rebind(kc: int) -> void:
	key_bindings[_rebinding_action] = kc
	_rebind_button.text = OS.get_keycode_string(kc)
	_rebinding_action   = ""
	_rebind_button      = null
	game_state          = "options"

## リバインドキャンセル（Esc）
func _cancel_rebind() -> void:
	if _rebind_button != null:
		_rebind_button.text = OS.get_keycode_string(
			key_bindings.get(_rebinding_action, 0))
	_rebinding_action = ""
	_rebind_button    = null
	game_state        = "options"

## キーバインドをデフォルトに戻す
func _reset_key_bindings() -> void:
	for action: String in KEY_ACTIONS:
		key_bindings[action] = KEY_ACTIONS[action]["default"]
	# ボタン表示を更新
	for action: String in KEY_ACTIONS:
		var btn := _options_layer.find_child("keybind_" + action, true, false) as Button
		if btn:
			btn.text = OS.get_keycode_string(key_bindings[action])

func _open_options() -> void:
	_options_layer.visible = true
	game_state = "options"

func _close_options() -> void:
	_options_layer.visible = false
	game_state = "playing"

func _linear_to_db_safe(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return linear_to_db(linear)

## SE を再生する（同時に複数鳴らせるよう都度プレイヤーを生成）
## 自然終了 または 最大 3 秒で停止・解放する
func _play_se(key: String) -> void:
	if not SE.has(key):
		return
	var path: String = SE[key]
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream    = load(path) as AudioStream
	player.volume_db = _linear_to_db_safe(vol_se)
	player.play()
	# 自然終了時に解放
	player.finished.connect(player.queue_free)
	# 3秒タイムアウト（長い効果音の強制停止）
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)

# ─── 演出 ────────────────────────────────────────────────
## ダメージ数字をグリッド座標に浮かせて表示
func _show_damage_number(grid_pos: Vector2i, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.position = Vector2(
		grid_pos.x * TILE_SIZE + TILE_SIZE * 0.25,
		grid_pos.y * TILE_SIZE - 4.0
	)
	_entity_layer.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 20.0, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)

## カメラを短時間揺らす
func _camera_shake(intensity: float = 3.0, duration: float = 0.22) -> void:
	var tw := create_tween()
	var steps := 5
	for _i in steps:
		var off := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tw.tween_property(_camera, "offset", off, duration / steps)
	tw.tween_property(_camera, "offset", Vector2.ZERO, 0.04)

# ─── ユーティリティ ───────────────────────────────────────
func calc_atk() -> int:
	return p_atk_base + p_weapon.get("atk", 0) + p_ring.get("atk", 0)

func calc_def() -> int:
	return p_def_base + p_shield.get("def", 0) + p_ring.get("def", 0)

func add_message(text: String) -> void:
	messages.append(text)
	if messages.size() > 30:
		messages.remove_at(0)
	if is_instance_valid(_hud):
		_hud.queue_redraw()

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
