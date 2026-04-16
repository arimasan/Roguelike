extends Node2D
## ローグライクゲーム メインコントローラー

# ─── 定数 ─────────────────────────────────────────────────
const TILE_SIZE     := 32
const MAX_FLOOR     := 50
const MAX_INVENTORY := 20
const FOV_RADIUS    := 7
const FOV_MODE_CLASSIC := 0   # ①通路=周囲1マス、部屋=全体照明
const FOV_MODE_SCREEN  := 1   # ②画面内全タイル表示
const HUNGER_RATE   := 15   # 何ターンごとに満腹度-1か

# ─── ゲーム状態 ───────────────────────────────────────────
var game_state: String = "playing"   # playing / inventory / dead / victory

# ─── フロア・マップ ───────────────────────────────────────
var current_floor: int = 1
var turn_count:    int = 0
var generator:     DungeonGenerator = null
var explored:    Dictionary = {}   # Vector2i → true
var fov_visible: Dictionary = {}   # Vector2i → true  ※CanvasItem.visible と衝突を避けるため改名
var fov_mode:    int        = FOV_MODE_CLASSIC   # 現在のFOVモード

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
var p_facing:   Vector2i = Vector2i(1, 0)   # プレイヤーの向き（投擲方向の初期値）
var p_weapon:   Dictionary = {}
var p_shield:   Dictionary = {}
var p_ring:     Dictionary = {}
var p_inventory: Array = []
var p_gold:      int   = 0
var p_blind_turns:     int  = 0     # 盲目ターン残数（視野半径1）
var p_poisoned_turns:  int  = 0     # 毒ターン残数（毎ターン1ダメージ）
var p_sleep_turns:     int  = 0     # 睡眠ターン残数（行動不能）
var p_slow_turns:      int  = 0     # 鈍足ターン残数（2ターンに1回行動）
var p_confused_turns:  int  = 0     # 混乱ターン残数（移動方向ランダム）
var p_paralyzed_turns: int  = 0     # 麻痺ターン残数（完全行動不能）
var _p_slow_skip:      bool = false # 鈍足：次の行動をスキップするか
var _regen_accum:   float = 0.0     # 自然回復の積み立て
var _hunger_accum:  float = 0.0     # 空腹ダメージの積み立て

# ─── エンティティ ─────────────────────────────────────────
# enemies: Array of { "data": dict, "hp": int, "grid_pos": V2i,
#                     "node": Node2D, "asleep": bool, "alerted": bool }
var enemies:     Array = []
# companions: Array of { "data": dict, "hp": int, "grid_pos": V2i, "node": Node2D }
##   仲間：プレイヤーに追従し敵を攻撃する。同時最大 MAX_COMPANIONS 体。
var companions: Array = []
const MAX_COMPANIONS: int = 3
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
var _storage_pot_iid: int = -1   # 操作中の箱の _iid
var storage_cursor:   int =  0   # 箱の中身リスト上のカーソル

# ─── インベントリ：アクションメニュー ─────────────────────
# アクションリスト要素: [action_id: String, label: String]
var action_cursor:  int   = 0
var _action_list:   Array = []

# ─── 投擲の狙い ──────────────────────────────────────────
var _aim_dir:       Vector2i = Vector2i(1, 0)
var _aim_item_idx:  int      = -1     # p_inventory 内のインデックス（足元投擲時は未使用）
var _aim_is_shoot:  bool     = false
var _aim_from_floor: bool    = false  # true なら p_grid の floor_item を投擲する
var _aim_node:      Node2D   = null

# ─── 斜め移動ヒント矢印（diag_mod 押下時に4方向へ点滅表示） ──
var _diag_arrows: Array = []   # Node2D x4
var _diag_shown:  bool  = false

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
var _in_shop_area:    bool       = false   # 現在店内にいるか（BGM・メッセージ切り替え用）
var _shop_traded:     bool       = false   # この滞在中に売買したか（退店メッセージ用）
var _shop_entered:    bool       = false   # 入店メッセージ表示済みフラグ（旧・使用継続）

# ─── モンスターハウス ──────────────────────────────────────
# traps: Array of { "type": String, "grid_pos": V2i, "node": Node2D, "triggered": bool }
var traps:                   Array = []
var _monster_house_triggered: bool = false

# ─── ダッシュ中断フラグ ──────────────────────────────────
# ダッシュの1ステップ中に「プレイヤーに何かが起きた」ことを通知するフラグ。
# Combat.apply_damage_to_player / ItemEffects.apply_status_to_player が true を立てる。
# _try_player_move のダッシュ続行判定で確認して停止。各ステップ開始時にリセット。
var _dash_interrupt: bool = false

# ─── セーブ ───────────────────────────────────────────────
## セーブ／ロードロジックは SaveLoad（scripts/save_load.gd）に分離。
## パスやフォーマット管理もそちら。

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
var _options_layer:  CanvasLayer = null
var _confirm_layer:  CanvasLayer = null   # 諦め確認ダイアログ
var debug_mode:      bool        = true    # F12 でトグル。図鑑内に「生成する」ボタンを表示
var _bestiary_layer: CanvasLayer = null   # 図鑑画面
var _bestiary_tabs:  TabContainer = null
var _bestiary_enemy_list:   ItemList    = null
var _bestiary_enemy_detail: RichTextLabel = null
var _bestiary_enemy_sprite: TextureRect = null
var _bestiary_enemy_btn:    Button      = null
var _bestiary_item_list:    ItemList    = null
var _bestiary_item_detail:  RichTextLabel = null
var _bestiary_item_sprite:  TextureRect = null
var _bestiary_item_btn:     Button      = null
var _bestiary_trap_list:    ItemList    = null
var _bestiary_trap_detail:  RichTextLabel = null
var _bestiary_trap_sprite:  TextureRect = null
var _bestiary_trap_btn:     Button      = null
# ─── 会話イベント ───────────────────────────────────────
var _dialog_layer:    CanvasLayer  = null
var _dialog_speaker:  Label         = null
var _dialog_body:     RichTextLabel = null
var _dialog_hint:     Label         = null
var _dialog_lines:    Array         = []
var _dialog_idx:      int           = 0
var _dialog_choices:  Array         = []
var _dialog_callback: Callable      = Callable()
var _lbl_master_pct:    Label   = null
var _lbl_bgm_pct:       Label   = null
var _lbl_se_pct:        Label   = null
var _slider_master:     HSlider = null
var _slider_bgm:        HSlider = null
var _slider_se:         HSlider = null

# ─── 音量設定 ────────────────────────────────────────────
var vol_master: float = 1.0
var vol_bgm:    float = 1.0
var vol_se:     float = 1.0

