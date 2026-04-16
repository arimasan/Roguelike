class_name EnemySkills
extends RefCounted

## 敵スキルの発動判定と効果適用を担当する。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 各スキルは enemy_data.gd の "skills" 配列に定義。
##   { "id", "name", "effect", "cooldown", "chance", ... 効果固有パラメタ }
## * 各敵 dict に "skill_cooldowns": Dictionary<id, 残りターン> を持たせる。
##   EnemyAI.take_turn から毎ターン tick_cooldowns() を呼ぶ。
## * try_activate() が発動可能なスキルを抽選し、発動した場合 true を返す。
##   true の場合は通常行動（移動/攻撃）をスキップする。
## * 各効果（ranged_damage / ranged_status / breath_line / multi_attack / summon / room_aoe）は
##   このファイル内の _execute_* に実装。
##
## ── 依存 ─────────────────────────────────────────────────
## * game.gd の add_message / _player_node / _play_se / _show_damage_number
## * Fov.has_los（視線判定）
## * Combat.calc_def / Combat.apply_damage_to_player
## * ItemEffects.apply_status_to_player

## 全スキルのCTを1減らす
static func tick_cooldowns(enemy: Dictionary) -> void:
	var cds: Dictionary = enemy.get("skill_cooldowns", {})
	for sid: String in cds.keys():
		if cds[sid] > 0:
			cds[sid] -= 1

## 発動可能スキルを抽選し、発動した場合は true（通常行動をスキップ）
## アラート済み（プレイヤー視認/追跡中）の敵のみが対象
static func try_activate(game: Node, enemy: Dictionary) -> bool:
	var skills: Array = enemy["data"].get("skills", [])
	if skills.is_empty():
		return false
	var ep: Vector2i = enemy["grid_pos"] as Vector2i
	var pp: Vector2i = game.p_grid
	var cds: Dictionary = enemy.get("skill_cooldowns", {})
	# HP条件用の比率
	var hp_ratio: float = float(enemy["hp"]) / float(max(1, int(enemy["data"].get("hp", 1))))
	# 発動候補を収集
	var candidates: Array = []
	for skill: Dictionary in skills:
		var sid: String = skill.get("id", "")
		if cds.get(sid, 0) > 0:
			continue
		# HP条件
		var hp_below: float = float(skill.get("hp_below", 1.1))   # 1.1: 実質無条件
		if hp_ratio > hp_below:
			continue
		# 効果別の発動可否
		if not _can_activate(game, enemy, skill, ep, pp):
			continue
		# 抽選
		if randf() > float(skill.get("chance", 1.0)):
			continue
		candidates.append(skill)
	if candidates.is_empty():
		return false
	# 最初のマッチを使う（複数ある場合は配列順）
	var chosen: Dictionary = candidates[0]
	_execute(game, enemy, chosen)
	# CT設定
	if not enemy.has("skill_cooldowns"):
		enemy["skill_cooldowns"] = {}
	enemy["skill_cooldowns"][chosen["id"]] = int(chosen.get("cooldown", 0))
	return true

# ─── 発動可能判定 ─────────────────────────────────────────
static func _can_activate(game: Node, enemy: Dictionary, skill: Dictionary,
		ep: Vector2i, pp: Vector2i) -> bool:
	match skill.get("effect", ""):
		"ranged_damage", "ranged_status":
			var rng: int = int(skill.get("range", 1))
			if ep.distance_squared_to(pp) <= 2:
				return false   # 隣接時は通常攻撃優先
			if ep.distance_squared_to(pp) > rng * rng:
				return false
			return Fov.has_los(game, ep.x, ep.y, pp.x, pp.y)
		"breath_line":
			var rng2: int = int(skill.get("range", 1))
			# 直線上（同じ行・列・対角線）かつ射程内
			var dx: int = pp.x - ep.x
			var dy: int = pp.y - ep.y
			if not (dx == 0 or dy == 0 or absi(dx) == absi(dy)):
				return false
			var dist: int = max(absi(dx), absi(dy))
			if dist == 0 or dist > rng2:
				return false
			return Fov.has_los(game, ep.x, ep.y, pp.x, pp.y)
		"multi_attack", "drain_hp", "knockback":
			return ep.distance_squared_to(pp) <= 2
		"heal_self":
			# 自身のHPが指定割合以下のとき発動
			return true   # hp_below は try_activate 側でチェック済み
		"summon":
			return game.fov_visible.has(ep)   # プレイヤー視界内
		"room_aoe":
			# 同じ部屋にいるときのみ
			return _same_room(game, ep, pp)
	return false

static func _same_room(game: Node, a: Vector2i, b: Vector2i) -> bool:
	for room: Rect2i in game.generator.rooms:
		if room.has_point(a) and room.has_point(b):
			return true
	return false

