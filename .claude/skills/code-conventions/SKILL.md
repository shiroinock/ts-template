---
name: code-conventions
description: Defines project-wide code conventions for magic number elimination, constant usage, performance optimization, and type safety. Use when implementing, testing, or reviewing code to ensure consistency across the codebase.
allowed-tools: Read
---

# コード規約スキル

このスキルは、プロジェクトの共通コード規約を定義し、エージェント定義ファイルから参照されます。

## 基本原則

### 1. マジックナンバーの排除

**原則**: ドメイン知識としてみなせる数値は、必ず定数として定義し、コード中での直接記述を避ける。

**定義例**:
```typescript
// ❌ マジックナンバー（避けるべき）
const maxRetries = 3;
const timeout = 5000;
const pageSize = 20;

// ✅ 定数インポート（推奨）
import { CONFIG } from './constants';
const maxRetries = CONFIG.network.maxRetries;
const timeout = CONFIG.network.timeoutMs;
const pageSize = CONFIG.pagination.defaultPageSize;
```

**ドメイン知識として扱う数値の例**:
- ビジネスルールに関わる数値
- 設定値、閾値
- フォーマット関連の定数（桁数、長さ制限など）
- APIのバージョン番号、エンドポイント

### 2. 定数参照の原則

**実装ファイルでの定義**:
```typescript
// src/utils/constants.ts
export const CONFIG = {
  network: {
    maxRetries: 3,
    timeoutMs: 5000,
    retryDelayMs: 1000
  },
  pagination: {
    defaultPageSize: 20,
    maxPageSize: 100
  }
} as const;
```

**テストファイルでの使用**:
```typescript
// src/utils/api.test.ts
import { CONFIG } from './constants';

test('最大リトライ回数でリトライする', () => {
  const expectedRetries = CONFIG.network.maxRetries;
  // ...
});
```

**メリット**:
1. 定数値の変更時にテストが自動的に追従する
2. コメントで値の意味を説明する必要がなくなる
3. タイポや値の誤りを防げる
4. ドメイン知識の一元管理が実現される

### 3. パフォーマンス最適化

**原則**: 繰り返し処理で共通の操作は、ループ外に抽出する。

**例**:
```typescript
// ❌ 非効率（毎回呼び出し）
items.forEach((item) => {
  const config = getConfig();  // ← 毎回呼び出し
  processItem(item, config);
});

// ✅ 効率的（1回呼び出し）
const config = getConfig();  // ← ループ外で一度だけ
items.forEach((item) => {
  processItem(item, config);
});
```

### 4. コメント規約

**定数のコメント例**:
```typescript
export const CONFIG = {
  network: {
    maxRetries: 3,        // 最大リトライ回数
    timeoutMs: 5000,      // タイムアウト時間（ミリ秒）
    retryDelayMs: 1000    // リトライ間隔（ミリ秒）
  }
} as const;
```

**テストコメント例**:
```typescript
// 期待されるリトライ回数を設定から取得
const expectedRetries = CONFIG.network.maxRetries;
```

### 5. 型安全性の原則

**原則**: 型アサーション（`as`）は可能な限り避け、型ガードを使用する。

**型アサーションは避ける（非推奨）**:
```typescript
// ❌ 型アサーション（避けるべき）
const typedData = data as { config?: Partial<Config> };
if (typedData.config) {
  // 実行時エラーのリスクがある
}
```

**型ガードを使用（推奨）**:
```typescript
// ✅ 型ガード（推奨）
if (
  typeof data === 'object' &&
  data !== null &&
  'config' in data
) {
  const config = data.config;
  if (config && typeof config === 'object') {
    // 型安全に処理できる
  }
}
```

**ヘルパー関数で型ガードを抽出（より推奨）**:
```typescript
// ✅ 再利用可能な型ガード
const isConfigData = (
  data: unknown
): data is { config: unknown } => {
  return (
    data !== null &&
    typeof data === 'object' &&
    'config' in data
  );
};

// 使用例
if (isConfigData(parsed)) {
  return parsed; // 型安全
}
```

**メリット**:
1. 実行時のデータ構造を正確にチェックできる
2. 型アサーションによる誤った型推論を防げる
3. リファクタリング時の安全性が向上する
4. コードの意図が明確になる

### 6. マジック文字列の定数化

**原則**: 繰り返し使用される文字列リテラルは定数として定義する。

**定数化すべき文字列の例**:
```typescript
// ❌ マジック文字列（避けるべき）
const STORAGE_KEYS = {
  'user-settings': 'user-settings',  // 同じ文字列の重複
  // ...
};

// ✅ 定数化（推奨）
const USER_SETTINGS_KEY = 'user-settings' as const;
const STORAGE_KEYS = {
  [USER_SETTINGS_KEY]: USER_SETTINGS_KEY,
};
```

**メリット**:
1. タイポによるバグを防げる
2. リネーム時の変更箇所が減る
3. コードの意図が明確になる
4. IDEの補完が効く

### 7. エラーハンドリングとロギング

**原則**: サイレントに失敗する場合でも、デバッグ用にログを残す。

**ロギングなし（非推奨）**:
```typescript
// ❌ エラーを無視（デバッグが困難）
try {
  localStorage.setItem(key, JSON.stringify(value));
} catch {
  // エラーハンドリング: 保存失敗時は何もしない
}
```