# ─── キーコンフィグ ──────────────────────────────────────
const KEY_ACTIONS: Dictionary = {
	"move_up":    {"label": "上移動",             "default": KEY_UP},
	"move_down":  {"label": "下移動",             "default": KEY_DOWN},
	"move_left":  {"label": "左移動",             "default": KEY_LEFT},
	"move_right": {"label": "右移動",             "default": KEY_RIGHT},
	"diag_mod":   {"label": "斜め移動モディファイア", "default": KEY_SHIFT},
	"dash":       {"label": "ダッシュ",            "default": KEY_CTRL},
	"idash":      {"label": "i-ダッシュ（便利移動）", "default": KEY_TAB},
	"bestiary":   {"label": "図鑑",                 "default": KEY_Z},
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
	"explore":       "res://assets/bgm/explore.mp3",
	"shop":          "res://assets/bgm/shop.mp3",
	"monster_house": "res://assets/bgm/monster_house.mp3",
	# "boss":        "res://assets/bgm/boss.mp3",
	# "gameover":    "res://assets/bgm/gameover.mp3",
	# "victory":     "res://assets/bgm/victory.mp3",
}

# ─── SE パス定義 ─────────────────────────────────────────
## 効果音を差し替える際はここのパスを変更する（素材：効果音ラボ https://soundeffect-lab.info）
const SE := {
	"attack":       "res://assets/se/attack.mp3",
	"hit":          "res://assets/se/hit.mp3",
	"stairs":       "res://assets/se/stairs.mp3",
	"coin":         "res://assets/se/coin.mp3",
	"pickup":       "res://assets/se/pickup.mp3",
	"trap":         "res://assets/se/trap.mp3",
	# ─── アイテム・スキル用 ───────────────────────────────
	"general_item": "res://assets/se/general_item.mp3",
	"fire":         "res://assets/se/fire.mp3",
	"ice":          "res://assets/se/ice.mp3",
	"lightning":    "res://assets/se/lightning.mp3",
	"curse":        "res://assets/se/curse.mp3",
}

# ─── 初期化 ───────────────────────────────────────────────
func _ready() -> void:
	_start_time_msec = Time.get_ticks_msec()
	get_tree().set_auto_accept_quit(false)   # 手動でquit処理してセーブする
	for action: String in KEY_ACTIONS:
		key_bindings[action] = KEY_ACTIONS[action]["default"]
	_build_scene_nodes()
	if SaveLoad.has_save():
		if not SaveLoad.load_game(self):
			_start_new_floor()   # 読み込み失敗時は新規
	else:
		_start_new_floor()

## 毎フレーム: 斜め移動モディファイア押下中は4方向の矢印を点滅表示
func _process(_delta: float) -> void:
	var want_show: bool = false
	if game_state == "playing":
		var mod_key: int = int(key_bindings.get("diag_mod", KEY_SHIFT))
		want_show = Input.is_key_pressed(mod_key)
	if want_show and not _diag_shown:
		_spawn_diag_arrows()
	elif not want_show and _diag_shown:
		_clear_diag_arrows()
	if _diag_shown:
		_update_diag_arrows()

const _DIAG_DIRS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i( 1, -1),
	Vector2i(-1,  1), Vector2i( 1,  1),
]

func _diag_arrow_char(d: Vector2i) -> String:
	if d == Vector2i(-1, -1): return "↖"
	if d == Vector2i( 1, -1): return "↗"
	if d == Vector2i(-1,  1): return "↙"
	if d == Vector2i( 1,  1): return "↘"
	return ""

func _spawn_diag_arrows() -> void:
	_clear_diag_arrows()
	for d: Vector2i in _DIAG_DIRS:
		var node: Node2D = _make_tile_node(_diag_arrow_char(d),
			Color(0, 0, 0, 0), Color(1.0, 0.85, 0.3), 22)
		node.z_index = 15
		_entity_layer.add_child(node)
		var tgt: Vector2i = p_grid + d
		node.call("set_grid", tgt.x, tgt.y)
		_diag_arrows.append(node)
	_diag_shown = true

func _clear_diag_arrows() -> void:
	for node in _diag_arrows:
		if is_instance_valid(node):
			node.queue_free()
	_diag_arrows.clear()
	_diag_shown = false

## 位置をプレイヤー追従させ、alpha を sin で点滅
func _update_diag_arrows() -> void:
	var alpha: float = 0.35 + 0.5 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0))
	for i in _diag_arrows.size():
		var node = _diag_arrows[i]
		if not is_instance_valid(node):
			continue
		var tgt: Vector2i = p_grid + _DIAG_DIRS[i]
		node.call("set_grid", tgt.x, tgt.y)
		node.modulate.a = alpha

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game_state in ["playing", "inventory", "inv_action", "storage_pot", "storage_select", "shop"]:
			SaveLoad.save_game(self)
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
	OptionsUI.build_panel(self)
	# 図鑑パネル
	BestiaryUI.build_panel(self)
	# 会話パネル
	DialogUI.build_panel(self)

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
	# 仲間データを退避（ノードはこの後一括 queue_free されるため）
	var carry_companions: Array = []
	for c: Dictionary in companions:
		carry_companions.append({
			"data":     (c["data"] as Dictionary).duplicate(true),
			"hp":       int(c["hp"]),
			"hp_max":   int(c.get("hp_max", c["hp"])),
		})
	# 旧エンティティ削除
	for ch in _entity_layer.get_children():
		ch.queue_free()
	enemies.clear()
	companions.clear()
	floor_items.clear()
	gold_piles.clear()
	shop_items.clear()
	_shopkeeper    = {}
	_shop_entered  = false
	_in_shop_area  = false
	_shop_traded   = false
	traps.clear()
	_monster_house_triggered = false
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

	# 敵・アイテム・お金・ワナ配置
	EnemyAI.spawn_for_floor(self)
	_spawn_traps()
	_spawn_items()
	_spawn_gold()
	if generator.has_shop:
		ShopLogic.setup(self)
	if generator.has_monster_house:
		EnemyAI.setup_monster_house(self)

	# 仲間を再配置（プレイヤー隣接マスに）
	for cdata: Dictionary in carry_companions:
		var pos: Vector2i = _find_free_adjacent_tile()
		if pos == Vector2i(-1, -1):
			pos = p_grid   # フォールバック（重なる）
		var node: Node2D = _make_tile_node(cdata["data"]["symbol"], cdata["data"]["color"])
		node.z_index = 1
		_entity_layer.add_child(node)
		node.call("set_grid", pos.x, pos.y)
		node.call("set_sprite", Assets.enemy_sprite(cdata["data"].get("id", "")))
		node.call("set_status", "仲", Color(0.4, 0.7, 1.0))
		companions.append({
			"data":     cdata["data"],
			"hp":       cdata["hp"],
			"hp_max":   cdata["hp_max"],
			"grid_pos": pos,
			"node":     node,
			"skill_cooldowns": {},
		})

	# FOV更新・カメラ・HUD
	Fov.update(self)
	Fov.sync_entity_visibility(self)
	_update_camera()
	_refresh_hud()

	_play_bgm("explore")
	add_message("B%dF に降りた。" % current_floor)

