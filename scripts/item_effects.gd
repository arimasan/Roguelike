class_name ItemEffects
extends RefCounted

## アイテム使用時の効果を適用するヘルパー関数集。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態（プレイヤーHP、インベントリ、敵リストなど）はすべて game.gd が所有する。
##   このファイルは「効果ロジック」のみを担当し、状態は game 経由で読み書きする。
## * 必ず第1引数に game.gd インスタンス（Node）を受け取る。
## * UI状態遷移（game_state 変更）、セーブ/ロード、入力処理、HUD再描画はここに書かない。
##
## ── ここに書くべきもの ───────────────────────────────────
## * アイテム使用ロジック（apply_item / apply_scroll / apply_pot / apply_staff）
## * 状態異常付与（apply_status_to_player / apply_status_to_enemy）
## * アイテム効果が必要とする補助（nearest_visible_enemy / knockback_enemy）
##
## ── ここに書かないべきもの ─────────────────────────────
## * 保存の箱UI（InventoryUI.open_storage_pot / handle_storage_pot_input 等）
## * ステータス視覚更新（_refresh_*_status_visual → game.gd）
## * 投擲ロジック（throw_system.gd へ分離予定）
## * 敵出現ロジック（_spawn_* → game.gd）

# ─── 状態異常付与 ──────────────────────────────────────────
static func apply_status_to_player(game: Node, status: String, turns: int) -> void:
	# 状態異常耐性（survival_3）: 50% で無効化
	if SkillTree.has(game, "survival_3") and randf() < 0.30:
		game.add_message("状態異常を跳ね返した！")
		game._dash_interrupt = true
		return
	match status:
		"poison":
			game.p_poisoned_turns = max(game.p_poisoned_turns, turns)
			game.add_message("毒にやられた！")
		"sleep":
			game.p_sleep_turns = max(game.p_sleep_turns, turns)
			game.add_message("眠気に襲われた…")
		"blind":
			game.p_blind_turns = max(game.p_blind_turns, turns)
			game.add_message("目の前が真っ暗になった！")
		"slow":
			game.p_slow_turns = max(game.p_slow_turns, turns)
			game.add_message("動きが鈍くなった！")
		"confuse":
			game.p_confused_turns = max(game.p_confused_turns, turns)
			game.add_message("頭がぐるぐるする！")
		"paralyze":
			game.p_paralyzed_turns = max(game.p_paralyzed_turns, turns)
			game.add_message("体が動かない！")
	game._dash_interrupt = true
	game._refresh_player_status_visual()

static func apply_status_to_enemy(game: Node, enemy: Dictionary, status: String, turns: int) -> void:
	var name: String = enemy["data"].get("name", "敵")
	match status:
		"poison":
			enemy["poisoned"] = max(int(enemy.get("poisoned", 0)), turns)
			game.add_message("%s は毒にかかった！" % name)
		"sleep":
			enemy["asleep"]       = true
			enemy["asleep_turns"] = max(int(enemy.get("asleep_turns", 0)), turns)
			game.add_message("%s は眠り込んだ！" % name)
		"slow":
			enemy["slow_turns"] = max(int(enemy.get("slow_turns", 0)), turns)
			game.add_message("%s の動きが鈍くなった！" % name)
		"confuse":
			enemy["confused_turns"] = max(int(enemy.get("confused_turns", 0)), turns)
			game.add_message("%s は混乱した！" % name)
		"paralyze":
			enemy["paralyzed_turns"] = max(int(enemy.get("paralyzed_turns", 0)), turns)
			game.add_message("%s は麻痺した！" % name)
		"seal":
			enemy["sealed"] = true
			game.add_message("%s は封印された！" % name)
		"interest":
			enemy["interested_turns"] = max(int(enemy.get("interested_turns", 0)), turns)
			game.add_message("%s は %s に興味を持った！" % [name, "あなた"])
	game._refresh_enemy_status_visual(enemy)

