# TDD運用ガイド

このドキュメントでは、Claude Code を使用した TDD（Test-Driven Development）の運用方法を説明します。

## 目次

1. [概要](#概要)
2. [TDDサイクル](#tddサイクル)
3. [コマンド使用方法](#コマンド使用方法)
4. [パイプライン](#パイプライン)
5. [エージェントの役割](#エージェントの役割)
6. [ベストプラクティス](#ベストプラクティス)

---

## 概要

このプロジェクトでは、TDD を自動化するための専用コマンドとエージェントパイプラインを構築しています。

### 主要コマンド

- `/tdd-next` - TODO.md から次タスクを選定して TDD 実装
- `/tdd-implement <filepath>` - 特定のファイルを指定して TDD 実装

### エージェント構成

```
classify-files → test-writer → test-runner(RED) → implement → test-runner(GREEN) → review-file
```

---

## TDDサイクル

### Red-Green-Refactor サイクル

```
1. Red: 失敗するテストを書く
   └─ test-writer エージェントがテストを作成
   └─ test-runner が Red 状態を確認

2. Green: テストを通す最小限の実装
   └─ implement エージェントが実装
   └─ test-runner が Green 状態を確認

3. Refactor: コードを改善（必要に応じて）
   └─ review-file エージェントがレビュー
   └─ plan-fix エージェントが修正計画作成
   └─ implement エージェントがリファクタリング
   └─ test-runner が Green 状態を維持確認
```

### テストパターン

classify-files エージェントが以下のパターンを判定します：

| パターン | 対象 | 配置 | TDDモード |
|---------|------|------|----------|
| **unit** | 純粋関数、ユーティリティ | colocated | test-first |
| **store** | Zustand ストア | colocated | test-first |
| **hook** | React カスタムフック | colocated | test-later |
| **component** | React コンポーネント | colocated | test-later |
| **integration** | 複数モジュール統合 | separated | test-later |

---

## コマンド使用方法

### /tdd-next - 次タスクの自動実装

TODO.md から次の `- [ ]` タスクを自動選定し、TDD パイプラインで実装します。

```bash
/tdd-next
```

#### 実行フロー

1. **TODO.md から次タスクを選定**
   - 最初の `- [ ]` (pending) タスクを特定

2. **classify-files でテストパターン判定**
   - tddMode, testPattern, placement を判定

3. **パイプライン実行**
   - テストファーストまたはテストレイターパイプラインを順次実行

4. **TODO.md 更新**
   - 完了したタスクを `- [x]` に変更

#### 使用例

```bash
# TODO.md の次タスク「1.2 フォーマッター関数」を実装
/tdd-next

# 結果:
# - formatters.ts が作成される
# - formatters.test.ts が作成される
# - 全テストが Green になる
# - TODO.md が更新される
```

### /tdd-implement - 特定ファイルの実装

ファイルパスを指定して TDD 実装を行います。

```bash
/tdd-implement <filepath>
```

#### 使用例

```bash
# 新規ファイルの実装
/tdd-implement src/utils/formatters.ts

# 既存ファイルへのテスト追加
/tdd-implement src/utils/validators.ts
# → テストレイターモードを推奨（確認あり）
```

#### /tdd-next との違い

| 項目 | /tdd-next | /tdd-implement |
|------|-----------|----------------|
| タスク選定 | TODO.md から自動 | ユーザー指定 |
| TODO.md 更新 | ✓ | ✗ |
| 使用場面 | 計画的な実装 | 個別の修正・追加 |

---

## パイプライン

### テストファーストパイプライン

純粋関数、ストアなど、仕様が明確なモジュールで使用します。

```
classify-files
  ↓
test-writer (Red)
  ↓
test-runner (RED確認)
  ↓
implement
  ↓
test-runner (GREEN確認)
  ↓
review-file
  ↓ (必要に応じて)
plan-fix
  ↓
implement (Refactor)
  ↓
test-runner (GREEN維持確認)
```

#### 特徴

- **仕様先行**: テストが仕様書の役割を果たす
- **最小限の実装**: テストを通す最小限のコードのみ
- **リグレッション防止**: Red → Green の状態遷移を確認

### テストレイターパイプライン

コンポーネント、フックなど、実装を見ながらテストを書く方が効率的なモジュールで使用します。

```
classify-files
  ↓
implement
  ↓
test-writer
  ↓
test-runner (GREEN確認)
  ↓
review-file
  ↓ (必要に応じて)
plan-fix → implement → test-runner
```

#### 特徴

- **実装先行**: 実装を見ながらテストを書く
- **カバレッジ重視**: 実装されたコードを網羅的にテスト
- **リファクタリング支援**: テストが後からリファクタリングを支援

---

## エージェントの役割

### classify-files

**役割**: テストパターン判定

**入力**:
- ファイルパス
- 実装内容（仕様）

**出力**:
- tddMode (test-first / test-later)
- testPattern (unit / store / hook / component / integration)
- placement (colocated / separated)
- testFilePath

**判定基準**:
- ファイルの場所（src/utils, src/components など）
- 実装内容（純粋関数、React コンポーネント など）
- 外部依存の有無

### test-writer

**役割**: テストケース作成

**TDD Red フェーズ**:
- 実装を見ずに仕様からテストを作成
- すべてのテストが失敗する状態（Red）

**入力**:
- testPattern (unit / store / hook / component / integration)
- testFilePath
- 実装ファイルの仕様

**出力**:
- テストファイル作成
- テストケース数レポート

**テストパターン別テンプレート**:
- `.claude/test-patterns/unit-pure-function.md`
- `.claude/test-patterns/store.md`
- `.claude/test-patterns/hook.md`
- `.claude/test-patterns/component.md`
- `.claude/test-patterns/integration.md`

### test-runner

**役割**: テスト実行と状態判定

**期待状態**:
- `RED_EXPECTED` - 実装前、すべてのテストが失敗すべき
- `GREEN_EXPECTED` - 実装後、すべてのテストが成功すべき

**入力**:
- testFilePath
- expectation (RED_EXPECTED / GREEN_EXPECTED)

**出力**:
- テスト実行結果
- 状態判定 (SUCCESS / WARNING / ERROR)

**判定ロジック**:
```
RED_EXPECTED:
  - 全テスト失敗 → SUCCESS
  - 一部成功 → WARNING
  - 全テスト成功 → ERROR

GREEN_EXPECTED:
  - 全テスト成功 → SUCCESS
  - 一部失敗 → WARNING
  - 全テスト失敗 → ERROR
```

### implement

**役割**: コード実装

**TDD Green フェーズ**:
- テストを通す最小限の実装
- over-engineering を避ける

**入力**:
- testFilePath
- implFilePath
- テストファイルの内容

**出力**:
- 実装ファイル作成
- テスト結果レポート

**実装原則**:
- テストを通す最小限のコードのみ
- エラーハンドリングは必要最小限
- 抽象化は必要になってから
- YAGNI (You Aren't Gonna Need It) 原則

### review-file

**役割**: コード品質レビュー

**TDD Refactor フェーズ**:
- コード品質チェック
- 改善提案

**入力**:
- implFilePath
- reviewPerspective (code-quality など)

**出力**:
- 判定結果 (PASS / WARN / FAIL)
- 問題点リスト
- 改善提案

**レビュー観点**:
- 可読性
- 保守性
- パフォーマンス
- セキュリティ
- ベストプラクティス
- over-engineering の有無

### plan-fix

**役割**: 修正計画作成

**入力**:
- review-file の指摘事項
- implFilePath

**出力**:
- 修正計画（具体的な変更指示）

**使用タイミング**:
- review-file が WARN / FAIL の場合
- リファクタリングが必要な場合

---

## ベストプラクティス

### 1. エージェント実行は必ず順次実行

**重要**: エージェント間に依存関係があるため、**並列実行は不可**です。

```javascript
// ❌ 並列実行（依存関係があるため不可）
[
  Task(test-writer),
  Task(implement)
]

// ✅ 順次実行
Task(test-writer)
→ 完了待ち
→ Task(test-runner, RED_EXPECTED)
→ 完了待ち
→ Task(implement)
```

### 2. 状態の受け渡し

各エージェントの出力結果を次のエージェントに渡します。

```
test-writer の出力:
  - testFilePath: "src/utils/formatters.test.ts"

→ test-runner に渡す:
  - targetFile: "src/utils/formatters.test.ts"
  - expectation: "RED_EXPECTED"

→ implement に渡す:
  - testFilePath: "src/utils/formatters.test.ts"
  - implFilePath: "src/utils/formatters.ts"
```

### 3. テストファイルパスの一貫性

classify-files が提案したパスを厳守してください。

- **colocated**: 同階層
  - 例: `src/utils/formatters.test.ts`
- **separated**: `src/__tests__/integration/`
  - 例: `src/__tests__/integration/dataFlow.test.ts`

### 4. フィードバックフックの尊重

SubagentStop イベントで自動評価が実行されます。

- レポートは `.claude/reports/{agent-type}/` に保存
- エージェント定義ファイルに改善が追記される（必要に応じて）
- 手動編集は構造的な問題のみに限定

### 5. TODO.md の更新タイミング

- **全パイプライン完了後**に更新
- 途中でエラーが起きた場合は更新しない

---

## トラブルシューティング

問題が発生した場合は、以下を参照してください：

- [トラブルシューティングガイド](troubleshooting.md)
- [ベストプラクティス集](best-practices.md)

---

## 参考資料

- [エージェント定義](.claude/agents/)
- [テストパターン定義](.claude/test-patterns/)