# ─── 敵スポーン ───────────────────────────────────────────
## 敵の生成・AI・MH 関連は EnemyAI（scripts/enemy_ai.gd）に分離済み

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
	for si in shop_items:
		occupied.append(si["grid_pos"])
	for trap in traps:
		occupied.append(trap["grid_pos"])
	var count: int = randi_range(2, 4)
	for _i in count:
		var pos: Vector2i = generator.random_floor_pos()
		if pos in occupied:
			continue
		if generator.has_shop and generator.shop_room.has_point(pos):
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

## 店セットアップは ShopLogic.setup に分離済み

## モンスターハウス配置・発動は EnemyAI.setup_monster_house / trigger_monster_house に分離済み

## 踏んだワナを発動
func _check_trap(pos: Vector2i) -> void:
	for i in traps.size():
		if traps[i]["grid_pos"] != pos:
			continue
		var trap: Dictionary = traps[i]
		# ワナに踏み込んだ時点でダッシュは中断対象
		_dash_interrupt = true
		# スプライトを表示してフラッシュ
		trap["triggered"] = true
		trap["node"].visible = true
		trap["node"].call("flash", Color(1.0, 0.5, 0.0))
		_play_se(TrapData.trap_se(trap["type"]))
		add_message("%s にはまった！" % TrapData.trap_name(trap["type"]))
		# 図鑑登録（初発動時のみ）
		if Bestiary.discover_trap(str(trap["type"])):
			add_message("図鑑に %s を登録した。" % TrapData.trap_name(trap["type"]))
		# 効果適用
		match trap["type"]:
			"damage":
				var dmg: int = max(1, p_hp_max / 10 + current_floor)
				p_hp = max(0, p_hp - dmg)
				add_message("%d ダメージを受けた！" % dmg)
				if p_hp <= 0:
					_trigger_game_over("ダメージのワナで力尽きた")
					return
			"warp":
				p_grid = generator.random_floor_pos()
				_player_node.call("set_grid", p_grid.x, p_grid.y)
				Fov.update(self)
				_update_camera()
				add_message("見知らぬ場所に飛ばされた！")
			"hunger":
				p_fullness = max(0, p_fullness - 30)
				add_message("急にお腹が空いてきた…")
			"blind":
				p_blind_turns += 10
				add_message("目の前が真っ暗になった！")
			"poison":
				p_poisoned_turns += 10
				add_message("毒にやられた！")
			"sleep":
				p_sleep_turns += 5
				add_message("眠気に襲われた…")
			"drop_item":
				if not p_inventory.is_empty():
					var drop_idx: int = randi() % p_inventory.size()
					var dropped: Dictionary = p_inventory[drop_idx]
					p_inventory.remove_at(drop_idx)
					var drop_pos: Vector2i = _find_free_drop_pos(p_grid)
					if drop_pos != Vector2i(-1, -1):
						_place_floor_item(dropped, drop_pos)
					add_message("転んで %s を落とした！" % dropped.get("name", "?"))
				else:
					add_message("転んだが、荷物はなかった。")
			"alarm":
				add_message("けたたましい警報が鳴り響いた！")
				for enemy: Dictionary in enemies:
					enemy["asleep"]  = false
					enemy["alerted"] = true
					_refresh_enemy_status_visual(enemy)
			"slow":
				ItemEffects.apply_status_to_player(self, "slow", 8)
			"confuse":
				ItemEffects.apply_status_to_player(self, "confuse", 5)
		# 壊れ判定
		if randf() < TrapData.break_chance(trap["type"]):
			add_message("%s は壊れた。" % TrapData.trap_name(trap["type"]))
			trap["node"].queue_free()
			traps.remove_at(i)
		_refresh_hud()
		return

# ─── 状態異常ビジュアル更新 ────────────────────────────────
## 状態異常の「付与」は ItemEffects.apply_status_to_player / apply_status_to_enemy へ分離。
## ここには「ノードの見た目更新」だけを残す。

## プレイヤーノードの状態異常ビジュアルを現在の状態に合わせて更新
func _refresh_player_status_visual() -> void:
	if not is_instance_valid(_player_node):
		return
	if p_paralyzed_turns > 0:
		_player_node.call("set_status", "麻", Color(1.0, 1.0, 0.2))
	elif p_sleep_turns > 0:
		_player_node.call("set_status", "眠", Color(0.3, 0.8, 1.0))
	elif p_confused_turns > 0:
		_player_node.call("set_status", "混", Color(0.8, 0.3, 1.0))
	elif p_slow_turns > 0:
		_player_node.call("set_status", "鈍", Color(0.6, 0.6, 0.6))
	elif p_poisoned_turns > 0:
		_player_node.call("set_status", "毒", Color(0.3, 1.0, 0.3))
	elif p_blind_turns > 0:
		_player_node.call("set_status", "盲", Color(0.5, 0.5, 0.5))
	else:
		_player_node.call("clear_status")

## 敵ノードの状態異常ビジュアルを現在の状態に合わせて更新
func _refresh_enemy_status_visual(enemy: Dictionary) -> void:
	var node = enemy.get("node")
	if not is_instance_valid(node):
		return
	if enemy.get("paralyzed_turns", 0) > 0:
		node.call("set_status", "麻", Color(1.0, 1.0, 0.2))
	elif enemy.get("asleep", false):
		node.call("set_status", "眠", Color(0.3, 0.8, 1.0))
	elif enemy.get("confused_turns", 0) > 0:
		node.call("set_status", "混", Color(0.8, 0.3, 1.0))
	elif enemy.get("slow_turns", 0) > 0:
		node.call("set_status", "鈍", Color(0.6, 0.6, 0.6))
	elif enemy.get("poisoned", 0) > 0:
		node.call("set_status", "毒", Color(0.3, 1.0, 0.3))
	elif enemy.get("sealed", false):
		node.call("set_status", "封", Color(0.9, 0.5, 0.1))
	elif enemy.get("interested_turns", 0) > 0:
		node.call("set_status", "興", Color(1.0, 0.5, 0.85))
	else:
		node.call("clear_status")

## 店を開く処理・カーペットドロップ変換は ShopLogic.open / convert_carpet_drops に分離済み