# ─── アイテム使用エントリポイント ──────────────────────────
## 戻り値: true=アイテム消費（インベントリから削除）, false=残す
static func apply_item(game: Node, item: Dictionary) -> bool:
	# 図鑑登録（初使用時のみメッセージ）
	var item_id: String = item.get("id", "")
	if Bestiary.discover_item(item_id):
		game.add_message("図鑑に %s を登録した。" % item.get("name", "?"))
	var t: int = item.get("type", -1)
	var is_cursed: bool = item.get("cursed", false)
	var is_blessed: bool = item.get("blessed", false)
	match t:
		ItemData.TYPE_WEAPON:
			game._play_item_se(item)
			if game.p_weapon.get("_iid", -1) == item.get("_iid", -2):
				# 外そうとした：呪われていれば失敗
				if game.p_weapon.get("cursed", false):
					game.add_message("呪われていて外せない！")
					return false
				game.p_weapon = {}
				game.add_message("%s を外した。" % SealSystem.display_name(item))
			else:
				game.p_weapon = item
				game.add_message("%s を装備した。" % SealSystem.display_name(item))
				if is_cursed:
					game.add_message("…呪われていて外せない！")
			return false

		ItemData.TYPE_SHIELD:
			game._play_item_se(item)
			if game.p_shield.get("_iid", -1) == item.get("_iid", -2):
				if game.p_shield.get("cursed", false):
					game.add_message("呪われていて外せない！")
					return false
				game.p_shield = {}
				game.add_message("%s を外した。" % SealSystem.display_name(item))
			else:
				game.p_shield = item
				game.add_message("%s を装備した。" % SealSystem.display_name(item))
				if is_cursed:
					game.add_message("…呪われていて外せない！")
			return false

		ItemData.TYPE_RING:
			game._play_item_se(item)
			if game.p_ring.get("_iid", -1) == item.get("_iid", -2):
				if game.p_ring.get("cursed", false):
					game.add_message("呪われていて外せない！")
					return false
				game.p_ring = {}
				game.add_message("%s を外した。" % SealSystem.display_name(item))
			else:
				game.p_ring = item
				game.add_message("%s を装備した。" % SealSystem.display_name(item))
				if is_cursed:
					game.add_message("…呪われていて外せない！")
			return false

		ItemData.TYPE_FOOD:
			# 呪い：使用失敗（消費しない）
			if is_cursed:
				game.add_message("呪われていて食べられない！")
				return false
			game._play_item_se(item)
			var fullness_gain: int = item.get("fullness", 0)
			if is_blessed and fullness_gain > 0:
				fullness_gain *= 2
			if fullness_gain > 0:
				game.p_fullness = min(100, game.p_fullness + fullness_gain)
				game._hunger_accum = 0.0
				game.add_message("%s を食べた。満腹度が回復した。" % SealSystem.display_name(item))
				if is_blessed:
					game.add_message("祝福の効果で満腹度が大きく回復！")
			elif fullness_gain < 0:
				game.p_fullness = max(0, game.p_fullness + fullness_gain)
				game.add_message("腐った食料を食べてしまった！")
			return true

		ItemData.TYPE_POTION:
			if is_cursed:
				game.add_message("呪われていて飲めない！")
				return false
			game._play_item_se(item)
			game.add_message("%s を飲んだ。" % SealSystem.display_name(item))
			var mult: int = 2 if is_blessed else 1
			var heal: int = item.get("heal", 0) * mult
			if heal > 0:
				game.p_hp = min(game.p_hp_max, game.p_hp + heal)
				game.add_message("HP が %d 回復した。" % heal)
			var atk_up: int = item.get("atk_up", 0) * mult
			if atk_up > 0:
				game.p_atk_base += atk_up
				game.add_message("力が %d 上がった！" % atk_up)
			if is_blessed and (heal > 0 or atk_up > 0):
				game.add_message("祝福の効果で効き目が倍増！")
			match item.get("effect", ""):
				"antidote":
					var cured := false
					if game.p_poisoned_turns > 0:
						game.p_poisoned_turns = 0
						cured = true
					if game.p_blind_turns > 0:
						game.p_blind_turns = 0
						cured = true
					if game.p_sleep_turns > 0:
						game.p_sleep_turns = 0
						cured = true
					game.add_message("すべての状態異常が治った！" if cured else "特に変化はなかった。")
				"detox":
					if game.p_poisoned_turns > 0:
						game.p_poisoned_turns = 0
						game.add_message("毒が治った！")
					else:
						game.add_message("毒にはかかっていなかった。")
				"awaken":
					if game.p_sleep_turns > 0:
						game.p_sleep_turns = 0
						game.add_message("眠気が吹き飛んだ！")
					else:
						game.add_message("眠くはなかった。")
				"charm":
					game.add_message("自分に飲んでも効果はないようだ…")
			return true

		ItemData.TYPE_SCROLL:
			if is_cursed:
				game.add_message("呪われていて読めない！")
				return false
			apply_scroll(game, item)
			# 祝福された書：祝福を解除して消費しない（もう一度使える）
			if is_blessed:
				item["blessed"] = false
				game.add_message("祝福が解けた。もう一度使える。")
				return false
			return true

		ItemData.TYPE_POT:
			var pot_eff: String = item.get("effect", "")
			if pot_eff == "storage" or pot_eff == "synthesis":
				return InventoryUI.open_storage_pot(game, item)
			apply_pot(game, item)
			# 節約（technique_4）: 20%で使用回数を消費しない
			if SkillTree.has(game, "technique_4") and randf() < 0.15:
				game.add_message("節約！使用回数を消費しなかった。")
				return false
			var uses: int = item.get("uses", 1) - 1
			if uses <= 0:
				return true
			item["uses"] = uses
			return false

		ItemData.TYPE_STAFF:
			apply_staff(game, item)
			if SkillTree.has(game, "technique_4") and randf() < 0.15:
				game.add_message("節約！使用回数を消費しなかった。")
				return false
			var uses: int = item.get("uses", 1) - 1
			if uses <= 0:
				game.add_message("%s は砕け散った。" % item.get("name","?"))
				return true
			item["uses"] = uses
			return false

	return true