**ロギングあり（推奨）**:
```typescript
// ✅ console.warnでエラーを記録（推奨）
try {
  localStorage.setItem(key, JSON.stringify(value));
} catch (error) {
  // localStorage容量制限やシリアライズエラーを無視
  // アプリケーションの動作には影響しないため、サイレントに失敗
  console.warn('Failed to save to localStorage:', error);
}
```

**メリット**:
1. 本番環境でのデバッグが容易になる
2. エラーの発生頻度を把握できる
3. ユーザー体験を損なわずに問題を追跡できる

**ガイドライン**:
- アプリケーション動作に影響しないエラー → `console.warn`
- ユーザーに通知すべきエラー → UIで表示 + `console.error`
- 開発中のみ必要な情報 → `console.log`（本番では削除）

### 8. 重複コードの排除

**原則**: 同じロジックが複数箇所に存在する場合は、関数として抽出する。

**重複あり（非推奨）**:
```typescript
// ❌ 重複したロジック
const loadUserConfig = (): Config => {
  return { ...DEFAULT_CONFIG };
};

const initialState = {
  config: loadUserConfig(),
};

const resetConfig = (): Config => {
  return { ...DEFAULT_CONFIG };  // 同じロジック
};
```

**重複なし（推奨）**:
```typescript
// ✅ 単一の関数に統一
const getDefaultConfig = (): Config => {
  return { ...DEFAULT_CONFIG };
};

const initialState = {
  config: getDefaultConfig(),
};

const resetConfig = (): Config => {
  return getDefaultConfig();  // 同じ関数を再利用
};
```

**メリット**:
1. 修正時の変更箇所が減る
2. ロジックの一貫性が保たれる
3. テストが容易になる

### 9. ヘルパー関数の配置と命名

**原則**: ヘルパー関数は使用箇所の前に定義し、意図が明確な名前を付ける。

**配置の例**:
```typescript
// 1. 定数定義
const DEFAULT_CONFIG_KEY = 'default-config' as const;

// 2. データ定義（定数を使用する可能性がある）
const CONFIGS: Record<string, Config> = {
  [DEFAULT_CONFIG_KEY]: { /* ... */ }
};

// 3. ヘルパー関数（データ定義後に配置）
const isValidConfig = (data: unknown): data is Config => { /* ... */ };
const getDefaultConfig = (): Config => { /* ... */ };

// 4. メインロジック（ヘルパー関数を使用）
export const useConfigStore = create<ConfigStore>()(/* ... */);
```

**命名のガイドライン**:
- 型ガード関数: `is〜`（例: `isValidConfig`, `isUserData`）
- 取得関数: `get〜`（例: `getDefaultConfig`, `getUserById`）
- 変換関数: `to〜`または`〜To〜`（例: `toJSON`, `stringToNumber`）
- チェック関数: `has〜`、`can〜`（例: `hasPermission`, `canEdit`）

### 10. 既存の定数・仕様の尊重（重要）

**原則**: テスト作成時は既存の定数や仕様を必ず尊重する。

1. **既存の定数を使用する**
   - `constants.ts`などに既に定義されている定数は、必ずインポートして使用
   - テスト内で独自の値をハードコードしない

   ```typescript
   // ❌ 避けるべき（独自の値をハードコード）
   const stored = localStorage.getItem('my-custom-key');

   // ✅ 推奨（既存の定数をインポート）
   import { STORAGE_KEY } from './constants';
   const stored = localStorage.getItem(STORAGE_KEY);
   ```

2. **既存の実装仕様を変更させない**
   - テストに合わせて既存の定数値を変更させない
   - 実装側の仕様が正しい場合、テストをそれに合わせる
   - 定数値に疑問がある場合は、実装前にユーザーに確認

3. **後方互換性の考慮**
   - localStorageのキーなど、変更すると既存データが読めなくなる値には特に注意
   - 既存ユーザーへの影響を考慮した値の選択

## チェックリスト

### 実装時の確認項目

- [ ] ドメイン知識としてみなせる数値が定数として定義されているか
- [ ] テストファイルでも定数をインポートして使用しているか
- [ ] ループ外で実行可能な処理がループ内に含まれていないか
- [ ] 型アサーション（`as`）を避け、型ガードを使用しているか
- [ ] マジック文字列を定数化しているか
- [ ] サイレントエラーにログ出力を追加しているか
- [ ] 重複コードを関数として抽出しているか
- [ ] ヘルパー関数が適切に配置され、明確な名前が付けられているか
- [ ] 既存の定数や仕様を尊重しているか

### レビュー時の確認項目

1. **型安全性**:
   - 型アサーション（`as`）が使用されている場合、型ガードに置き換え可能か？
   - `unknown`型のデータを適切に型ガードでチェックしているか？

2. **可読性**:
   - 複雑な型ガードロジックをヘルパー関数として抽出できるか？
   - 関数名が意図を明確に表しているか？

3. **保守性**:
   - マジック文字列/数値が定数化されているか？
   - 重複したロジックが存在しないか？

4. **デバッグ性**:
   - サイレントに失敗するエラーにログ出力があるか？
   - エラーメッセージが問題特定に役立つか？

5. **設計品質**:
   - ヘルパー関数の配置が依存関係を考慮しているか？
   - 単一責任の原則に従っているか？