## エリア（探索/店/MH）に応じてBGM切り替え・入退場メッセージを管理する
## プレイヤー周囲8マスにいる MH 眠り敵を確定で起こす（通常の状態異常眠りには影響しない）
func _wake_adjacent_mh_enemies() -> void:
	for d: Vector2i in [
			Vector2i( 1, 0), Vector2i(-1, 0), Vector2i( 0, 1), Vector2i( 0,-1),
			Vector2i( 1, 1), Vector2i( 1,-1), Vector2i(-1, 1), Vector2i(-1,-1)]:
		var np: Vector2i = p_grid + d
		var e = _enemy_at(np)
		if e == null:
			continue
		if not e.get("mh_asleep", false):
			continue
		e["mh_asleep"]    = false
		e["asleep"]       = false
		e["asleep_turns"] = 0
		e["alerted"]      = true
		_refresh_enemy_status_visual(e)
		add_message("%s が目を覚ました！" % e["data"].get("name", "敵"))

## 仲間がモンスターハウスに踏み込んだ場合に MH を発動させる
func _check_companion_mh_trigger() -> void:
	if not generator.has_monster_house or _monster_house_triggered:
		return
	var mh_room: Rect2i = generator.monster_house_room
	for c in companions:
		if mh_room.has_point(c["grid_pos"] as Vector2i):
			EnemyAI.trigger_monster_house(self)
			_play_bgm("monster_house")
			return

func _update_area_bgm() -> void:
	# ─ BGM ターゲットを決定 ────────────────────────────────
	var in_mh:   bool = generator.has_monster_house and generator.monster_house_room.has_point(p_grid)
	var in_shop: bool = generator.has_shop and generator.shop_room.has_point(p_grid)

	var target_bgm: String = "explore"
	if _monster_house_triggered:
		target_bgm = "monster_house"   # 発動後はフロア全体でMH BGM
	if in_shop:
		target_bgm = "shop"   # 店内は常にショップBGM（MHより優先）

	# ─ 店の入退場メッセージ ────────────────────────────────
	if in_shop != _in_shop_area:
		_in_shop_area = in_shop
		if in_shop:
			add_message("いらっしゃいませ！何かお探しですか？")
			_shop_traded = false
		else:
			if _shop_traded:
				add_message("ありがとうございました。またのお越しをお待ちしております！")
			else:
				add_message("冷やかしか？…またいつでも来い。")

	# ─ MH 発動チェック（発動後は target_bgm を上書き）─────
	if in_mh and not _monster_house_triggered:
		EnemyAI.trigger_monster_house(self)   # 内部で _monster_house_triggered = true にする
		target_bgm = "monster_house"

	_play_bgm(target_bgm)

## 店のUI・売買・カーペット空き探索は ShopLogic（scripts/shop_logic.gd）に分離済み。
## 状態変数（shop_items / shop_cursor / shop_mode / shop_sell_cursor /
## _shopkeeper / _shop_traded / _in_shop_area / _shop_entered）はここ game.gd に保持。

func _place_floor_item(item: Dictionary, pos: Vector2i) -> void:
	var sym := ItemData.type_symbol(item.get("type", 0))
	var col := ItemData.type_color(item.get("type", 0))
	var node := _make_tile_node(sym, Color(0.12, 0.12, 0.12), col, 18)
	_entity_layer.add_child(node)
	node.call("set_grid", pos.x, pos.y)
	node.call("set_sprite", Assets.item_type_sprite(item.get("type", 0)))
	floor_items.append({"item": item, "grid_pos": pos, "node": node})

## ワナを1つ配置する（発動まで非表示）
func _place_trap(trap_type: String, pos: Vector2i) -> void:
	var node := _make_tile_node("", Color(0.15, 0.08, 0.08), Color.WHITE, 0)
	node.z_index = 0
	node.visible = false   # 未発動は非表示
	_entity_layer.add_child(node)
	node.call("set_grid", pos.x, pos.y)
	node.call("set_sprite", Assets.TRAP)
	traps.append({"type": trap_type, "grid_pos": pos, "node": node, "triggered": false})

## 通常フロアのワナをスポーンする（generator.trap_spawns を使用）
func _spawn_traps() -> void:
	for pos: Vector2i in generator.trap_spawns:
		var td: Dictionary = TrapData.random_trap()
		_place_trap(td["id"], pos)

## プレイヤー隣接マス（8方向）から空き床マスを返す。なければ Vector2i(-1,-1)
func _find_free_adjacent_tile() -> Vector2i:
	for d: Vector2i in [
			Vector2i( 1, 0), Vector2i(-1, 0), Vector2i( 0, 1), Vector2i( 0,-1),
			Vector2i( 1, 1), Vector2i( 1,-1), Vector2i(-1, 1), Vector2i(-1,-1)]:
		var p: Vector2i = p_grid + d
		if not generator.is_walkable(p.x, p.y):
			continue
		if _enemy_at(p) != null:
			continue
		if _item_at(p) != null:
			continue
		var blocked: bool = false
		for tr: Dictionary in traps:
			if (tr["grid_pos"] as Vector2i) == p:
				blocked = true
				break
		if blocked:
			continue
		if not _shopkeeper.is_empty() and _shopkeeper["grid_pos"] == p:
			continue
		return p
	return Vector2i(-1, -1)

## デバッグ：敵IDから1体を隣接マスに召喚
func debug_spawn_enemy(enemy_id: String) -> bool:
	var pos: Vector2i = _find_free_adjacent_tile()
	if pos == Vector2i(-1, -1):
		add_message("隣接マスに空きがない。")
		return false
	var data: Dictionary = EnemyData.get_by_id(enemy_id)
	if data.is_empty():
		add_message("不明な敵ID: %s" % enemy_id)
		return false
	var node: Node2D = _make_tile_node(data["symbol"], data["color"])
	node.z_index = 1
	_entity_layer.add_child(node)
	node.call("set_grid", pos.x, pos.y)
	node.call("set_sprite", Assets.enemy_sprite(data.get("id", "")))
	enemies.append({
		"data": data, "hp": int(data.get("hp", 1)),
		"grid_pos": pos, "node": node,
		"asleep": false, "alerted": true,
		"asleep_turns": 0, "poisoned": 0, "sealed": false,
		"slow_turns": 0, "slow_skip": false,
		"confused_turns": 0, "paralyzed_turns": 0,
		"skill_cooldowns": {},
	})
	add_message("[DEBUG] %s を生成した。" % data.get("name", "?"))
	return true

## デバッグ：アイテムIDから1個を隣接マスに配置
func debug_spawn_item(item_id: String) -> bool:
	var pos: Vector2i = _find_free_adjacent_tile()
	if pos == Vector2i(-1, -1):
		add_message("隣接マスに空きがない。")
		return false
	var item: Dictionary = ItemData.get_by_id(item_id)
	if item.is_empty():
		add_message("不明なアイテムID: %s" % item_id)
		return false
	item["_iid"] = _next_iid
	_next_iid += 1
	_place_floor_item(item, pos)
	add_message("[DEBUG] %s を生成した。" % item.get("name", "?"))
	return true