# ─── 本（スクロール） ──────────────────────────────────────
static func apply_scroll(game: Node, item: Dictionary) -> void:
	game._play_item_se(item)
	var effect: String = item.get("effect", "")
	game.add_message("本を読んだ！（%s）" % item.get("name","?"))
	match effect:
		"identify":
			game.add_message("すべてのアイテムを識別した。（効果なし）")
		"warp":
			game.p_grid = game.generator.random_floor_pos()
			game._player_node.call("set_grid", game.p_grid.x, game.p_grid.y)
			game.add_message("転移した！")
		"explosion":
			game.add_message("爆発が起きた！")
			for enemy in game.enemies.duplicate():
				var dist: int = (enemy["grid_pos"] as Vector2i).distance_squared_to(game.p_grid)
				if dist <= 9:
					var dmg := randi_range(15, 25)
					enemy["hp"] -= dmg
					game.add_message("%s に %d ダメージ！" % [enemy["data"]["name"], dmg])
					if enemy["hp"] <= 0:
						Combat.kill_enemy(game, enemy)
			Combat.apply_damage_to_player(game, randi_range(3, 8), "爆発の本")
		"uncurse":
			var uncursed := false
			if game.p_weapon.get("cursed", false):
				game.p_weapon["cursed"] = false
				game.add_message("%s の呪いが解けた！" % game.p_weapon.get("name", "武器"))
				uncursed = true
			if game.p_shield.get("cursed", false):
				game.p_shield["cursed"] = false
				game.add_message("%s の呪いが解けた！" % game.p_shield.get("name", "盾"))
				uncursed = true
			if game.p_ring.get("cursed", false):
				game.p_ring["cursed"] = false
				game.add_message("%s の呪いが解けた！" % game.p_ring.get("name", "指輪"))
				uncursed = true
			for inv_item: Dictionary in game.p_inventory:
				if inv_item.get("cursed", false):
					inv_item["cursed"] = false
					uncursed = true
			if uncursed:
				game.add_message("持ち物の呪いをすべて解いた！")
			else:
				game.add_message("呪われたものは見つからなかった。")
		"sleep":
			for enemy in game.enemies:
				if game.fov_visible.has(enemy["grid_pos"] as Vector2i):
					enemy["asleep"] = true
			game.add_message("周囲の敵が眠りについた！")
		"map":
			for y in DungeonGenerator.MAP_H:
				for x in DungeonGenerator.MAP_W:
					game.explored[Vector2i(x, y)] = true
			game.add_message("フロア全体が明らかになった！")
			game._map_drawer.call("queue_redraw")
		"monster":
			EnemyAI.spawn_one_near_player(game)
			game.add_message("モンスターが現れた！")
		"slow":
			var affected := 0
			for enemy in game.enemies:
				if game.fov_visible.has(enemy["grid_pos"]):
					apply_status_to_enemy(game, enemy, "slow", 6)
					affected += 1
			game.add_message("周囲の敵の動きが鈍くなった！" if affected > 0 else "効果はなかった。")
		"confuse":
			var affected := 0
			for enemy in game.enemies:
				if game.fov_visible.has(enemy["grid_pos"]):
					apply_status_to_enemy(game, enemy, "confuse", 5)
					affected += 1
			game.add_message("周囲の敵が混乱した！" if affected > 0 else "効果はなかった。")

