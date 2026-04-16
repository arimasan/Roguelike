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

# ─── 攻撃／防御力計算 ─────────────────────────────────────
static func calc_atk(game: Node) -> int:
	return int(game.p_atk_base) + int(game.p_weapon.get("atk", 0)) + int(game.p_ring.get("atk", 0))

static func calc_def(game: Node) -> int:
	return int(game.p_def_base) + int(game.p_shield.get("def", 0)) + int(game.p_ring.get("def", 0))

# ─── プレイヤー → 敵 ──────────────────────────────────────
static func player_attack(game: Node, enemy: Dictionary) -> void:
	var p_grid: Vector2i = game.p_grid
	var diff: Vector2i = (enemy["grid_pos"] as Vector2i) - p_grid
	if diff != Vector2i.ZERO:
		game.p_facing = Vector2i(sign(diff.x), sign(diff.y))
	var dmg: int = max(1, calc_atk(game) - int(enemy["data"].get("def", 0)))
	# 炎の剣ボーナス
	if game.p_weapon.get("effect", "") == "burn":
		dmg += randi_range(1, 4)
	enemy["hp"] -= dmg
	enemy["alerted"] = true
	enemy["node"].call("flash", Color(1.0, 0.2, 0.2))
	game._show_damage_number(enemy["grid_pos"] as Vector2i, str(dmg), Color(1.0, 0.4, 0.4))
	game._play_se("attack")
	game.add_message("%s に %d ダメージ！" % [enemy["data"]["name"], dmg])
	if enemy["hp"] <= 0:
		kill_enemy(game, enemy)

# ─── 敵撃破＋経験値・レベル処理 ────────────────────────────
static func kill_enemy(game: Node, enemy: Dictionary) -> void:
	game.add_message("%s を倒した！" % enemy["data"]["name"])
	var gained_exp: int = int(enemy["data"].get("exp", 0))
	if game.p_ring.get("effect", "") == "exp_boost":
		gained_exp = int(gained_exp * 1.5)
	game.p_exp = int(game.p_exp) + gained_exp
	game.add_message("経験値 %d 獲得。" % gained_exp)
	enemy["node"].queue_free()
	game.enemies.erase(enemy)
	check_level_up(game)

static func check_level_up(game: Node) -> void:
	while int(game.p_exp) >= int(game.p_exp_next):
		game.p_exp     = int(game.p_exp) - int(game.p_exp_next)
		game.p_level   = int(game.p_level) + 1
		game.p_exp_next = int(int(game.p_exp_next) * 1.8)
		game.p_hp_max  = int(game.p_hp_max) + 8
		game.p_hp       = min(int(game.p_hp) + 8, int(game.p_hp_max))
		game.p_atk_base = int(game.p_atk_base) + 1
		game.p_def_base = int(game.p_def_base) + 1
		game.add_message("レベルアップ！ LV %d になった！" % int(game.p_level))

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
