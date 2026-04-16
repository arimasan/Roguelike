class_name Bestiary
extends RefCounted

## 図鑑（発見済みエンティティ）のメタ進行を管理する。
## ゲームオーバー・リスタートを跨いで永続化する（user://bestiary.json）。
##
## - discovered_enemies: Dictionary<enemy_id, true>   撃破したことのある敵
## - discovered_items:   Dictionary<item_id, true>    使用/装備/投擲/識別した事のあるアイテム
## - discovered_traps:   Dictionary<trap_id, true>    発動したことのあるワナ

const META_PATH := "user://bestiary.json"

static var enemies:  Dictionary = {}
static var items:    Dictionary = {}
static var traps:    Dictionary = {}
static var recruited: Dictionary = {}   # 仲間化したことのある敵 ID

static var _loaded: bool = false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(META_PATH):
		return
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	for k in d.get("enemies", {}):
		enemies[str(k)] = true
	for k in d.get("items", {}):
		items[str(k)] = true
	for k in d.get("traps", {}):
		traps[str(k)] = true
	for k in d.get("recruited", {}):
		recruited[str(k)] = true

static func save() -> void:
	var d: Dictionary = {
		"enemies":  enemies,
		"items":    items,
		"traps":    traps,
		"recruited":recruited,
	}
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()

static func discover_enemy(enemy_id: String) -> bool:
	ensure_loaded()
	if enemy_id == "" or enemies.has(enemy_id):
		return false
	enemies[enemy_id] = true
	save()
	return true

static func discover_item(item_id: String) -> bool:
	ensure_loaded()
	if item_id == "" or items.has(item_id):
		return false
	items[item_id] = true
	save()
	return true

static func discover_trap(trap_id: String) -> bool:
	ensure_loaded()
	if trap_id == "" or traps.has(trap_id):
		return false
	traps[trap_id] = true
	save()
	return true

static func knows_enemy(enemy_id: String) -> bool:
	ensure_loaded()
	return enemies.has(enemy_id)

static func knows_item(item_id: String) -> bool:
	ensure_loaded()
	return items.has(item_id)

static func knows_trap(trap_id: String) -> bool:
	ensure_loaded()
	return traps.has(trap_id)

## 仲間化したことのある敵を記録（初回のみ true 返却）
static func recruit_enemy(enemy_id: String) -> bool:
	ensure_loaded()
	if enemy_id == "" or recruited.has(enemy_id):
		return false
	recruited[enemy_id] = true
	enemies[enemy_id] = true   # 仲間化＝撃破済み扱いにもしておく
	save()
	return true

static func has_recruited(enemy_id: String) -> bool:
	ensure_loaded()
	return recruited.has(enemy_id)
