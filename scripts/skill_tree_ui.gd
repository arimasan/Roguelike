class_name SkillTreeUI
extends RefCounted

## スキルツリー画面の描画と入力処理。
## game.gd の state "skill_tree" で動作する。
## カーソル: game._st_branch_idx (列) / game._st_tier_idx (行)

static func open(game: Node) -> void:
	game._st_branch_idx = 0
	game._st_tier_idx   = 0
	game.game_state = "skill_tree"
	game._refresh_hud()

static func handle_input(game: Node, kc: int) -> void:
	match kc:
		KEY_ESCAPE, KEY_I:
			game.game_state = "playing"
			game._refresh_hud()
		KEY_LEFT, KEY_H:
			game._st_branch_idx = max(0, int(game._st_branch_idx) - 1)
			game._refresh_hud()
		KEY_RIGHT, KEY_L:
			game._st_branch_idx = min(3, int(game._st_branch_idx) + 1)
			game._refresh_hud()
		KEY_UP, KEY_K:
			game._st_tier_idx = max(0, int(game._st_tier_idx) - 1)
			game._refresh_hud()
		KEY_DOWN, KEY_J:
			game._st_tier_idx = min(3, int(game._st_tier_idx) + 1)
			game._refresh_hud()
		KEY_ENTER, KEY_Z, KEY_KP_ENTER:
			var skill_id: String = _selected_id(game)
			if not skill_id.is_empty():
				if SkillTree.unlock(game, skill_id):
					game._play_se("general_item")
				else:
					game.add_message("習得できない。")
				game._refresh_hud()

static func _selected_id(game: Node) -> String:
	var branch: String = SkillTree.BRANCHES[int(game._st_branch_idx)]
	var skills: Array = SkillTree.branch_skills(branch)
	var idx: int = int(game._st_tier_idx)
	if idx >= 0 and idx < skills.size():
		return skills[idx]
	return ""

## HUD 描画用（hud.gd から呼ばれる）
static func draw(hud: Control, vp: Vector2, game: Node) -> void:
	var font := ThemeDB.fallback_font
	var BAR_H: int = 100
	# 背景
	hud.draw_rect(Rect2(0, 0, vp.x, vp.y - BAR_H), Color(0, 0, 0, 0.85))

	# タイトル
	var sp: int = int(game.skill_points)
	var title: String = "─── スキルツリー ───  SP: %d" % sp
	hud.draw_string(font, Vector2(vp.x / 2.0 - 160, 32), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.95, 0.85, 0.25))

	var col_w: float = (vp.x - 40.0) / 4.0
	var start_y: float = 60.0
	var row_h: float = 80.0
	var sel_branch: int = int(game._st_branch_idx)
	var sel_tier: int   = int(game._st_tier_idx)

	for bi in SkillTree.BRANCHES.size():
		var branch: String = SkillTree.BRANCHES[bi]
		var bx: float = 20.0 + bi * col_w
		var skills: Array = SkillTree.branch_skills(branch)

		# ブランチ名
		var branch_col: Color = Color(0.70, 0.85, 1.00) if bi == sel_branch else Color(0.55, 0.55, 0.60)
		hud.draw_string(font, Vector2(bx + 10, start_y),
			"【%s】" % SkillTree.BRANCH_NAMES[branch],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, branch_col)

		for ti in skills.size():
			var sid: String = skills[ti]
			var skill: Dictionary = SkillTree.SKILLS[sid]
			var sy: float = start_y + 28 + ti * row_h
			var is_sel: bool = (bi == sel_branch and ti == sel_tier)
			var unlocked: bool = SkillTree.has(game, sid)
			var can_get: bool = SkillTree.can_unlock(game, sid)

			# 背景ハイライト
			if is_sel:
				hud.draw_rect(Rect2(bx + 2, sy - 14, col_w - 8, row_h - 8),
					Color(0.25, 0.35, 0.50, 0.70))

			# 状態マーク
			var mark: String
			var mark_col: Color
			if unlocked:
				mark = "✓"
				mark_col = Color(0.3, 1.0, 0.3)
			elif can_get:
				mark = "○"
				mark_col = Color(1.0, 0.95, 0.4)
			else:
				mark = "✗"
				mark_col = Color(0.45, 0.45, 0.45)

			hud.draw_string(font, Vector2(bx + 8, sy + 2), mark,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, mark_col)

			# スキル名
			var name_col: Color
			if unlocked:
				name_col = Color(0.85, 1.0, 0.85)
			elif can_get:
				name_col = Color.WHITE
			else:
				name_col = Color(0.50, 0.50, 0.50)
			hud.draw_string(font, Vector2(bx + 26, sy + 2),
				"%s (%dpt)" % [skill["name"], int(skill["cost"])],
				HORIZONTAL_ALIGNMENT_LEFT, int(col_w - 40), 14, name_col)

			# 説明文
			hud.draw_string(font, Vector2(bx + 26, sy + 20),
				skill["desc"],
				HORIZONTAL_ALIGNMENT_LEFT, int(col_w - 40), 11,
				Color(0.65, 0.65, 0.70))

			# Tier 間の接続線
			if ti < skills.size() - 1:
				var line_x: float = bx + 14
				var line_y1: float = sy + 28
				var line_y2: float = sy + row_h - 16
				var line_col: Color = Color(0.3, 0.5, 0.3) if unlocked else Color(0.3, 0.3, 0.3)
				hud.draw_line(Vector2(line_x, line_y1), Vector2(line_x, line_y2), line_col, 1.0)

	# 操作ガイド
	var gy: float = vp.y - BAR_H - 30.0
	hud.draw_rect(Rect2(0, gy - 4, vp.x, 30), Color(0, 0, 0, 0.6))
	hud.draw_string(font, Vector2(8, gy + 16),
		"[←→] ブランチ  [↑↓] スキル  [Enter/Z] 習得  [Esc] 閉じる",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.70, 0.70, 0.70))
