---
description: TDD対応の次タスク実装。TODO.mdから選定し、適切なパイプラインで実装。
---

# TDD対応の次タスク実装

TODO.mdから次のタスクを選定し、テストパターン判定に基づいて適切なTDDパイプラインで実装します。

## CI チェックに関する重要な区別

このパイプラインでは **local-ci コマンド**を使用します。以下の違いを理解しておいてください：

| コマンド | 実行場所 | 目的 | 使用場面 |
|---------|---------|------|----------|
| **local-ci** (このパイプラインで使用) | **local** | local CI チェック（remote CI 相当）をローカル実行 | TDD完了後、PR作成前の検証 |
| **check-remote-ci** | **remote** (GitHub Actions) | remote CI の実行状態確認 | PR作成後、remote CI が失敗した際の調査 |

- **local-ci**: ローカルマシン上で Biome check、Test、Build を並列実行（3つの sub agent を使用）
- **check-remote-ci**: remote CI (GitHub Actions) の実行結果を確認し、失敗時の修正方針を提案

## 実行フロー

### 1. TODO.mdから次タスクを選定

Read ツールで TODO.md を読み込み、最初の `- [ ]` (pending) タスクを特定します。

### 2. ブランチ作成

タスク内容に基づいて適切な名前でGitブランチを作成します。

**ブランチ命名規則**:
- **機能追加**: `feature/{機能名}`
- **バグ修正**: `fix/{修正内容}`
- **リファクタリング**: `refactor/{対象}`
- **テスト追加**: `test/{対象}`

**手順**:
1. 現在のブランチを確認: `git branch --show-current`
2. mainブランチから新しいブランチを作成:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b {ブランチ名}
   ```

**例**:
- タスク「入力バリデーション機能の追加」 → `feature/validation-input`
- タスク「データ変換のバグ修正」 → `fix/data-transform`
- タスク「ストアのリファクタリング」 → `refactor/store`

### 3. classify-files でテストパターン判定

Task ツールで classify-files エージェントを起動し、実装対象ファイルのテストパターンを判定します。

**プロンプト例**:
```
TODO.mdの次タスク「{タスク名}」について、実装対象ファイルのテストパターンを判定してください。

対象ファイル: {ファイルパス}

以下を出力してください:
1. tddMode (test-first / test-later)
2. testPattern (unit / store / hook / component / integration)
3. placement (colocated / separated)
4. rationale (判定理由)
5. testFilePath (テストファイルの配置パス)
```

### 3.5. テストパターン別の方針

classify-files の判定結果に基づき、test-writer エージェントが適切なテストパターンを適用します。

各テストパターンの詳細な方針は **`.claude/agents/test-writer.md`** に記載されています。

#### component パターン（コンポーネントテスト）の概要

Reactコンポーネントのテストは、**セマンティックテスト**と**スナップショットテスト**を組み合わせます：

**セマンティックテスト**（優先）: ユーザー視点の振る舞い・状態変化を検証
- ステート分岐、条件付きレンダリング
- ユーザーインタラクション（クリック、入力など）
- propsによる動作の変化

**スナップショットテスト**: 構造・見た目の意図しない変更を検知
- コンポーネントの基本的なレンダリング結果
- 主要なpropsによる見た目のバリエーション

詳細は `test-writer.md` のセクション4を参照してください。

#### test-writer エージェント起動時のプロンプト例

```
{testPattern} パターンで {testFilePath} にテストを作成してください。

実装ファイル: {implFilePath}

test-writer.md に記載された {testPattern} パターンの方針に従ってテストを作成してください。

テストは失敗する状態 (Red) で作成してください。
```

**component パターンの場合の補足**:
```
component パターンで {testFilePath} にテストを作成してください。

実装ファイル: {implFilePath}

test-writer.md セクション4に記載された方針に従い、以下の順序でテストを作成してください:
1. セマンティックテスト（ユーザー視点の振る舞い検証）
2. スナップショットテスト（構造・見た目の検証）