## デバッグ：ワナIDから1個を隣接マスに配置（未発動状態）
func debug_spawn_trap(trap_id: String) -> bool:
	var pos: Vector2i = _find_free_adjacent_tile()
	if pos == Vector2i(-1, -1):
		add_message("隣接マスに空きがない。")
		return false
	var td: Dictionary = TrapData.get_by_id(trap_id)
	if td.is_empty():
		add_message("不明なワナID: %s" % trap_id)
		return false
	_place_trap(trap_id, pos)
	add_message("[DEBUG] %s を生成した。" % td.get("name", "?"))
	return true

# ─── 入力処理 ─────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var kev := event as InputEventKey

	var kc := kev.keycode

	# リバインド待ち受け中
	if game_state == "rebinding":
		if kc == KEY_ESCAPE:
			OptionsUI.cancel_rebind(self)
		else:
			OptionsUI.finish_rebind(self, kc)
		return

	# F12: デバッグモードトグル（図鑑内に「生成する」ボタンを出すなど）
	if kc == KEY_F12:
		debug_mode = not debug_mode
		add_message("デバッグモード: %s" % ("ON" if debug_mode else "OFF"))
		# 図鑑が開いていれば再描画（ボタン表示・全エントリ表示の切替）
		if game_state == "bestiary" and is_instance_valid(_bestiary_layer):
			BestiaryUI.refresh_visibility(self)
			BestiaryUI.open(self)   # リスト・詳細を再描画
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
				OptionsUI.open(self)
				return
			if kc == KEY_M:
				show_minimap = not show_minimap
				_refresh_hud()
				return
			_handle_play_input(kc)
		"inventory":
			InventoryUI.handle_input(self, kc, kev.shift_pressed)
		"inv_action":
			InventoryUI.handle_action_input(self, kc)
		"throw_aim":
			ThrowSystem.handle_aim_input(self, kc)
		"throw_anim":
			pass   # アニメーション中は入力無視
		"storage_pot":
			InventoryUI.handle_storage_pot_input(self, kc)
		"storage_select":
			InventoryUI.handle_storage_select_input(self, kc)
		"shop":
			ShopLogic.handle_input(self, kc)
		"options":
			if kc == KEY_ESCAPE:
				OptionsUI.close(self)
				return
		"bestiary":
			BestiaryUI.handle_input(self, kc)
		"dialog":
			DialogUI.handle_input(self, kc)
		"dead", "victory":
			if kc == KEY_R:
				get_tree().reload_current_scene()

func _apply_zoom() -> void:
	var z: float = ZOOM_LEVELS[_zoom_index]
	_camera.zoom = Vector2(z, z)

func _handle_play_input(kc: int) -> void:
	# 麻痺：完全行動不能
	if p_paralyzed_turns > 0:
		add_message("体が痺れて動けない！")
		_player_node.call("flash", Color(1.0, 1.0, 0.2))
		_end_player_turn()
		return
	# 睡眠：行動不能
	if p_sleep_turns > 0:
		add_message("眠っている…")
		_end_player_turn()
		return
	# 鈍足：2ターンに1回スキップ
	if p_slow_turns > 0 and _p_slow_skip:
		_p_slow_skip = false
		add_message("体が重くて動けない…")
		_player_node.call("flash", Color(0.6, 0.6, 0.6))
		_end_player_turn()
		return
	if p_slow_turns > 0:
		_p_slow_skip = true
	var mod: int  = key_bindings.get("diag_mod", KEY_SHIFT)
	var dash_k: int = key_bindings.get("dash", KEY_CTRL)
	var idash_k: int = key_bindings.get("idash", KEY_TAB)
	var is_dash: bool = Input.is_key_pressed(dash_k)
	var is_idash: bool = Input.is_key_pressed(idash_k)

	# 混乱：移動キーを押したとき方向をランダム化
	if p_confused_turns > 0:
		var is_move_key := kc in [
			key_bindings.get("move_up", KEY_UP), key_bindings.get("move_down", KEY_DOWN),
			key_bindings.get("move_left", KEY_LEFT), key_bindings.get("move_right", KEY_RIGHT),
		]
		if is_move_key or Input.is_key_pressed(mod):
			var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
						 Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
			add_message("混乱して変な方向に動いた！")
			_player_node.call("flash", Color(0.8, 0.3, 1.0))
			_try_player_move(dirs[randi() % dirs.size()])   # 混乱中はダッシュ無効
			return

	# 斜め移動：モディファイア + 2方向キー同時押し
	# モディファイア押下中は通常移動を一切発火させない（桂馬移動防止）
	if Input.is_key_pressed(mod):
		var up_h    := Input.is_key_pressed(key_bindings.get("move_up",    KEY_UP))
		var down_h  := Input.is_key_pressed(key_bindings.get("move_down",  KEY_DOWN))
		var left_h  := Input.is_key_pressed(key_bindings.get("move_left",  KEY_LEFT))
		var right_h := Input.is_key_pressed(key_bindings.get("move_right", KEY_RIGHT))
		if   up_h   and left_h:  _move_or_dash(Vector2i(-1, -1), is_dash, is_idash)
		elif up_h   and right_h: _move_or_dash(Vector2i( 1, -1), is_dash, is_idash)
		elif down_h and left_h:  _move_or_dash(Vector2i(-1,  1), is_dash, is_idash)
		elif down_h and right_h: _move_or_dash(Vector2i( 1,  1), is_dash, is_idash)
		return  # 2方向揃っていない場合も含め、常にここで止める

	# 4方向移動・その他
	if   kc == key_bindings.get("move_left",  KEY_LEFT):  _move_or_dash(Vector2i(-1,  0), is_dash, is_idash)
	elif kc == key_bindings.get("move_right", KEY_RIGHT): _move_or_dash(Vector2i( 1,  0), is_dash, is_idash)
	elif kc == key_bindings.get("move_up",    KEY_UP):    _move_or_dash(Vector2i( 0, -1), is_dash, is_idash)
	elif kc == key_bindings.get("move_down",  KEY_DOWN):  _move_or_dash(Vector2i( 0,  1), is_dash, is_idash)
	elif kc == key_bindings.get("wait",       KEY_SPACE): _player_wait_or_descend()
	elif kc == key_bindings.get("inventory",  KEY_I):     InventoryUI.open(self)
	elif kc == key_bindings.get("pickup",     KEY_G):     _try_pickup()
	elif kc == key_bindings.get("bestiary",   KEY_Z):     BestiaryUI.open(self)

## ダッシュ/i-ダッシュ判定付きの移動ルーター（i-ダッシュが通常ダッシュより優先）
func _move_or_dash(dir: Vector2i, dash: bool, idash: bool = false) -> void:
	if idash:
		_try_i_dash(dir)
	elif dash:
		_try_player_dash(dir)
	else:
		_try_player_move(dir)

