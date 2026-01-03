# TDDトラブルシューティングガイド

このドキュメントでは、TDD運用中によく発生する問題とその解決方法を説明します。

## 目次

1. [エージェント実行エラー](#エージェント実行エラー)
2. [テスト実行エラー](#テスト実行エラー)
3. [パイプライン失敗](#パイプライン失敗)
4. [フィードバックループ](#フィードバックループ)
5. [コマンド実行エラー](#コマンド実行エラー)

---

## エージェント実行エラー

### エージェントが見つからない

**エラーメッセージ**:
```
Agent type 'test-runner' not found
```

**原因**:
- エージェント定義ファイルが存在しない
- Claude Code が再起動されていない

**解決方法**:
1. エージェント定義ファイルを確認
   ```bash
   ls .claude/agents/test-runner.md
   ```

2. Claude Code を再起動
   - エージェント定義の変更は再起動後に反映される

### エージェントが途中で停止する

**症状**:
- エージェントが実行中に突然停止
- タイムアウトエラー

**原因**:
- タスクが複雑すぎる
- メモリ不足
- ネットワークエラー

**解決方法**:

1. **タスクを分割する**
   ```bash
   # ❌ 複雑すぎるタスク
   /tdd-implement src/components/ComplexComponent.tsx

   # ✅ 分割して実装
   /tdd-implement src/components/ComplexComponent/Header.tsx
   /tdd-implement src/components/ComplexComponent/Body.tsx
   /tdd-implement src/components/ComplexComponent/Footer.tsx
   ```

2. **モデルを変更する**
   - `model: "haiku"` → より軽量で高速
   - `model: "sonnet"` → バランス型（デフォルト）
   - `model: "opus"` → 最高性能だが遅い

3. **リトライする**
   - エージェントを再実行
   - 前回の結果を参考に修正

### 並列実行エラー

**エラーメッセージ**:
```
Multiple agents are running in parallel
```

**原因**:
- 依存関係のあるエージェントを並列実行している

**解決方法**:

```javascript
// ❌ 並列実行（依存関係があるため不可）
Task(test-writer)
Task(implement)  // test-writerの結果に依存

// ✅ 順次実行
Task(test-writer)
→ 完了待ち
→ Task(implement)
```

**修正手順**:
1. コマンド定義ファイルを修正
2. 順次実行に変更
3. Claude Code を再起動

---

## テスト実行エラー

### テストが Red にならない（test-writer 直後）

**症状**:
- test-writer がテストを作成
- 実装ファイルが存在しないのにテストが通る

**原因**:
- test-writer が実装コードを含めてテストを作成した
- モックが過剰に使用されている

**解決方法**:

1. **テストファイルを確認**
   ```bash
   cat src/utils/formatters.test.ts | grep "import.*formatters"
   ```

2. **test-writer に警告を出力**
   - フィードバックフックが自動で改善提案を追記

3. **手動で修正**（必要に応じて）
   - テストから実装コードを削除
   - モックを削除

### テストが Green にならない（implement 直後）

**症状**:
- implement が実装を作成
- テストが失敗し続ける

**原因**:
- テストの期待値が間違っている
- 実装のロジックが間違っている
- 入力バリデーションが不足している

**解決方法**:

1. **テスト失敗の詳細を確認**
   ```bash
   pnpm test src/utils/formatters.test.ts 2>&1 | grep "Error:"
   ```

2. **plan-fix エージェントで修正計画を作成**
   ```
   plan-fix が自動起動
   → 修正計画を作成
   → implement が修正を実施
   ```

3. **最大3回までリトライ**
   - それでも失敗 → ユーザーに報告

4. **手動で修正**（最終手段）
   - テストまたは実装を直接編集

### 浮動小数点精度エラー

**エラーメッセージ**:
```
Expected: 123.45
Received: 123.44999999999999
```

**原因**:
- 浮動小数点演算の精度誤差

**解決方法**:

```typescript
// ❌ 厳密な等価比較
expect(result).toBe(123.45);

// ✅ 許容誤差付き比較
expect(result).toBeCloseTo(123.45, 2);  // 小数第2位まで一致
```

**テストパターンの修正**:
- `.claude/test-patterns/unit-pure-function.md` に追記
- test-writer が自動で `toBeCloseTo()` を使用

---

## パイプライン失敗

### classify-files の判定が不明確

**症状**:
- classify-files が判定できない
- tddMode または testPattern が空

**原因**:
- ファイルの性質が特殊
- 既存のテストパターンに合致しない

**解決方法**:

1. **ユーザーに確認**
   ```
   classify-files が判定できませんでした。

   ファイル: src/utils/specialUtil.ts

   以下を選択してください:
   1. tddMode: test-first / test-later
   2. testPattern: unit / store / hook / component / integration
   ```

2. **手動で指定してパイプライン続行**
   ```bash
   /tdd-implement src/utils/specialUtil.ts
   # → 確認ダイアログで選択
   ```

### review-file が FAIL を返す

**症状**:
- review-file が重大な問題を検出
- FAIL判定

**原因**:
- セキュリティリスク
- over-engineering
- コーディング規約違反

**解決方法**:

1. **plan-fix が自動起動**
   ```
   review-file (FAIL)
   → plan-fix (修正計画作成)
   → implement (修正実施)
   → test-runner (Green維持確認)
   ```

2. **修正内容を確認**
   - `.claude/reports/plan-fix/` のレポートを参照

3. **手動で修正**（必要に応じて）

### TODO.md が更新されない

**症状**:
- パイプラインは成功
- TODO.md が `- [ ]` のまま

**原因**:
- パイプライン途中でエラーが発生した
- TODO.md の更新処理が実行されなかった

**解決方法**:

1. **手動で TODO.md を更新**
   ```markdown
   ### 1.2 バリデーション (`src/utils/validators.ts`)
   - [x] `validateEmail(email)` 関数
   - [x] `validatePassword(password)` 関数
   ...
   ```

2. **パイプラインを再実行**
   - `/tdd-next` で次のタスクへ

---

## フィードバックループ

### レポートが生成されない

**症状**:
- `.claude/reports/` にレポートが生成されない

**原因**:
- SubagentStop フックが実行されていない
- evaluate-subagent.sh にエラーがある

**解決方法**:

1. **フックの確認**
   ```bash
   cat .claude/hooks.json | grep "SubagentStop"
   ```

2. **evaluate-subagent.sh の実行テスト**
   ```bash
   bash .claude/scripts/evaluate-subagent.sh test-writer
   ```

3. **エラーログを確認**
   ```bash
   cat .claude/reports/test-writer/evaluation_*.md | grep "Error:"
   ```

### 評価スクリプトのエラー

**エラーメッセージ**:
```
Error: Input must be provided either through stdin or as a prompt argument when using --print
```

**原因**:
- `claude` コマンドのオプション指定が間違っている

**解決方法**:

1. **evaluate-subagent.sh を修正**
   ```bash
   # ❌ 間違い
   EVALUATION_RESULT=$(claude --allowedTools "Edit,Read" -p "$EVAL_PROMPT" 2>&1)

   # ✅ 修正（オプションは一つのみ）
   EVALUATION_RESULT=$(echo "$EVAL_PROMPT" | claude --allowedTools "Edit,Read" 2>&1)
   ```

2. **レポート生成を確認**
   ```bash
   ls -lt .claude/reports/test-writer/
   ```

### エージェント定義ファイルに改善が追記されない

**症状**:
- レポートは生成される
- エージェント定義ファイルに改善提案が追記されない

**原因**:
- 評価プロンプトが改善提案を生成していない
- Edit ツールが実行されていない

**解決方法**:

1. **評価プロンプトを確認**
   ```bash
   cat .claude/evaluation-prompts/test-writer.md
   ```

2. **手動で改善提案を追記**（必要に応じて）
   ```markdown
   ## 改善提案（過去のフィードバック）

   - 浮動小数点比較には toBeCloseTo() を使用する
   - テストファイルには実装コードを含めない
   ```

---

## コマンド実行エラー

### /tdd-next が次タスクを選定できない

**症状**:
- `/tdd-next` を実行
- 「次タスクが見つかりません」エラー

**原因**:
- TODO.md に `- [ ]` タスクがない
- TODO.md のフォーマットが間違っている

**解決方法**:

1. **TODO.md を確認**
   ```bash
   cat TODO.md | grep "- \[ \]"
   ```

2. **フォーマットを修正**
   ```markdown
   ### 1.3 ユーティリティ (`src/utils/helpers.ts`)
   - [ ] `formatDate(date)` 関数
   - [ ] `parseDate(text)` 関数
   ```

3. **次タスクを手動で指定**
   ```bash
   /tdd-implement src/utils/helpers.ts
   ```

### /tdd-implement がファイルを作成できない

**症状**:
- `/tdd-implement` を実行
- ファイルが作成されない

**原因**:
- ディレクトリが存在しない
- 権限エラー

**解決方法**:

1. **ディレクトリを作成**
   ```bash
   mkdir -p src/utils
   ```

2. **権限を確認**
   ```bash
   ls -ld src/utils
   ```

3. **手動でファイルを作成**（最終手段）
   ```bash
   touch src/utils/helpers.ts
   touch src/utils/helpers.test.ts
   ```

### テストファイルパスが間違っている

**症状**:
- classify-files が提案したパスが間違っている
- separated配置なのに colocated になっている

**原因**:
- classify-files の判定ロジックに問題

**解決方法**:

1. **classify-files の判定を確認**
   ```bash
   cat .claude/reports/classify-files/evaluation_*.md
   ```

2. **手動でパスを修正**
   ```bash
   # テストファイルを正しい場所に移動
   mv src/utils/dataFlow.test.ts src/__tests__/integration/dataFlow.test.ts
   ```

3. **classify-files.md に改善提案を追記**
   ```markdown
   ## 改善提案

   - integration パターンは separated 配置を推奨
   - testFilePath: src/__tests__/integration/{filename}.test.ts
   ```

---

## よくある質問

### Q1: テストが多すぎる場合、どうすればいいですか？

**A**: test-writer が作成したテストケース数を確認し、必要に応じて削減します。

1. **テストケース数を確認**
   ```bash
   grep "test(" src/utils/formatters.test.ts | wc -l
   ```

2. **不要なテストを削除**
   - エッジケースのテストが重複している場合
   - 境界値テストが過剰な場合

3. **test-writer に改善提案**
   - フィードバックフックが自動で調整

### Q2: ドメインロジックとプレゼンテーション層の分離を保つには？

**A**: レイヤー分離の原則を守ります。

**原則**:
- **ドメインロジック**: ビジネスルール、計算、バリデーション
- **プレゼンテーション層**: UI表示、フォーマット、ユーザー入力

**チェック方法**:
1. review-file が自動検出
2. ファイル配置を明確にする
   - ドメイン: `src/utils/`, `src/services/`
   - プレゼンテーション: `src/components/`, `src/hooks/`

### Q3: over-engineering を避けるには？

**A**: テストを通す最小限の実装のみを書きます。

**避けるべきパターン**:
- 将来使うかもしれない機能の実装
- 抽象化層の追加
- 不要なデザインパターンの適用
- 設定ファイルの作成

**実装ガイドライン**:
- YAGNI (You Aren't Gonna Need It) 原則
- 必要になってから追加する
- リファクタリングは後で

---

## 緊急時の対処

### すべて失敗した場合

1. **ログを確認**
   ```bash
   cat .claude/reports/*/*.md | tail -100
   ```

2. **エージェントを個別に実行**
   ```bash
   # classify-files のみ実行
   Task(classify-files, ...)

   # test-writer のみ実行
   Task(test-writer, ...)
   ```

3. **手動で実装**
   - テストファイルを手動作成
   - 実装ファイルを手動作成
   - `pnpm test` で確認

4. **GitHub Issue に報告**
   - エラーログを添付
   - 再現手順を記載

---

## 参考資料

- [TDD運用ガイド](tdd-workflow.md)
- [ベストプラクティス集](best-practices.md)