テストは失敗する状態 (Red) で作成してください。
```

### 4. パイプライン選択と実行

classify-files の判定結果に基づき、適切なパイプラインを**順次実行**します。

**重要**: エージェント間に依存関係があるため、**必ず順次実行**してください。並列実行は不可です。

#### 4-1. テストファーストパイプライン (tddMode: test-first)

```
1. test-writer エージェント起動 【Red: テスト作成】
   目的: 失敗するテストを作成（TDD Red フェーズ）
   - テストパターンに応じた失敗するテストを作成
   - classify-files が判定した testPattern と testFilePath を渡す

2. test-runner エージェント起動 【Red確認】
   目的: テストが正しく失敗することを確認（TDDサイクル検証）
   - 期待する状態: RED_EXPECTED
   - 判定: 全テスト失敗 → SUCCESS
   - test-writer が作成したテストファイルパスを渡す

3. implement エージェント起動 【Green: 実装】
   目的: テストを通す最小限の実装（TDD Green フェーズ）
   - テストを通す最小限の実装
   - テストファイルパスと実装ファイルパスを渡す

4. test-runner エージェント起動 【Green確認（局所的）】
   目的: 実装したコードが新規テストを通すことを確認
   - 期待する状態: GREEN_EXPECTED
   - 実装したファイルに関連するテストのみ実行（局所的影響を検出）
   - 判定: 全テスト成功 → 次へ
   - 判定: 失敗 → plan-fixへ

5. local-ci コマンド実行 【local CI 全体チェック（全体的）】
   目的: 既存コード全体への影響がないことを確認
   - Skill("local-ci") を呼び出し
   - **ローカルマシン上**で Biome check、Test（全テスト）、Build を並列実行（全体的影響を検出）
   - 判定: 全て成功 → 次へ
   - 判定: 失敗 → plan-fixへ

6. (local-ci が成功した場合) review-file エージェント起動 【Refactor判断】
   目的: コード品質を確認（TDD Refactor フェーズ）
   - review-perspective-selector skill で観点を自動選択
   - 実装ファイルとテストファイルの両方をレビュー
   - 判定: PASS → 完了
   - 判定: WARN → ユーザーに確認「修正しますか？(y/n)」
   - 判定: FAIL → 必須修正（次へ進む）

7. (test-runner/local-ci が失敗 or WARN時にユーザー承認 or FAIL の場合) plan-fix エージェント起動 【修正計画】
   目的: 問題を分析し、具体的な修正計画を立案
   - test-runner/local-ci の失敗内容 または review-file の指摘事項に基づき修正計画を作成
   - 修正内容をユーザーに提示

8. (ユーザーが承認した場合) implement エージェント起動 【修正実行】
   目的: plan-fix の計画に基づいて問題を修正
   - plan-fixの計画に基づいて修正実行
   - テストファイルと実装ファイルの両方を修正可能

9. local-ci コマンド実行 【修正確認（全体的）】
   目的: 修正後のコードが全てのチェックを通過することを確認
   - Skill("local-ci") を呼び出し
   - **ローカルマシン上**で Biome check、Test、Build を並列実行
   - 判定: 全て成功 → 次へ
   - 判定: 失敗 → 7に戻る（最大3回まで）

10. review-file エージェント起動 【再レビュー】
   目的: 修正後のコード品質を再確認
   - 修正後のコードを再度レビュー
   - 判定: PASS → 完了
   - 判定: WARN/FAIL → 7に戻る（最大3回まで）
```

#### 4-2. テストレイターパイプライン (tddMode: test-later)

```
1. implement エージェント起動 【実装】
   目的: 仕様に基づいてコードを実装（テストは後から）
   - 実装優先

2. test-writer エージェント起動 【テスト作成】
   目的: 実装済みのコードに対するテストを作成
   - 実装に基づくテスト作成（Green状態で作成）

3. test-runner エージェント起動 【Green確認（局所的）】
   目的: 作成したテストが実装を正しく検証することを確認
   - 期待する状態: GREEN_EXPECTED
   - 実装したファイルに関連するテストのみ実行（局所的影響を検出）
   - 判定: 全テスト成功 → 次へ
   - 判定: 失敗 → plan-fixへ