## インベントリ／アクションメニュー／保存の箱 の入力・状態遷移は
## InventoryUI（scripts/inventory_ui.gd）に分離済み。
## 状態変数（inv_cursor / action_cursor / _action_list /
## _storage_pot_iid / storage_cursor）はここ game.gd に保持。

## 投擲／撃つ系のロジックは ThrowSystem（scripts/throw_system.gd）に分離済み。
## 状態変数（_aim_dir / _aim_item_idx / _aim_is_shoot / _aim_node）はここ game.gd に保持。

# ─── プレイヤー行動 ───────────────────────────────────────
## プレイヤー1歩移動。
## dash=true のとき: 攻撃・店オープン・アイテム拾得をスキップ。ダッシュ続行可能なら true を返す。
## dash=false のとき: 常に false を返す（戻り値は使われない）。
func _try_player_move(dir: Vector2i, dash: bool = false) -> bool:
	if dash:
		_dash_interrupt = false
	if dir != Vector2i.ZERO:
		p_facing = dir
	var new_pos: Vector2i = p_grid + dir
	# 敵: 通常は攻撃、ダッシュ中は停止
	var target_enemy = _enemy_at(new_pos)
	if target_enemy != null:
		if dash:
			return false
		Combat.player_attack(self, target_enemy)
		_end_player_turn()
		return false
	# 店員: 通常は店を開く、ダッシュ中は停止
	if not _shopkeeper.is_empty() and _shopkeeper["grid_pos"] == new_pos:
		if dash:
			return false
		ShopLogic.open(self)
		return false
	# 壁チェック
	if not generator.is_walkable(new_pos.x, new_pos.y):
		return false
	# 仲間がいる: ダッシュ中は停止、通常は位置入れ替え
	var swap_comp = CompanionAI.at(self, new_pos)
	if swap_comp != null:
		if dash:
			return false
		# 仲間の位置を自分の元位置に
		swap_comp["grid_pos"] = p_grid
		swap_comp["node"].call("set_grid", p_grid.x, p_grid.y)
	# ダッシュ時: 未発動のワナを踏むか & MH 発動前の状態を記録
	var will_trigger_trap: bool = false
	if dash:
		for trap in traps:
			if (trap["grid_pos"] as Vector2i) == new_pos and not trap.get("triggered", false):
				will_trigger_trap = true
				break
	var was_mh_triggered: bool = _monster_house_triggered
	var was_room_idx: int = _room_index_of(p_grid)
	# 移動
	p_grid = new_pos
	_player_node.call("set_grid", p_grid.x, p_grid.y)
	# BGM切り替え・入退場メッセージ・MH発動
	_update_area_bgm()
	# MH 眠り敵：プレイヤー隣接で確定起床
	_wake_adjacent_mh_enemies()
	# ワナチェック
	_check_trap(p_grid)
	# 店アイテム踏んだ時：名前と価格を表示
	for si in shop_items:
		if si["grid_pos"] == p_grid:
			var pickup_key := OS.get_keycode_string(key_bindings.get("pickup", KEY_G))
			add_message("【%s】  %dG  [%s] で購入" % [si["item"].get("name", "?"), si["price"], pickup_key])
			break
	# アイテム処理
	if dash:
		# ダッシュ中は拾わず「～の上に乗った」メッセージのみ。金は拾う
		var fi = _item_at(p_grid)
		if fi != null:
			add_message("%s の上に乗った。" % fi["item"].get("name", "?"))
		_collect_gold(p_grid)
	else:
		_auto_pickup()
	# 階段チェック
	if generator.get_tile(p_grid.x, p_grid.y) == DungeonGenerator.TILE_STAIRS:
		var descend_key := OS.get_keycode_string(key_bindings.get("wait", KEY_SPACE))
		add_message("階段を見つけた！ [%s] で降りる" % descend_key)
	_end_player_turn()
	if not dash:
		return false
	# ── ダッシュ続行判定 ───────────────────────────────────
	if game_state != "playing":
		return false
	if will_trigger_trap:
		return false
	if _monster_house_triggered and not was_mh_triggered:
		return false
	# あらゆるダメージ／状態異常／敵スキルの発生で中断
	if _dash_interrupt:
		return false
	# 部屋の入口に到達したら停止（通路→部屋、または別の部屋へ切り替わった瞬間）
	var now_room_idx: int = _room_index_of(p_grid)
	if now_room_idx != -1 and now_room_idx != was_room_idx:
		return false
	# 部屋から通路に出た1マス目で停止
	if was_room_idx != -1 and now_room_idx == -1:
		return false
	# 通路の分岐（T字路・十字路・部屋の入口隣接など）で停止
	if now_room_idx == -1 and _is_corridor_junction(p_grid):
		return false
	# 現在地の停止要素: 床アイテム・店商品・階段
	if _item_at(p_grid) != null:
		return false
	for si in shop_items:
		if si["grid_pos"] == p_grid:
			return false
	if generator.get_tile(p_grid.x, p_grid.y) == DungeonGenerator.TILE_STAIRS:
		return false
	# 次マスの停止要素: 敵・店員・壁
	var next2: Vector2i = p_grid + dir
	if _enemy_at(next2) != null:
		return false
	if not _shopkeeper.is_empty() and _shopkeeper["grid_pos"] == next2:
		return false
	if not generator.is_walkable(next2.x, next2.y):
		return false
	return true

## 指定座標がどの部屋に属するかのインデックス（通路なら -1）
func _room_index_of(pos: Vector2i) -> int:
	if generator == null:
		return -1
	for i in generator.rooms.size():
		if (generator.rooms[i] as Rect2i).has_point(pos):
			return i
	return -1

## 通路の分岐点判定: 4方向の歩行可能マスが3以上なら分岐（直線通路は2）
func _is_corridor_junction(pos: Vector2i) -> bool:
	if generator == null:
		return false
	var count: int = 0
	for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var np: Vector2i = pos + d
		if generator.is_walkable(np.x, np.y):
			count += 1
	return count >= 3