# ─── 効果実行 ─────────────────────────────────────────────
static func _execute(game: Node, enemy: Dictionary, skill: Dictionary) -> void:
	var name: String = enemy["data"].get("name", "敵")
	var sname: String = skill.get("name", "スキル")
	game.add_message("%s は %s を使った！" % [name, sname])
	if skill.has("se"):
		game._play_se(skill["se"])
	match skill.get("effect", ""):
		"ranged_damage":   _execute_ranged_damage(game, enemy, skill)
		"ranged_status":   _execute_ranged_status(game, enemy, skill)
		"breath_line":     _execute_breath_line(game, enemy, skill)
		"multi_attack":    _execute_multi_attack(game, enemy, skill)
		"summon":          _execute_summon(game, enemy, skill)
		"room_aoe":        _execute_room_aoe(game, enemy, skill)
		"drain_hp":        _execute_drain_hp(game, enemy, skill)
		"heal_self":       _execute_heal_self(game, enemy, skill)
		"knockback":       _execute_knockback(game, enemy, skill)

static func _execute_ranged_damage(game: Node, enemy: Dictionary, skill: Dictionary) -> void:
	var dmg_range: Array = skill.get("damage", [1, 1])
	var dmg: int = randi_range(int(dmg_range[0]), int(dmg_range[1]))
	# 防御は無視（魔法/遠距離扱い）
	Combat.apply_damage_to_player(game, dmg, enemy["data"].get("name", "敵"))

static func _execute_ranged_status(game: Node, enemy: Dictionary, skill: Dictionary) -> void:
	var status: String = skill.get("status", "")
	var turns: int = int(skill.get("turns", 3))
	if status == "":
		return
	ItemEffects.apply_status_to_player(game, status, turns)

static func _execute_breath_line(game: Node, enemy: Dictionary, skill: Dictionary) -> void:
	var dmg_range: Array = skill.get("damage", [1, 1])
	var dmg: int = randi_range(int(dmg_range[0]), int(dmg_range[1]))
	Combat.apply_damage_to_player(game, dmg, enemy["data"].get("name", "敵"))

static func _execute_multi_attack(game: Node, enemy: Dictionary, skill: Dictionary) -> void:
	# 通常攻撃 + 追加攻撃
	EnemyAI.attack(game, enemy)
	var extra: int = int(skill.get("extra_hits", 1))
	for _i in extra:
		if game.p_hp <= 0:
			return
		EnemyAI.attack(game, enemy)

static func _execute_summon(game: Node, enemy: Dictionary, skill: Dictionary) -> void:
	var count: int = int(skill.get("count", 1))
	for _i in count:
		EnemyAI.spawn_wandering(game)

static func _execute_room_aoe(game: Node, enemy: Dictionary, skill: Dictionary) -> void:
	var dmg_range: Array = skill.get("damage", [1, 1])
	var dmg: int = randi_range(int(dmg_range[0]), int(dmg_range[1]))
	Combat.apply_damage_to_player(game, dmg, enemy["data"].get("name", "敵"))

## 隣接攻撃＋与ダメージの一部を自身回復（吸血）
static func _execute_drain_hp(game: Node, enemy: Dictionary, skill: Dictionary) -> void:
	var hp_before: int = int(game.p_hp)
	EnemyAI.attack(game, enemy)
	var dealt: int = max(0, hp_before - int(game.p_hp))
	if dealt <= 0:
		return
	var ratio: float = float(skill.get("drain_ratio", 0.5))
	var heal: int = max(1, int(round(float(dealt) * ratio)))
	var max_hp: int = int(enemy["data"].get("hp", enemy["hp"]))
	enemy["hp"] = min(int(enemy["hp"]) + heal, max_hp)
	enemy["node"].call("flash", Color(0.8, 0.2, 0.6))
	game.add_message("%s は HP を %d 吸い取った！" % [enemy["data"].get("name", "敵"), heal])

## 自身のHP回復
static func _execute_heal_self(game: Node, enemy: Dictionary, skill: Dictionary) -> void:
	var heal_range: Array = skill.get("heal", [10, 20])
	var heal: int = randi_range(int(heal_range[0]), int(heal_range[1]))
	var max_hp: int = int(enemy["data"].get("hp", enemy["hp"]))
	var before: int = int(enemy["hp"])
	enemy["hp"] = min(before + heal, max_hp)
	var actual: int = int(enemy["hp"]) - before
	enemy["node"].call("flash", Color(0.4, 1.0, 0.4))
	game.add_message("%s は HP を %d 回復した。" % [enemy["data"].get("name", "敵"), actual])

## 通常攻撃＋プレイヤーをノックバック（敵から離れる方向へ）
static func _execute_knockback(game: Node, enemy: Dictionary, skill: Dictionary) -> void:
	EnemyAI.attack(game, enemy)
	if game.p_hp <= 0:
		return
	var steps: int = int(skill.get("steps", 3))
	var ep: Vector2i = enemy["grid_pos"] as Vector2i
	var pp: Vector2i = game.p_grid
	var diff: Vector2i = pp - ep
	var dx: int = sign(diff.x)
	var dy: int = sign(diff.y)
	if dx == 0 and dy == 0:
		return
	for _i in steps:
		var np: Vector2i = game.p_grid + Vector2i(dx, dy)
		if np.x < 0 or np.x >= DungeonGenerator.MAP_W \
				or np.y < 0 or np.y >= DungeonGenerator.MAP_H:
			break
		if not game.generator.is_walkable(np.x, np.y):
			break
		if game._enemy_at(np) != null:
			break
		game.p_grid = np
		game._player_node.call("set_grid", np.x, np.y)
	game._update_fov()
	game._update_camera()
