---
description: テストを実行し、結果を報告するエージェント
allowed-tools: Bash
model: haiku
---

# Test Check エージェント

## 目的

`pnpm test` を実行し、全テストスイートの実行結果を報告します。

## 実行内容

```bash
pnpm test
```

## 実装手順

### Step 1: テスト実行

```bash
pnpm test
```

### Step 2: 結果判定

テスト結果から成功数・失敗数を抽出します。

**成功した場合**:
```
✅ Tests: PASSED (X tests passed)
```

**失敗した場合**:
```
❌ Tests: FAILED

Failed tests:
{失敗したテストの詳細}
```

## 出力フォーマット

**重要**: 親エージェント（local-ci-checker）が処理できるよう、以下の構造化されたJSON形式で出力してください。

### 基本構造

```json
{
  "check": "test",
  "status": "PASSED|FAILED",
  "duration": 45230,
  "summary": {
    "message": "簡潔な結果サマリー（1行）"
  },
  "details": {
    "testFiles": {
      "total": 46,
      "passed": 46,
      "failed": 0
    },
    "tests": {
      "total": 1000,
      "passed": 1000,
      "failed": 0,
      "skipped": 0
    }
  },
  "errors": []  // 失敗時のみ含める
}
```

### 成功時の例

```json
{
  "check": "test",
  "status": "PASSED",
  "duration": 45230,
  "summary": {
    "message": "All tests passed (1,000 tests in 46 files)"
  },
  "details": {
    "testFiles": {
      "total": 46,
      "passed": 46,
      "failed": 0
    },
    "tests": {
      "total": 1000,
      "passed": 1000,
      "failed": 0,
      "skipped": 0
    },
    "coverage": {
      "statements": 98.5,
      "branches": 95.2,
      "functions": 99.1,
      "lines": 98.3
    }
  }
}
```

### 失敗時の例

```json
{
  "check": "test",
  "status": "FAILED",
  "duration": 42150,
  "summary": {
    "message": "Tests failed (3 failed out of 1,000 tests)"
  },
  "details": {
    "testFiles": {
      "total": 46,
      "passed": 45,
      "failed": 1
    },
    "tests": {
      "total": 1000,
      "passed": 997,
      "failed": 3,
      "skipped": 0
    }
  },
  "errors": [
    {
      "file": "src/utils/validation.test.ts",
      "testName": "isValidInput › should return false for negative values",
      "error": "AssertionError: expected true to be false",
      "expected": false,
      "received": true,
      "location": "src/utils/validation.test.ts:145:23",
      "severity": "error"
    }
  ]
}
```

### エラーオブジェクトの仕様

各エラーは以下のフィールドを含む必要があります：

```typescript
interface TestError {
  file: string;          // テストファイルパス
  testName: string;      // テスト名（describe › it 形式）
  error: string;         // エラー種別
  expected?: any;        // 期待値（アサーションエラーの場合）
  received?: any;        // 実際の値（アサーションエラーの場合）
  location: string;      // エラー発生箇所（file:line:column形式）
  severity: "error";     // 深刻度（常にerror）
  message?: string;      // 追加のエラーメッセージ
}
```

## 実装時の注意事項

1. **JSON形式の厳密性**
   - 全ての出力は有効なJSONでなければなりません
   - 文字列内の特殊文字は適切にエスケープしてください

2. **エラー件数の制限**
   - エラーが100件を超える場合、errors 配列は最大100件に制限してください
   - details.tests.failed フィールドで実際の失敗テスト総数を示してください

3. **テストカウントの正確性**
   - testFiles と tests の両方のカウントを正確に取得してください
   - skipped テストも含めてカウントしてください

4. **カバレッジ情報**
   - 成功時のみ coverage フィールドを含めてください（オプション）
   - カバレッジが取得できない場合は省略可能です

5. **実行時間の測定**
   - duration フィールドはミリ秒単位で測定してください
