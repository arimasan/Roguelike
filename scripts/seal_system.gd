class_name SealSystem
extends RefCounted

## 印（seal）と合成（synthesis）のロジック。
##
## ── 設計方針 ──────────────────────────────────────────────
## * 武器・盾は seal_slots（空き印数）を持ち、合成で他の武器の特性（印）を取り込める。
## * plus（修正値）は合成時に加算される。
## * 印効果は戦闘時に Combat 側で参照する。
##
## ── ここに書くべきもの ───────────────────────────────────
## * 合成ロジック（synthesize）
## * 合成の箱での自動合成判定（try_merge_in_pot）
## * 印効果の定数・参照
## * アイテム表示名生成（display_name）
##
## ── ここに書かないべきもの ─────────────────────────────
## * 戦闘計算（Combat）
## * 投擲判定（ThrowSystem）
## * UI描画（hud.gd）

# ─── 印効果定義 ────────────────────────────────────────────
# 武器印
const WEAPON_SEAL_EFFECTS := {
	"burn":    {"atk_bonus": 0, "on_hit": "fire_damage"},     # 炎: 追加炎ダメージ
	"silver":  {"atk_bonus": 3, "on_hit": ""},                # 銀: ATK+3
	"ancient": {"atk_bonus": 5, "on_hit": ""},                # 古: ATK+5
	"curse":   {"atk_bonus": 0, "on_hit": "paralyze_chance"}, # 呪: 5%金縛り
}
# 盾印
const SHIELD_SEAL_EFFECTS := {
	"silver_def":  {"def_bonus": 3, "on_defend": ""},
	"ancient_def": {"def_bonus": 5, "on_defend": ""},
	"curse_def":   {"def_bonus": 0, "on_defend": "paralyze_chance"},
}

# ─── アイテム表示名 ────────────────────────────────────────
## 「呪 木の剣+3[炎銀]」のように、呪い/祝福＋修正値＋印を含む表示名を返す
static func display_name(item: Dictionary) -> String:
	var base_name: String = item.get("name", "?")
	# 呪い/祝福プレフィックス（全アイテム共通）
	var prefix := ""
	if item.get("cursed", false):
		prefix = "呪 "
	elif item.get("blessed", false):
		prefix = "祝 "
	var t: int = item.get("type", -1)
	if t != ItemData.TYPE_WEAPON and t != ItemData.TYPE_SHIELD:
		return "%s%s" % [prefix, base_name]
	var plus: int = int(item.get("plus", 0))
	var suffix := ""
	if plus > 0:
		suffix = "+%d" % plus
	elif plus < 0:
		suffix = "%d" % plus
	var seals: Array = item.get("seals", [])
	var seal_str := ""
	if not seals.is_empty():
		for s in seals:
			seal_str += s.get("name", "?")
		seal_str = "[%s]" % seal_str
	return "%s%s%s%s" % [prefix, base_name, suffix, seal_str]

## 印スロットの空き数（technique_3 のボーナスは game が必要なため別途）
static func free_slots(item: Dictionary, bonus: int = 0) -> int:
	var max_slots: int = int(item.get("seal_slots", 0)) + bonus
	var used: int = (item.get("seals", []) as Array).size()
	return max(0, max_slots - used)

# ─── 合成 ──────────────────────────────────────────────────
## base に material を合成する。同タイプ（武器同士／盾同士）のみ。
## 戻り値: 合成結果メッセージの Array[String]。空なら合成不可。
## base は直接書き換わる。material は呼び出し元で消費する。
## extra_slots: スキル等による追加印スロット数
static func synthesize(base: Dictionary, material: Dictionary, extra_slots: int = 0) -> Array:
	var bt: int = base.get("type", -1)
	var mt: int = material.get("type", -1)
	if bt != mt:
		return []
	if bt != ItemData.TYPE_WEAPON and bt != ItemData.TYPE_SHIELD:
		return []
	var msgs: Array = []
	# 1. 修正値の加算
	var m_plus: int = int(material.get("plus", 0))
	if m_plus != 0:
		base["plus"] = int(base.get("plus", 0)) + m_plus
		msgs.append("修正値 +%d → +%d" % [m_plus, int(base["plus"])])
	# 2. 印の転写
	var seal_id: String = material.get("seal_id", "")
	if not seal_id.is_empty():
		if free_slots(base, extra_slots) > 0:
			if not _has_seal(base, seal_id):
				var seal := {
					"id":   seal_id,
					"name": material.get("seal_name", "?"),
					"desc": material.get("seal_desc", ""),
				}
				if not base.has("seals"):
					base["seals"] = []
				(base["seals"] as Array).append(seal)
				msgs.append("印「%s」を合成！" % seal["name"])
			else:
				msgs.append("印「%s」は既にある。" % material.get("seal_name", "?"))
		else:
			msgs.append("空き印がない。印「%s」は合成できなかった。" % material.get("seal_name", "?"))
	# 素材の ATK/DEF 基礎値は加算しない（印と+値のみ移る）
	if msgs.is_empty():
		msgs.append("合成したが、変化はなかった。")
	return msgs

## base に seal_id の印が既にあるか
static func _has_seal(item: Dictionary, seal_id: String) -> bool:
	for s in item.get("seals", []):
		if s.get("id", "") == seal_id:
			return true
	return false

# ─── 合成の箱：contents 内での自動合成 ─────────────────────
## 合成の箱に target_item を追加するとき、contents 内に同タイプの武器/盾があれば合成。
## 戻り値: {"merged": bool, "messages": Array}
static func try_merge_in_pot(contents: Array, target_item: Dictionary) -> Dictionary:
	var t: int = target_item.get("type", -1)
	if t != ItemData.TYPE_WEAPON and t != ItemData.TYPE_SHIELD:
		return {"merged": false, "messages": []}
	# contents 内から同タイプの最初のアイテムを探す
	for i in contents.size():
		var existing: Dictionary = contents[i]
		if int(existing.get("type", -1)) == t:
			# existing をベースとして target_item を合成
			var msgs: Array = synthesize(existing, target_item)
			return {"merged": true, "messages": msgs}
	return {"merged": false, "messages": []}

# ─── 印のATK/DEFボーナス合計 ──────────────────────────────
## 武器の印による追加ATK
static func seal_atk_bonus(item: Dictionary) -> int:
	var bonus: int = 0
	for s in item.get("seals", []):
		var sid: String = s.get("id", "")
		if WEAPON_SEAL_EFFECTS.has(sid):
			bonus += int(WEAPON_SEAL_EFFECTS[sid].get("atk_bonus", 0))
	return bonus

## 盾の印による追加DEF
static func seal_def_bonus(item: Dictionary) -> int:
	var bonus: int = 0
	for s in item.get("seals", []):
		var sid: String = s.get("id", "")
		if SHIELD_SEAL_EFFECTS.has(sid):
			bonus += int(SHIELD_SEAL_EFFECTS[sid].get("def_bonus", 0))
	return bonus

## 武器に「炎」印があるか
static func has_burn_seal(item: Dictionary) -> bool:
	return _has_seal(item, "burn")

## 武器に「呪」印があるか（攻撃時金縛りチャンス）
static func has_curse_seal(item: Dictionary) -> bool:
	return _has_seal(item, "curse")

## 盾に「呪」印があるか（被弾時金縛りチャンス）
static func has_curse_def_seal(item: Dictionary) -> bool:
	return _has_seal(item, "curse_def")
