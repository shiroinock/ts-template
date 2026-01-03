# 現在のブランチの remote CI 状態を確認して修正方針を提案

**このコマンドの役割**: GitHub Actions上で実行されている **remote CI** の状態を確認し、失敗がある場合は原因を分析して修正方針を提案します。

## local-ci との違い

| コマンド | 実行場所 | 目的 | 使用場面 |
|---------|---------|------|----------|
| **check-ci** (このコマンド) | **remote** (GitHub Actions) | remote CI の実行状態確認と修正方針提案 | PR作成後、remote CI が失敗した際の原因調査 |
| **local-ci** | **local** | local CI チェック（CI相当）をローカル実行 | PR作成前の事前チェック、TDD完了後の検証 |

現在チェックアウトしているブランチの remote CI 実行状態を確認し、失敗がある場合は原因を分析して修正方針を提案してください。

**重要**: このコマンドは **サブエージェントを使用せず**、Bashツールで直接実装してください。

## 実装手順

### 1. 現在のブランチの最新 remote CI 実行を取得

```bash
# 現在のブランチ名
git branch --show-current

# 最新の remote CI 実行リスト（JSON形式、CI ワークフローのみ）
gh run list --branch $(git branch --show-current) --limit 5 --json databaseId,status,conclusion,createdAt,name,event
```

### 2. remote CI ワークフローを特定

`name: "CI"` のワークフローを見つける（Claude Code Review や Deploy は除外）

### 3. ステータスに応じた処理

#### ✅ success（完了・成功）
```markdown
## Remote CI Status Report

**ブランチ**: {branch}
**ステータス**: ✅ すべてのチェックがパスしました

**実行されたジョブ:**
- biome-check: ✅ 成功
- test: ✅ 成功
- build: ✅ 成功

このブランチはマージ可能な状態です。
```

#### ❌ failure（完了・失敗）

```bash
# 失敗したジョブのログを取得
gh run view <run-id> --log-failed
```

**ログから以下を抽出:**
1. どのジョブが失敗したか（biome-check / test / build）
2. どのステップで失敗したか
3. エラーメッセージの内容

**エラーパターンマッチング:**
- `pnpm install` + `lock file` → pnpm-lock.yaml不整合
- `biome check` + `fixed` → コードスタイル違反
- `test` + `FAIL` → テスト失敗
- `error TS` + 行番号 → TypeScript型エラー
- その他 → ログから推測

**修正方針レポートを生成:**
```markdown
## Remote CI Status Report

**ブランチ**: {branch}
**remote CI 実行**: {run-id} (completed - failure)

### 失敗したジョブ
- {job-name}: "{step-name}"で失敗

### エラー内容
{エラーメッセージ抜粋}

### 原因
{特定した原因}

### 修正方針
1. {修正手順1}
2. {修正手順2}

### 修正コマンド（推奨）
```bash
{具体的なコマンド}
```

### 次のステップ
- [ ] 上記コマンドを実行
- [ ] 変更をコミット
- [ ] プッシュしてCIを再実行
```

#### 🔄 in_progress（実行中）

```bash
# 現在の進行状況を表示
gh run view <run-id>
```

```markdown
## Remote CI Status Report

**ブランチ**: {branch}
**ステータス**: 🔄 remote CI 実行中

**進行状況:**
- biome-check: {status}
- test: {status}
- build: {status}

完了まで待機するか、現状を監視しますか？
```

#### ⏸️ queued（待機中）

```markdown
## Remote CI Status Report

**ブランチ**: {branch}
**ステータス**: ⏸️ remote CI 待機中

ジョブがキューに入っています。しばらく待ってから再度確認してください。
```

### 4. ユーザーに確認・修正実行

修正方針を提示した後、ユーザーに確認：
```
この修正方針で進めてよろしいですか？
```

承認されたら、提案したコマンドを実行。

## 実装上の注意事項

### ❌ やってはいけないこと
- WebFetchツールで GitHub Actions の HTMLページを取得する
- review-file やその他のサブエージェントにログ解析を依頼する
- サブエージェントを使用する

### ✅ 正しい実装
- Bashツールで `gh` コマンドを直接実行
- JSON出力を解析（`--json` オプション）
- ログは `--log-failed` で取得
- エラーパターンは文字列マッチングで判定

## エラーパターン辞書

| パターン | 原因 | 修正コマンド |
|---------|------|------------|
| `pnpm install` + `EUSAGE` + `lock file` | pnpm-lock.yaml不整合 | `rm -rf node_modules pnpm-lock.yaml && pnpm install` |
| `biome check` + `fixed` | コードスタイル違反 | `pnpm lint` |
| `test` + `FAIL` + ファイル名 | テスト失敗 | `pnpm test` で確認して修正 |
| `error TS2322` / `TS2564` など | TypeScript型エラー | 該当ファイルを修正 |
| `exclude` + テストファイル | tsconfig.json設定不足 | tsconfig.jsonにexclude追加 |

## 使用例

```
User: /check-remote-ci
Assistant: 現在のブランチのremote CI状態を確認します...
          [Bashツールでgh runコマンドを実行]
          [結果を分析してレポート生成]
          [修正方針を提示]
```