4. local-ci コマンド実行 【local CI 全体チェック（全体的）】
   目的: 既存コード全体への影響がないことを確認
   - Skill("local-ci") を呼び出し
   - **ローカルマシン上**で Biome check、Test（全テスト）、Build を並列実行（全体的影響を検出）
   - 判定: 全て成功 → 次へ
   - 判定: 失敗 → plan-fixへ

5. (local-ci が成功した場合) review-file エージェント起動 【品質確認】
   目的: コード品質とテストの妥当性を確認
   - review-perspective-selector skill で観点を自動選択
   - 実装ファイルとテストファイルの両方をレビュー
   - 判定: PASS → 完了
   - 判定: WARN → ユーザーに確認「修正しますか？(y/n)」
   - 判定: FAIL → 必須修正（次へ進む）

6. (test-runner/local-ci が失敗 or WARN時にユーザー承認 or FAIL の場合) plan-fix エージェント起動 【修正計画】
   目的: 問題を分析し、具体的な修正計画を立案
   - test-runner/local-ci の失敗内容 または review-file の指摘事項に基づき修正計画を作成

7. (ユーザーが承認した場合) implement エージェント起動 【修正実行】
   目的: plan-fix の計画に基づいて問題を修正
   - plan-fixの計画に基づいて修正実行

8. local-ci コマンド実行 【修正確認（全体的）】
   目的: 修正後のコードが全てのチェックを通過することを確認
   - Skill("local-ci") を呼び出し
   - **ローカルマシン上**で Biome check、Test、Build を並列実行
   - 判定: 全て成功 → 次へ
   - 判定: 失敗 → 6に戻る（最大3回まで）

9. review-file エージェント起動 【再レビュー】
   目的: 修正後のコード品質を再確認
   - 修正後のコードを再度レビュー
   - 判定: PASS → 完了
   - 判定: WARN/FAIL → 6に戻る（最大3回まで）
```

### 5. TODO.md更新

タスク完了後、TODO.mdを更新します:
- 完了したタスクを `- [x]` に変更
- 実装したファイルパスを記録 (必要に応じて)

### 6. レポート生成

実行結果をレポートとして出力します:

```markdown
## タスク完了レポート

**タスク**: {タスク名}
**TDDモード**: {test-first / test-later}
**テストパターン**: {unit / store / hook / component / integration}

### 作成ファイル
- {実装ファイルパス}
- {テストファイルパス}

### テスト結果
- 実行: {total} tests
- 成功: {passed} passed
- 失敗: {failed} failed
- カバレッジ: {coverage}%

### CI チェック結果
- Biome check: ✓
- Tests: ✓ ({total} tests passed)
- Build: ✓

### フィードバックループ
- test-writer: {レポートパス}
- implement: {レポートパス}
- test-runner: {レポートパス}
- local-ci-checker: {結果サマリー}

### 次回の改善点
{エージェント定義ファイルへの改善内容}
```

## エージェント起動の注意点

### 並列 vs 順次実行

**重要**: エージェント間に依存関係があるため、**必ず順次実行**してください。

```javascript
// ❌ 並列実行 (依存関係があるため不可)
[
  Task(test-writer),
  Task(implement)  // test-writerの結果に依存
]

// ✅ 順次実行
Task(test-writer)
→ 完了待ち
→ Task(test-runner, RED_EXPECTED)
→ 完了待ち
→ Task(implement)
→ 完了待ち
→ Task(test-runner, GREEN_EXPECTED)
```

### 状態の受け渡し

各エージェントの出力結果を次のエージェントに渡します:

```
test-writer の出力:
  - testFilePath: "src/utils/helpers.test.ts"

→ test-runner に渡す:
  - targetFile: "src/utils/helpers.test.ts"
  - expectation: "RED_EXPECTED"

→ implement に渡す:
  - testFilePath: "src/utils/helpers.test.ts"
  - implFilePath: "src/utils/helpers.ts"