## ダッシュ: dir 方向へ停止条件まで連続移動（各ステップで1ターン消費）
func _try_player_dash(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	var max_steps: int = 100   # 暴走防止の上限
	while max_steps > 0:
		max_steps -= 1
		if not _try_player_move(dir, true):
			break

## i-ダッシュ（便利移動）：方向キー+i-ダッシュキーで発動
## - 部屋内：指定方向側にあるアイテム/金/階段のうち最寄りへ最短経路で移動
##           （方向側になければ最寄りの通路出口へ）
## - 通路内：指定方向を起点に曲がり角を自動追従し、次の部屋入口まで進む
## 停止条件は通常ダッシュと同じ（敵隣接・被弾・ワナ・MH発動等）
func _try_i_dash(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	var room_idx: int = _room_index_of(p_grid)
	if room_idx == -1:
		_i_dash_corridor(dir)
	else:
		_i_dash_in_room(room_idx, dir)

## 通路モード：指定方向を起点に曲がり角を自動追従しながら進む
func _i_dash_corridor(start_dir: Vector2i) -> void:
	var prev_dir: Vector2i = start_dir
	var max_steps: int = 100
	while max_steps > 0:
		max_steps -= 1
		var dir: Vector2i = _i_dash_next_corridor_dir(p_grid, prev_dir)
		if dir == Vector2i.ZERO:
			break
		if not _try_player_move(dir, true):
			break
		prev_dir = dir

## 通路の次の進行方向を決定する（行き止まりや分岐は Vector2i.ZERO を返す）
func _i_dash_next_corridor_dir(pos: Vector2i, prev_dir: Vector2i) -> Vector2i:
	var reject: Vector2i = -prev_dir  # 来た方向へ戻るのは禁止
	var options: Array = []
	for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		if d == reject:
			continue
		var np: Vector2i = pos + d
		if generator.is_walkable(np.x, np.y):
			options.append(d)
	if options.size() == 1:
		return options[0]
	# 分岐点：直進可能なら直進、それ以外は停止
	if options.size() >= 2 and prev_dir != Vector2i.ZERO:
		for opt: Vector2i in options:
			if opt == prev_dir:
				return opt
	return Vector2i.ZERO

## 部屋モード：BFS で全候補の距離を計算 → 方向重みをかけたスコアで最良を選ぶ
## 優先度: 前方のアイテム/金/階段 > 前方の通路出口。前方に何もなければ停止。
func _i_dash_in_room(room_idx: int, dir: Vector2i) -> void:
	var room: Rect2i = generator.rooms[room_idx]
	# BFS で全到達マスの距離・親を求める
	var bfs: Dictionary = _i_dash_bfs_all(p_grid)
	var distances: Dictionary = bfs["distances"]
	var parents: Dictionary    = bfs["parents"]
	# 前方（入力方向と 90°以内）のアイテム/金/階段を収集
	var forward_items: Array[Vector2i] = []
	for fi in floor_items:
		var fp: Vector2i = fi["grid_pos"] as Vector2i
		if room.has_point(fp) and distances.has(fp) and _i_dash_alignment(fp, dir) >= 0.0:
			forward_items.append(fp)
	for gp in gold_piles:
		var gpp: Vector2i = gp["grid_pos"] as Vector2i
		if room.has_point(gpp) and distances.has(gpp) and _i_dash_alignment(gpp, dir) >= 0.0:
			forward_items.append(gpp)
	if room.has_point(generator.stairs_pos) \
			and distances.has(generator.stairs_pos) \
			and _i_dash_alignment(generator.stairs_pos, dir) >= 0.0:
		forward_items.append(generator.stairs_pos)
	# 前方にアイテム類がなければ、前方の通路出口にフォールバック
	var candidates: Array[Vector2i] = forward_items
	if candidates.is_empty():
		for ex: Vector2i in _i_dash_room_exits(room):
			if distances.has(ex) and _i_dash_alignment(ex, dir) >= 0.0:
				candidates.append(ex)
	if candidates.is_empty():
		add_message("その方向に目的地はない。")
		return
	# 各候補を距離×方向ペナルティでスコア化し、最小を選ぶ
	var best_pos: Vector2i  = Vector2i(-99999, -99999)
	var best_score: float   = INF
	for tpos: Vector2i in candidates:
		var d: int = distances[tpos]
		var score: float = _i_dash_target_score(tpos, dir, d)
		if score < best_score:
			best_score = score
			best_pos   = tpos
	if best_pos.x == -99999:
		add_message("そこへは行けない。")
		return
	# 親ポインタから経路を復元
	var path: Array = []
	var cur: Vector2i = best_pos
	while cur != p_grid:
		path.push_front(cur)
		cur = parents[cur]
	for next_pos: Vector2i in path:
		var step_dir: Vector2i = next_pos - p_grid
		if not _try_player_move(step_dir, true):
			break

## ターゲットのスコア計算（低いほど優先）
## score = 距離 × (2 − 方向アラインメント)
## - 指定方向とピッタリ一致: 係数 ×1（距離そのまま）
## - 垂直（90°外れ）:          係数 ×2
func _i_dash_target_score(pos: Vector2i, dir: Vector2i, distance: int) -> float:
	var align: float = _i_dash_alignment(pos, dir)
	return float(distance) * (2.0 - align)

## cos(θ)：ターゲット方向ベクトルと入力方向の内積を正規化。範囲 [-1, 1]
## 1=同方向, 0=垂直, -1=真後ろ。自分位置のときは 0 を返す
func _i_dash_alignment(pos: Vector2i, dir: Vector2i) -> float:
	var v: Vector2i = pos - p_grid
	var v_len: float = sqrt(float(v.x * v.x + v.y * v.y))
	if v_len < 0.001:
		return 0.0
	var dir_len: float = sqrt(float(dir.x * dir.x + dir.y * dir.y))
	return float(v.x * dir.x + v.y * dir.y) / (v_len * dir_len)

## 4方向BFSで start から到達可能な全マスの距離と親ポインタを返す
func _i_dash_bfs_all(start: Vector2i) -> Dictionary:
	var distances: Dictionary = {start: 0}
	var parents:   Dictionary = {start: start}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var d: int = distances[cur]
		for dd: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var np: Vector2i = cur + dd
			if distances.has(np):
				continue
			if not generator.is_walkable(np.x, np.y):
				continue
			distances[np] = d + 1
			parents[np]   = cur
			queue.append(np)
	return {"distances": distances, "parents": parents}

## 部屋の出口から続く通路側の1マス目を返す（BFS のターゲットに使用）
## 部屋内マスを返すと「プレイヤーが既に出口マスにいる」ケースで経路ゼロになるため通路側で返す
func _i_dash_room_exits(room: Rect2i) -> Dictionary:
	var out: Dictionary = {}
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var on_border := (x == room.position.x or x == room.end.x - 1
					or y == room.position.y or y == room.end.y - 1)
			if not on_border:
				continue
			var p: Vector2i = Vector2i(x, y)
			if not generator.is_walkable(p.x, p.y):
				continue
			for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var np: Vector2i = p + d
				if generator.is_walkable(np.x, np.y) and not room.has_point(np):
					out[np] = true
					break
	return out

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
	SaveLoad.save_game(self)
	_start_new_floor()

func _try_pickup() -> void:
	# 店アイテムが足元にあれば購入
	for i in shop_items.size():
		if shop_items[i]["grid_pos"] == p_grid:
			ShopLogic.try_buy(self, i)
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
		add_message("%s の上に乗った。" % fi["item"].get("name", "?"))
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
	# 会話中はターン進行を遅延（会話終了時に Combat._finish_recruit から再呼び出し）
	if game_state == "dialog":
		return
	# 満腹度
	turn_count += 1
	if turn_count % HUNGER_RATE == 0:
		p_fullness = max(0, p_fullness - 1)
		if p_fullness <= 10 and p_fullness > 0:
			add_message("お腹が減って苦しい…")
	if p_fullness == 0:
		_hunger_accum += float(p_hp_max) / 100.0
		var hunger_dmg := int(_hunger_accum)
		if hunger_dmg >= 1:
			_hunger_accum -= float(hunger_dmg)
			Combat.apply_damage_to_player(self, hunger_dmg, "空腹")
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
	# 毒ダメージ
	if p_poisoned_turns > 0:
		_player_node.call("flash", Color(0.3, 1.0, 0.3))
		Combat.apply_damage_to_player(self, 1, "毒")
		p_poisoned_turns -= 1
		if p_poisoned_turns == 0:
			add_message("毒が抜けた。")
			_refresh_player_status_visual()
	# 睡眠カウントダウン
	if p_sleep_turns > 0:
		p_sleep_turns -= 1
		if p_sleep_turns == 0:
			add_message("目が覚めた。")
			_refresh_player_status_visual()
	# 鈍足カウントダウン
	if p_slow_turns > 0:
		p_slow_turns -= 1
		if p_slow_turns == 0:
			_p_slow_skip = false
			add_message("動きが戻った。")
			_refresh_player_status_visual()
	# 混乱カウントダウン
	if p_confused_turns > 0:
		p_confused_turns -= 1
		if p_confused_turns == 0:
			add_message("混乱が収まった。")
			_refresh_player_status_visual()
	# 麻痺カウントダウン
	if p_paralyzed_turns > 0:
		p_paralyzed_turns -= 1
		if p_paralyzed_turns == 0:
			add_message("麻痺が解けた。")
			_refresh_player_status_visual()
	# 仲間ターン（プレイヤー直後・敵ターン直前）
	CompanionAI.run_turns(self)
	# 敵の追加スポーン（50ターンに1体、視界外）
	if turn_count % 50 == 0:
		EnemyAI.spawn_wandering(self)
	EnemyAI.run_turns(self)
	Fov.update(self)
	Fov.sync_entity_visibility(self)
	_update_camera()
	_refresh_hud()

# ─── 戦闘：プレイヤー → 敵 ───────────────────────────────
## 戦闘計算・ダメージ処理・レベルアップは Combat（scripts/combat.gd）に分離済み

# ─── 敵ターン ─────────────────────────────────────────────
## 敵ターン処理は EnemyAI.run_turns / run_turn / attack / chase / random_walk / move / can_walk に分離済み

# ─── インベントリ操作 ─────────────────────────────────────
## アイテム使用ロジックは ItemEffects に、インベントリUIは InventoryUI に分離済み。

## ワンダリングスポーン／即時召喚は EnemyAI.spawn_wandering / spawn_one_near_player に分離済み

## 保存の箱UI（view / store / 取り出し / しまう）は InventoryUI に分離済み。

## アイテムが置かれていない最寄りの床タイルを返す（見つからなければ Vector2i(-1,-1)）
func _find_free_drop_pos(origin: Vector2i) -> Vector2i:
	var occupied: Array = []
	for fi in floor_items:
		occupied.append(fi["grid_pos"] as Vector2i)
	for si in shop_items:
		occupied.append(si["grid_pos"] as Vector2i)
	for trap in traps:
		occupied.append(trap["grid_pos"] as Vector2i)

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

## FOV（視野計算）とエンティティ可視性同期は Fov（scripts/fov.gd）に分離済み。
## 呼び出しは Fov.update(self) / Fov.sync_entity_visibility(self)。

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
	SaveLoad.delete_save()   # ローグライク：死んだらセーブ削除
	add_message("あなたは倒れた…")
	_refresh_hud()

func _trigger_victory() -> void:
	game_state = "victory"
	SaveLoad.delete_save()   # クリア後もセーブ削除
	add_message("古代の守護者を倒し、遺産を持ち帰った！")
	_refresh_hud()

## セーブ・ロードは SaveLoad（scripts/save_load.gd）に分離済み。
## 呼び出しは SaveLoad.save_game(self) / SaveLoad.load_game(self) / SaveLoad.has_save() / SaveLoad.delete_save()

## ロード後にオプションUIへ音量・キーコンフィグの値を反映する
## ロード後のUI値反映は OptionsUI.apply_loaded に分離済み。
## SaveLoad からは game._apply_loaded_settings() 経由で呼ばれるので薄いラッパーだけ残す。
func _apply_loaded_settings() -> void:
	OptionsUI.apply_loaded(self)

# ─── BGM ─────────────────────────────────────────────────
var _current_bgm_key: String = ""

func _play_bgm(key: String) -> void:
	if key == _current_bgm_key and _bgm_player.playing:
		return   # 同じ曲が再生中なら何もしない
	if not BGM.has(key):
		return
	var path: String = BGM[key]
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamMP3
	if stream == null:
		return
	stream.loop        = true
	_bgm_player.stream    = stream
	_bgm_player.volume_db = _linear_to_db_safe(vol_bgm)
	_bgm_player.play()
	_current_bgm_key = key

func _stop_bgm() -> void:
	_bgm_player.stop()
	_current_bgm_key = ""

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

## アイテム辞書から SE キーを解決して再生する
## item に "se" フィールドがあればそれを優先、なければ "general_item"
func _play_item_se(item: Dictionary) -> void:
	_play_se(item.get("se", "general_item"))

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
## calc_atk / calc_def は Combat に分離済み（Combat.calc_atk(game) / Combat.calc_def(game)）

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

## インベントリ表示用のリスト。p_inventory の後ろに足元のアイテム（あれば）を追加。
## HUD 描画・アクションメニュー共にこちらを基準にする。
func _inventory_display_list() -> Array:
	var list: Array = p_inventory.duplicate()
	var fi = _item_at(p_grid)
	if fi != null:
		list.append(fi["item"])
	return list

## 表示リスト上の index i が足元アイテム（p_inventory の範囲外）かを判定
func _is_floor_entry(i: int) -> bool:
	return i >= p_inventory.size() and _item_at(p_grid) != null

func _make_tile_node(sym: String, bg: Color,
		fg: Color = Color.WHITE, fs: int = 20) -> Node2D:
	var node := Node2D.new()
	node.set_script(load("res://scripts/tile_node.gd"))
	node.call("setup", sym, bg, fg, fs)
	return node
