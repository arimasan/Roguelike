class_name Combat
extends RefCounted

## プレイヤー⇔敵の戦闘計算と、HP 変化・撃破・レベルアップ・被弾処理を担当する。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態（p_hp / p_atk_base / p_weapon / p_ring / enemies / p_level / p_exp 等）は
##   すべて game.gd が所有。このファイルはロジックのみ。
## * 第1引数に必ず game.gd インスタンス（Node）を受け取る。
## * 演出（ダメージ数字・ノードフラッシュ・カメラシェイク・SE）は game.gd に残したヘルパ
##   （_show_damage_number / _camera_shake / _play_se）経由で呼ぶ。
##
## ── ここに書くべきもの ───────────────────────────────────
## * プレイヤー→敵攻撃（player_attack）
## * 敵→プレイヤー被弾＋死亡判定（apply_damage_to_player）
## * 敵撃破処理・経験値／レベルアップ（kill_enemy / check_level_up）
## * 攻撃／防御力計算（calc_atk / calc_def）
##
## ── ここに書かないべきもの ─────────────────────────────
## * 敵側AIからの攻撃発動フロー（EnemyAI.attack が Combat.apply_damage_to_player を呼ぶ）
## * 状態異常の付与（ItemEffects.apply_status_to_*）
## * ゲームオーバー画面遷移（game._trigger_game_over）

# ─── 攻撃／防御力計算（修正値＋印ボーナス込み） ────────────
static func calc_atk(game: Node) -> int:
	var weapon: Dictionary = game.p_weapon
	var base: int = int(game.p_atk_base) + int(weapon.get("atk", 0)) + int(game.p_ring.get("atk", 0))
	base += int(weapon.get("plus", 0))
	base += SealSystem.seal_atk_bonus(weapon)
	base += SkillTree.atk_bonus(game)
	return base

static func calc_def(game: Node) -> int:
	var shield: Dictionary = game.p_shield
	var base: int = int(game.p_def_base) + int(shield.get("def", 0)) + int(game.p_ring.get("def", 0))
	base += int(shield.get("plus", 0))
	base += SealSystem.seal_def_bonus(shield)
	return base

# ─── プレイヤー → 敵 ──────────────────────────────────────
static func player_attack(game: Node, enemy: Dictionary) -> void:
	var p_grid: Vector2i = game.p_grid
	var diff: Vector2i = (enemy["grid_pos"] as Vector2i) - p_grid
	if diff != Vector2i.ZERO:
		game.p_facing = Vector2i(sign(diff.x), sign(diff.y))
	var dmg: int = max(1, calc_atk(game) - int(enemy["data"].get("def", 0)))
	# 炎印（武器固有 or 合成印）
	if game.p_weapon.get("effect", "") == "burn" or SealSystem.has_burn_seal(game.p_weapon):
		dmg += randi_range(1, 4)
	# 会心の一撃（combat_2）: 10%で1.5倍
	if SkillTree.has(game, "combat_2") and randf() < 0.10:
		dmg = int(dmg * 1.5)
		game.add_message("会心の一撃！")
	enemy["hp"] -= dmg
	enemy["alerted"] = true
	enemy["node"].call("flash", Color(1.0, 0.2, 0.2))
	game._show_damage_number(enemy["grid_pos"] as Vector2i, str(dmg), Color(1.0, 0.4, 0.4))
	game._play_se("attack")
	game.add_message("%s に %d ダメージ！" % [enemy["data"]["name"], dmg])
	if enemy["hp"] <= 0:
		kill_enemy(game, enemy)
		return
	if SealSystem.has_curse_seal(game.p_weapon) and randf() < 0.05:
		ItemEffects.apply_status_to_enemy(game, enemy, "paralyze", 3)
		game.add_message("呪いの印が発動！")
	# 連続攻撃（combat_3）: 15%で2回目の攻撃（再帰しない）
	if not bool(game._double_attack_active) and SkillTree.has(game, "combat_3") and randf() < 0.10:
		game._double_attack_active = true
		game.add_message("連続攻撃！")
		player_attack(game, enemy)
		game._double_attack_active = false

# ─── 敵撃破＋経験値・レベル処理 ────────────────────────────
## by_companion=true のときは経験値を与えない（仲間が倒した場合）
static func kill_enemy(game: Node, enemy: Dictionary, by_companion: bool = false) -> void:
	# 興味状態で倒された場合は仲間勧誘のチャンス
	if not by_companion and int(enemy.get("interested_turns", 0)) > 0:
		_try_recruit(game, enemy)
		return
	game.add_message("%s を倒した！" % enemy["data"]["name"])
	# 合成虫: 吸収していたアイテムをドロップ
	if enemy.has("absorbed"):
		var ep: Vector2i = enemy["grid_pos"] as Vector2i
		for absorbed_item: Dictionary in enemy["absorbed"]:
			game._place_floor_item(absorbed_item, game._find_free_drop_pos(ep))
			game.add_message("%s が落ちた。" % SealSystem.display_name(absorbed_item))
	# 図鑑登録（初撃破時のみメッセージ）
	var enemy_id: String = enemy["data"].get("id", "")
	if Bestiary.discover_enemy(enemy_id):
		game.add_message("図鑑に %s を登録した。" % enemy["data"]["name"])
	if not by_companion:
		var gained_exp: int = int(enemy["data"].get("exp", 0))
		if game.p_ring.get("effect", "") == "exp_boost":
			gained_exp = int(gained_exp * 1.5)
		game.p_exp = int(game.p_exp) + gained_exp
		game.add_message("経験値 %d 獲得。" % gained_exp)
		check_level_up(game)
	enemy["node"].queue_free()
	game.enemies.erase(enemy)