```

### エージェント起動例

**classify-files エージェント**:
```javascript
{
  "subagent_type": "classify-files",
  "model": "haiku",
  "prompt": "TODO.mdの次タスク「{タスク名}」について、実装対象ファイルのテストパターンを判定してください。\n\n対象ファイル: {ファイルパス}\n\n以下を出力してください:\n1. tddMode (test-first / test-later)\n2. testPattern (unit / store / hook / component / integration)\n3. placement (colocated / separated)\n4. rationale (判定理由)\n5. testFilePath (テストファイルの配置パス)"
}
```

**test-writer エージェント**:
```javascript
{
  "subagent_type": "test-writer",
  "model": "sonnet",
  "prompt": "{testPattern} パターンで {testFilePath} にテストを作成してください。\n\n実装ファイル: {implFilePath}\n\nテストは失敗する状態 (Red) で作成してください。"
}
```

**test-runner エージェント**:
```javascript
{
  "subagent_type": "test-runner",
  "model": "haiku",
  "prompt": "{testFilePath} のテストを実行し、{expectation} であることを確認してください。"
}
```

**implement エージェント**:
```javascript
{
  "subagent_type": "implement",
  "model": "sonnet",
  "prompt": "{implFilePath} を実装してください。\n\nテストファイル: {testFilePath}\n\nテストを通す最小限の実装をしてください。"
}
```

**review-file エージェント**:
```javascript
{
  "subagent_type": "review-file",
  "model": "haiku",
  "prompt": "まず、review-perspective-selector skill を使用して {implFilePath} に適切なレビュー観点を選択してください。\n\n選択された観点ファイル（.claude/review-points/*.md）を使用してレビューを実施してください。\n\n対象ファイル:\n- 実装: {implFilePath}\n- テスト: {testFilePath}\n\nPASS/WARN/FAILで判定してください。"
}
```

**plan-fix エージェント**:
```javascript
{
  "subagent_type": "plan-fix",
  "model": "haiku",
  "prompt": "review-file の指摘事項に基づき、{implFilePath} の修正計画を作成してください。"
}
```

**local-ci コマンド（Skill 呼び出し）**:
```javascript
Skill({
  "skill": "local-ci"
})
```

## エラーハンドリング

### テストが Red にならない場合 (test-writer 直後)

```
→ 警告を出力
→ test-writer.md に改善提案を追加 (フィードバックフック経由)
→ 続行するかユーザーに確認
```

### local-ci が失敗する場合 (implement 直後)

```
→ 失敗したチェックを全て確認（Biome/Test/Build）
→ 全てのエラー内容をまとめて表示
→ plan-fix エージェント起動
→ local-ci の失敗内容に基づき総合的な修正計画を作成
→ implement エージェント再起動
→ 最大3回までリトライ
→ それでも失敗 → ユーザーに報告
```

### classify-files の判定が不明確な場合

```
→ ユーザーに確認
→ 手動で tddMode と testPattern を選択
→ パイプライン続行
```

## 重要な注意事項

### 1. エージェント定義ファイルを直接編集しない

フィードバックフック (SubagentStop) が自動で改善します。手動編集は構造的な問題のみに限定してください。

### 2. テストファイルパスの一貫性

classify-files が提案したパスを厳守してください:
- **colocated**: 同階層 (例: `src/utils/helpers.test.ts`)
- **separated**: `src/__tests__/integration/` (例: `src/__tests__/integration/dataFlow.test.ts`)

### 3. SubagentStop フックの自動実行

各エージェント完了時に自動評価が実行されます:
- レポートは `.claude/reports/{agent-type}/` に保存
- エージェント定義ファイルに改善が追記される (必要に応じて)

### 4. TODO.md の更新タイミング

- **全パイプライン完了後（local-ci が成功し、review-file が PASS した後）**に更新してください
- 途中でエラーが起きた場合は更新しないでください
- local-ci が失敗した場合も更新しないでください

## 検証方法

1. 手動で `/tdd-next` を実行
2. TODO.md の次タスクが選択される
3. classify-files が判定を行う
4. 適切なパイプラインが実行される
5. ファイルが作成される
6. local-ci コマンドが実行される（Biome check、Test、Build を並列実行）
7. 全てのCIチェックが成功する（または失敗した全ての問題が報告される）
8. review-file がコードをレビューする
9. TODO.md が更新される
10. フィードバックレポートが生成される（test-writer、implement、local-ci、review-file）

---

**Note**: このコマンドは複雑なパイプラインを実行します。各エージェントの完了を待ち、順次実行することを忘れないでください。
