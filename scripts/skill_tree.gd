class_name SkillTree
extends RefCounted

## スキルツリーのデータ定義・解放判定・効果有無の参照を担当する。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 状態（skill_points / skills_unlocked）は game.gd が所有。
## * 各スキルの「効果反映」はそれぞれの担当ファイル（Combat / Fov / ItemEffects 等）で
##   SkillTree.has(game, "skill_id") を呼んで判定する。
## * UI は skill_tree_ui.gd が担当。

const BRANCHES: Array[String] = ["combat", "explore", "survival", "technique"]

const BRANCH_NAMES: Dictionary = {
	"combat":    "戦闘",
	"explore":   "探索",
	"survival":  "生存",
	"technique": "技巧",
}

## 全スキル定義。requires が空なら Tier1（前提なし）。
const SKILLS: Dictionary = {
	# ── 戦闘 ──────────────────────────────────────
	"combat_1": {"branch":"combat", "tier":1, "cost":1,
		"name":"力の心得", "desc":"ATK+2", "requires":""},
	"combat_2": {"branch":"combat", "tier":2, "cost":2,
		"name":"会心の一撃", "desc":"攻撃時10%で1.5倍ダメージ", "requires":"combat_1"},
	"combat_3": {"branch":"combat", "tier":3, "cost":3,
		"name":"連続攻撃", "desc":"攻撃時10%で2回攻撃", "requires":"combat_2"},
	"combat_4": {"branch":"combat", "tier":4, "cost":4,
		"name":"剛力", "desc":"さらにATK+3", "requires":"combat_3"},
	# ── 探索 ──────────────────────────────────────
	"explore_1": {"branch":"explore", "tier":1, "cost":2,
		"name":"俊足", "desc":"5%で1ターン2回行動", "requires":""},
	"explore_2": {"branch":"explore", "tier":2, "cost":2,
		"name":"千里眼", "desc":"視野半径+2", "requires":"explore_1"},
	"explore_3": {"branch":"explore", "tier":3, "cost":3,
		"name":"罠感知", "desc":"視界内のワナ自動可視化", "requires":"explore_2"},
	"explore_4": {"branch":"explore", "tier":4, "cost":4,
		"name":"瞬足", "desc":"通路で1ターン2マス移動", "requires":"explore_3"},
	# ── 生存 ──────────────────────────────────────
	"survival_1": {"branch":"survival", "tier":1, "cost":1,
		"name":"頑丈", "desc":"最大HP+10", "requires":""},
	"survival_2": {"branch":"survival", "tier":2, "cost":2,
		"name":"省エネ", "desc":"満腹度減少速度が半分", "requires":"survival_1"},
	"survival_3": {"branch":"survival", "tier":3, "cost":3,
		"name":"状態異常耐性", "desc":"状態異常を30%で無効化", "requires":"survival_2"},
	"survival_4": {"branch":"survival", "tier":4, "cost":4,
		"name":"不屈", "desc":"フロア1回だけ致死ダメをHP1で耐える", "requires":"survival_3"},
	# ── 技巧 ──────────────────────────────────────
	"technique_1": {"branch":"technique", "tier":1, "cost":1,
		"name":"投擲強化", "desc":"投擲ダメージ+30%", "requires":""},
	"technique_2": {"branch":"technique", "tier":2, "cost":2,
		"name":"薬効増大", "desc":"薬・食料の効果+30%", "requires":"technique_1"},
	"technique_3": {"branch":"technique", "tier":3, "cost":3,
		"name":"印拡張", "desc":"武器/盾の印スロット+1", "requires":"technique_2"},
	"technique_4": {"branch":"technique", "tier":4, "cost":4,
		"name":"節約", "desc":"杖・箱の使用回数を15%で消費しない", "requires":"technique_3"},
}

# ─── 判定 ──────────────────────────────────────────────────
static func has(game: Node, skill_id: String) -> bool:
	return (game.skills_unlocked as Dictionary).get(skill_id, false)

static func can_unlock(game: Node, skill_id: String) -> bool:
	if has(game, skill_id):
		return false
	if not SKILLS.has(skill_id):
		return false
	var skill: Dictionary = SKILLS[skill_id]
	if int(game.skill_points) < int(skill["cost"]):
		return false
	var req: String = skill.get("requires", "")
	if not req.is_empty() and not has(game, req):
		return false
	return true

static func unlock(game: Node, skill_id: String) -> bool:
	if not can_unlock(game, skill_id):
		return false
	var skill: Dictionary = SKILLS[skill_id]
	game.skill_points = int(game.skill_points) - int(skill["cost"])
	game.skills_unlocked[skill_id] = true
	game.add_message("スキル「%s」を習得した！" % skill["name"])
	# 即時効果
	if skill_id == "survival_1":
		game.p_hp_max = int(game.p_hp_max) + 10
		game.p_hp = int(game.p_hp) + 10
	return true

## ブランチのスキルID一覧を Tier 順で返す
static func branch_skills(branch: String) -> Array:
	var result: Array = []
	for id: String in SKILLS:
		if SKILLS[id]["branch"] == branch:
			result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool:
		return int(SKILLS[a]["tier"]) < int(SKILLS[b]["tier"]))
	return result

# ─── 効果値ヘルパ ──────────────────────────────────────────
## 戦闘スキルによるATKボーナス
static func atk_bonus(game: Node) -> int:
	var bonus: int = 0
	if has(game, "combat_1"): bonus += 2
	if has(game, "combat_4"): bonus += 3
	return bonus

## 投擲ダメージ倍率（technique_1）
static func throw_damage_mult(game: Node) -> float:
	return 1.3 if has(game, "technique_1") else 1.0

## 薬効・食料倍率（technique_2）
static func consumable_mult(game: Node) -> float:
	return 1.3 if has(game, "technique_2") else 1.0

## 印スロット追加数（technique_3）
static func bonus_seal_slots(game: Node) -> int:
	return 1 if has(game, "technique_3") else 0

## FOV半径ボーナス（explore_2）
static func fov_radius_bonus(game: Node) -> int:
	return 2 if has(game, "explore_2") else 0