# ─── 箱（pot: storage以外） ────────────────────────────────
static func apply_pot(game: Node, item: Dictionary) -> void:
	game._play_item_se(item)
	var effect: String = item.get("effect", "")
	game.add_message("箱を使った！（%s）" % item.get("name","?"))
	match effect:
		"heal":
			var heal := randi_range(15, 30)
			game.p_hp = min(game.p_hp_max, game.p_hp + heal)
			game.add_message("HP が %d 回復した。" % heal)
		"poison":
			var hit_count := 0
			for enemy in game.enemies:
				if game.fov_visible.has(enemy["grid_pos"] as Vector2i):
					enemy["poisoned"] = 8
					enemy["node"].call("flash", Color(0.5, 1.0, 0.2))
					game.add_message("%s に毒を浴びせた！" % enemy["data"]["name"])
					hit_count += 1
			if hit_count == 0:
				game.add_message("しかし周囲に敵はいない。")
		"strength":
			game.p_atk_base += 3
			game.add_message("力が 3 上がった！")
		"blind":
			game.p_blind_turns = 10
			game.add_message("目の前が真っ暗になった！（10ターン視界1）")

# ─── 杖 ────────────────────────────────────────────────────
static func apply_staff(game: Node, item: Dictionary) -> void:
	game._play_item_se(item)
	var effect: String = item.get("effect", "")
	game.add_message("%s を振った！" % item.get("name","?"))
	match effect:
		"fire":
			var target = nearest_visible_enemy(game)
			if target == null:
				game.add_message("しかし周囲に敵はいない。")
				return
			var dmg := randi_range(20, 35)
			target["hp"] -= dmg
			game.add_message("%s に炎が燃え上がった！%d ダメージ！" % [target["data"]["name"], dmg])
			if target["hp"] <= 0:
				Combat.kill_enemy(game, target)

		"thunder":
			var hit := false
			for enemy in game.enemies.duplicate():
				if game.fov_visible.has(enemy["grid_pos"] as Vector2i):
					var dmg := randi_range(10, 18)
					enemy["hp"] -= dmg
					game.add_message("%s に雷が落ちた！%d ダメージ！" % [enemy["data"]["name"], dmg])
					if enemy["hp"] <= 0:
						Combat.kill_enemy(game, enemy)
					hit = true
			if not hit:
				game.add_message("しかし周囲に敵はいない。")

		"freeze":
			var hit := false
			for enemy in game.enemies:
				if game.fov_visible.has(enemy["grid_pos"] as Vector2i):
					enemy["asleep"]       = true
					enemy["asleep_turns"] = 3
					game.add_message("%s が凍りついた！" % enemy["data"]["name"])
					hit = true
			if not hit:
				game.add_message("しかし周囲に敵はいない。")

		"knockback":
			var target = nearest_visible_enemy(game)
			if target == null:
				game.add_message("しかし周囲に敵はいない。")
				return
			knockback_enemy(game, target, 5)
			game.add_message("%s を吹き飛ばした！" % target["data"]["name"])

		"seal":
			var target = nearest_visible_enemy(game)
			if target == null:
				game.add_message("しかし周囲に敵はいない。")
				return
			target["asleep"]       = true
			target["asleep_turns"] = 5
			game.add_message("%s を封印した！" % target["data"]["name"])

		"magic":
			var target = nearest_visible_enemy(game)
			if target == null:
				game.add_message("しかし周囲に敵はいない。")
				return
			target["hp"] = max(1, target["hp"] / 2)
			game.add_message("%s のHPが半分になった！" % target["data"]["name"])

		"charm":
			var target = nearest_visible_enemy(game)
			if target == null:
				game.add_message("しかし周囲に敵はいない。")
				return
			apply_status_to_enemy(game, target, "interest", 6)

# ─── ヘルパー ───────────────────────────────────────────────
## 視界内で最も近い敵を返す（なければ null）
static func nearest_visible_enemy(game: Node) -> Variant:
	var best: Variant = null
	var best_dist: int = 999999
	for enemy in game.enemies:
		var ep := enemy["grid_pos"] as Vector2i
		if game.fov_visible.has(ep):
			var d: int = ep.distance_squared_to(game.p_grid)
			if d < best_dist:
				best_dist = d
				best      = enemy
	return best

## 敵をプレイヤーから遠ざける方向に steps マス押し飛ばす
static func knockback_enemy(game: Node, enemy: Dictionary, steps: int) -> void:
	var player_pos: Vector2i = game.p_grid
	var diff: Vector2i = (enemy["grid_pos"] as Vector2i) - player_pos
	var dx: int = sign(diff.x)
	var dy: int = sign(diff.y)
	if dx == 0 and dy == 0:
		return
	for _i in steps:
		var np: Vector2i = (enemy["grid_pos"] as Vector2i) + Vector2i(dx, dy)
		if np.x < 0 or np.x >= DungeonGenerator.MAP_W \
				or np.y < 0 or np.y >= DungeonGenerator.MAP_H:
			break
		if not game.generator.is_walkable(np.x, np.y):
			break
		if game._enemy_at(np) != null:
			break
		enemy["grid_pos"] = np
		enemy["node"].call("set_grid", np.x, np.y)
