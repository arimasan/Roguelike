# Claude Code プロジェクト設定

## GDScript パースチェック（必須）

`.gd` ファイルを編集したら、**完了報告の前に必ず** Godot の `--check-only` でパースエラーを検出すること。

### 手順

1. **Godot 実行パスを探す**（環境依存。`which godot` や `find` で探す）:
   ```bash
   # 例: Windows
   GODOT=$(find /c/Users/*/Downloads -name "Godot_*_console.exe" 2>/dev/null | head -1)
   # 例: Linux/Mac（PATH に入っている場合）
   GODOT=$(which godot 2>/dev/null)
   ```

2. **パースチェックを実行**:
   ```bash
   "$GODOT" --headless --check-only --path . 2>&1 | head -60
   ```

3. **結果判定**:
   - `ERROR` / `SCRIPT ERROR` / `Parse Error` を含む行があれば **修正してから再実行**
   - 以下の WARNING のみなら OK（既知の無害な警告）:
     ```
     WARNING: res://scenes/game.tscn:3 - ext_resource, invalid UID: uid://gamescript01
     ```

4. **新しい `class_name` を追加した場合**:
   `--check-only` は `.godot/global_script_class_cache.cfg` を更新しないため、
   `Identifier "Foo" not declared` エラーが出る。一度だけ以下を実行してキャッシュ更新:
   ```bash
   "$GODOT" --headless --editor --quit --path .
   ```
   `update_scripts_classes | Foo` が出れば登録完了。以降は `--check-only` だけで OK。

### 注意事項

- **ユーザがテスト中の Godot ゲームクライアントを絶対に kill しないこと**。
  `taskkill` や `pkill` で Godot プロセスを落としてはいけない。
  `--check-only` は独立プロセスとして起動するので、既存プロセスとは干渉しない。
- タイムアウト 30秒で実行し、応答がなければ結果を報告して先に進む。
- 実行時間は通常 5〜15秒。

## アーキテクチャ

Godot 4.6 の GDScript プロジェクト。`game.gd` がオーケストレーター（状態所有＋入力ディスパッチ）で、ロジックは責務別の静的ヘルパクラスに分離している。

### ファイル構成（scripts/）

各ヘルパは `class_name Foo extends RefCounted` の静的メソッド集。第1引数に `game: Node` を受け取る。

| ファイル | 責務 |
|---|---|
| `scenes/game.gd` | 状態変数所有、ライフサイクル、入力ディスパッチ、移動、ターン管理 |
| `scripts/item_effects.gd` | アイテム使用効果、状態異常付与 |
| `scripts/throw_system.gd` | 投擲の照準・軌道・命中・落下 |
| `scripts/inventory_ui.gd` | インベントリ/アクションメニュー/保存の箱UI |
| `scripts/shop_logic.gd` | 店の売買・カーペット管理 |
| `scripts/save_load.gd` | セーブ/ロード（JSON） |
| `scripts/enemy_ai.gd` | 敵AI・スポーン・モンスターハウス |
| `scripts/combat.gd` | 攻防計算・レベルアップ・被弾 |
| `scripts/fov.gd` | 視野計算・エンティティ可視性 |
| `scripts/options_ui.gd` | オプション画面・キーリバインド |
| `scripts/companion_ai.gd` | 仲間AI |
| `scripts/enemy_skills.gd` | 敵スキルシステム |
| `scripts/dialog_ui.gd` | 会話ダイアログUI |
| `scripts/bestiary_ui.gd` | 図鑑UI |
| `scripts/hud.gd` | HUD描画全般 |
| `data/item_data.gd` | アイテム定義・価格計算 |
| `data/enemy_data.gd` | 敵定義 |
| `data/trap_data.gd` | ワナ定義 |
| `data/bestiary.gd` | 図鑑データ管理 |

### 設計原則

- **状態は game.gd に集約**。サブシステムは状態を持たず `game` 経由で読み書きする。
- 各ファイル冒頭に「ここに書く/書かないべきもの」のガイドコメントがある。
- **ファイル肥大化チェック**: 大きな機能追加後は `wc -l` でサイズを確認。800行超で分割を検討、1200行超で積極提案。ただし自然な境界がない場合は無理に割らない。