## 興味状態で倒された敵から仲間勧誘の会話を発火する
static func _try_recruit(game: Node, enemy: Dictionary) -> void:
	# 図鑑には倒した実績として登録（仲間化前提でも撃破は撃破）
	var enemy_id: String = enemy["data"].get("id", "")
	Bestiary.discover_enemy(enemy_id)
	# 隣接マスの空きを先に確保（なければ仲間化不可で通常撃破）
	var spawn_pos: Vector2i = game._find_free_adjacent_tile()
	# 会話用に enemy ノードはまだ消さず保留
	var name: String = enemy["data"].get("name", "敵")
	var line: String = enemy["data"].get("recruit_line",
		"…ねぇ、私を仲間にしない？\nあなたの旅を、一緒に行きたいの。")
	DialogUI.start(game, name,
		[line],
		["はい", "いいえ"],
		func(choice: int) -> void:
			_finish_recruit(game, enemy, spawn_pos, choice))

static func _finish_recruit(game: Node, enemy: Dictionary, spawn_pos: Vector2i, choice: int) -> void:
	if choice == 0:
		# はい：仲間化
		if spawn_pos == Vector2i(-1, -1):
			game.add_message("…しかし周囲に空きがない。")
			_finalize_kill_no_exp(game, enemy)
			return
		if not CompanionAI.add_from_enemy(game, enemy, spawn_pos):
			# 満員などで失敗
			_finalize_kill_no_exp(game, enemy)
			return
		Bestiary.recruit_enemy(enemy["data"].get("id", ""))
		game.add_message("★ %s が仲間に加わった！" % enemy["data"].get("name", "?"))
		_finalize_kill_no_exp(game, enemy)
	else:
		# いいえ：そのまま撃破（経験値あり）
		game.add_message("%s を倒した！" % enemy["data"]["name"])
		var gained_exp: int = int(enemy["data"].get("exp", 0))
		if game.p_ring.get("effect", "") == "exp_boost":
			gained_exp = int(gained_exp * 1.5)
		game.p_exp = int(game.p_exp) + gained_exp
		game.add_message("経験値 %d 獲得。" % gained_exp)
		check_level_up(game)
		_finalize_kill_no_exp(game, enemy)

static func _finalize_kill_no_exp(game: Node, enemy: Dictionary) -> void:
	if is_instance_valid(enemy.get("node")):
		enemy["node"].queue_free()
	game.enemies.erase(enemy)
	# 会話で保留されていたターンを進める
	game._end_player_turn()

static func check_level_up(game: Node) -> void:
	while int(game.p_exp) >= int(game.p_exp_next):
		game.p_exp     = int(game.p_exp) - int(game.p_exp_next)
		game.p_level   = int(game.p_level) + 1
		game.p_exp_next = int(int(game.p_exp_next) * 1.8)
		game.p_hp_max  = int(game.p_hp_max) + 8
		game.p_hp       = min(int(game.p_hp) + 8, int(game.p_hp_max))
		game.p_atk_base = int(game.p_atk_base) + 1
		game.p_def_base = int(game.p_def_base) + 1
		game.skill_points = int(game.skill_points) + 1
		game.add_message("レベルアップ！ LV %d になった！（SP+1）" % int(game.p_level))

# ─── 敵 → プレイヤー被弾 ──────────────────────────────────
## source: ダメージ源のテキスト（敵名／"空腹"／"毒"／"爆発の本" など）
static func apply_damage_to_player(game: Node, dmg: int, source: String) -> void:
	game.p_hp = int(game.p_hp) - dmg
	game._dash_interrupt = true
	game._player_node.call("flash", Color(1.0, 0.2, 0.2))
	game._show_damage_number(game.p_grid, str(dmg), Color(1.0, 0.7, 0.7))
	game._camera_shake()
	game._play_se("hit")
	if source != "":
		game.add_message("%s から %d ダメージ！" % [source, dmg])
	if int(game.p_hp) <= 0:
		# 不屈（survival_4）: フロア1回だけHP1で耐える
		if SkillTree.has(game, "survival_4") and not game._skill_survived_fatal:
			game.p_hp = 1
			game._skill_survived_fatal = true
			game.add_message("不屈のスキルが発動！ HP1で踏みとどまった！")
			game._player_node.call("flash", Color(1.0, 1.0, 0.2))
			return
		game.p_hp = 0
		var cause: String
		if source == "空腹":
			cause = "餓死"
		elif source == "爆発の本":
			cause = "爆発の本で自滅"
		elif source != "":
			cause = "%s に倒された" % source
		else:
			cause = "力尽きた"
		game._trigger_game_over(cause)
