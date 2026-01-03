---
description: ビルドを実行し、結果を報告するエージェント
allowed-tools: Bash
model: haiku
---

# Build Check エージェント

## 目的

`pnpm build` を実行し、TypeScriptコンパイル + Viteビルドの結果を報告します。

## 実行内容

```bash
pnpm build
```

## 実装手順

### Step 1: ビルド実行

```bash
pnpm build
```

### Step 2: 結果判定

**成功した場合**:
```
✅ Build: PASSED
```

**失敗した場合**:
```
❌ Build: FAILED

Errors:
{ビルドエラー・型エラーの詳細}
```

## 出力フォーマット

**重要**: 親エージェント（local-ci-checker）が処理できるよう、以下の構造化されたJSON形式で出力してください。

### 基本構造

```json
{
  "check": "build",
  "status": "PASSED|FAILED",
  "duration": 12340,
  "summary": {
    "message": "簡潔な結果サマリー（1行）"
  },
  "details": {
    // チェック固有の詳細情報
  },
  "errors": []  // 失敗時のみ含める
}
```

### 成功時の例

```json
{
  "check": "build",
  "status": "PASSED",
  "duration": 12340,
  "summary": {
    "message": "Build succeeded"
  },
  "details": {
    "outputSize": "245.3 KB",
    "chunks": [
      {
        "name": "index.js",
        "size": "189.2 KB"
      },
      {
        "name": "vendor.js",
        "size": "56.1 KB"
      }
    ]
  }
}
```

### 失敗時の例（TypeScriptエラー）

```json
{
  "check": "build",
  "status": "FAILED",
  "duration": 8230,
  "summary": {
    "message": "Build failed (2 TypeScript errors)"
  },
  "details": {
    "errorCount": 2,
    "warningCount": 0
  },
  "errors": [
    {
      "file": "src/types/User.ts",
      "line": 5,
      "column": 3,
      "code": "TS2322",
      "message": "Type 'number | undefined' is not assignable to type 'number'.",
      "severity": "error"
    }
  ]
}
```

### 失敗時の例（Viteビルドエラー）

```json
{
  "check": "build",
  "status": "FAILED",
  "duration": 2150,
  "summary": {
    "message": "Build failed (module resolution error)"
  },
  "details": {
    "errorType": "module-resolution"
  },
  "errors": [
    {
      "file": "src/components/Settings.tsx",
      "line": 3,
      "message": "Could not resolve './SettingsPanel' from 'src/components/Settings.tsx'",
      "severity": "error"
    }
  ]
}
```

### エラーオブジェクトの仕様

各エラーは以下のフィールドを含む必要があります：

```typescript
interface BuildError {
  file: string;           // エラーが発生したファイルパス
  line?: number;          // 行番号（ある場合）
  column?: number;        // 列番号（ある場合）
  code?: string;          // エラーコード（TypeScriptの場合、例: TS2322）
  message: string;        // エラーメッセージ
  severity: "error" | "warning";  // 深刻度
}
```

## 実装時の注意事項

1. **JSON形式の厳密性**
   - 全ての出力は有効なJSONでなければなりません
   - 文字列内の特殊文字は適切にエスケープしてください

2. **エラー件数の制限**
   - エラーが100件を超える場合、errors 配列は最大100件に制限してください
   - details.errorCount フィールドで実際のエラー総数を示してください

3. **エラータイプの区別**
   - TypeScriptエラーとViteビルドエラーを区別してください
   - TypeScriptエラーの場合は code フィールド（TS2322など）を含めてください
   - Viteエラーの場合は details.errorType を含めてください

4. **ファイルパスの正規化**
   - 全てのファイルパスはプロジェクトルートからの相対パスとしてください

5. **実行時間の測定**
   - duration フィールドはミリ秒単位で測定してください

6. **ビルド成果物の情報**
   - 成功時は details にビルド成果物のサイズ情報を含めてください（オプション）
   - chunks 配列には主要なチャンクの名前とサイズを含めてください
