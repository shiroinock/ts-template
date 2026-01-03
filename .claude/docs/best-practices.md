# TDDベストプラクティス集

このドキュメントでは、Claude Code を使用した TDD 開発のベストプラクティスを説明します。

## 目次

1. [テスト設計](#テスト設計)
2. [実装原則](#実装原則)
3. [エージェント活用](#エージェント活用)
4. [パフォーマンス最適化](#パフォーマンス最適化)
5. [メンテナンス](#メンテナンス)

---

## テスト設計

### AAA パターン（Arrange-Act-Assert）

すべてのテストで3段階構造を明示します。

```typescript
test("formatCurrency は数値を通貨形式にフォーマットする", () => {
  // Arrange: テストデータを準備
  const amount = 1234.56;

  // Act: テスト対象を実行
  const result = formatCurrency(amount);

  // Assert: 結果を検証
  expect(result).toBe('¥1,234.56');
});
```

**利点**:
- テストの意図が明確
- 可読性が高い
- デバッグしやすい

### 境界値テスト

境界値を必ずテストします。

```typescript
describe("validateAge - 境界値テスト", () => {
  test("最小値（0歳）- ちょうど", () => {
    expect(validateAge(0)).toBe(true);
  });

  test("最小値未満（-1歳）", () => {
    expect(validateAge(-1)).toBe(false);
  });

  test("最大値（120歳）- ちょうど", () => {
    expect(validateAge(120)).toBe(true);
  });

  test("最大値超過（121歳）", () => {
    expect(validateAge(121)).toBe(false);
  });
});
```

**境界値の例**:
- 年齢: 0歳、18歳（成人）、120歳（上限）
- 価格: 0円、最小注文額、最大購入額
- 文字数: 0文字、最小長、最大長
- 配列: 空配列、1要素、最大要素数

### 浮動小数点比較

`toBeCloseTo()` を使用して許容誤差を指定します。

```typescript
// ❌ 厳密な等価比較（浮動小数点誤差で失敗する可能性）
expect(result).toBe(123.45);

// ✅ 許容誤差付き比較
expect(result).toBeCloseTo(123.45, 2);  // 小数第2位まで一致

// ✅ 計算の往復変換
const formatted = formatCurrency(1234.56);
const parsed = parseCurrency(formatted);
expect(parsed).toBeCloseTo(1234.56, 2);
```

**許容誤差の目安**:
- 金額計算: 小数第2位（0.01円）
- パーセンテージ: 小数第1位（0.1%）
- 時間計算: 小数第3位（0.001秒）

### 可逆性テスト

往復変換で元の値に戻ることを確認します。

```typescript
test("データ変換の可逆性 - encode → decode", () => {
  // Arrange
  const original = { name: 'Alice', age: 30 };

  // Act: 往復変換
  const encoded = encodeData(original);
  const decoded = decodeData(encoded);

  // Assert: 元の値に戻る
  expect(decoded).toEqual(original);
});
```

**可逆性が重要な関数**:
- エンコード・デコード（encode ↔ decode）
- シリアライズ・デシリアライズ（serialize ↔ deserialize）
- フォーマット・パース（format ↔ parse）

### テストケース名の命名規則

```typescript
// ✅ 良い命名（何をテストするか明確）
test("formatCurrency は1000を'¥1,000'にフォーマットする", () => { ... });
test("validateEmail は無効なアドレスでfalseを返す", () => { ... });
test("calculateDiscount は会員価格で10%割引を適用する", () => { ... });

// ❌ 悪い命名（曖昧）
test("正しく動作する", () => { ... });
test("テスト1", () => { ... });
test("境界値", () => { ... });
```

**命名パターン**:
- `{関数名} は {入力} で {期待結果} を返す`
- `{関数名} は {条件} の場合 {動作} する`

---

## 実装原則

### YAGNI（You Aren't Gonna Need It）

将来使うかもしれない機能は実装しません。

```typescript
// ❌ over-engineering（将来使うかもしれない機能）
interface FormatterConfig {
  locale: 'ja' | 'en' | 'zh';
  currency: 'JPY' | 'USD' | 'EUR';
  precision: number;
  thousandsSeparator: string;
}

export function formatCurrency(
  amount: number,
  config?: FormatterConfig
): string {
  // 複雑な設定処理...
}

// ✅ YAGNI原則（今必要な機能のみ）
export function formatCurrency(amount: number): string {
  return `¥${amount.toLocaleString('ja-JP')}`;
}
```

**避けるべきパターン**:
- 設定ファイルの作成（まだ設定可能にする必要がない）
- 抽象化層の追加（まだ複数の実装がない）
- デザインパターンの適用（まだパターンが必要ない）

### テストを通す最小限の実装

```typescript
// テスト
test("calculateDiscount は会員で10%割引を返す", () => {
  expect(calculateDiscount(1000, 'member')).toBe(900);
});

// ❌ over-implementation（不要な処理）
export function calculateDiscount(price: number, userType: string): number {
  // 入力値の詳細なバリデーション（テストされていない）
  if (typeof price !== 'number') {
    throw new Error('price must be a number');
  }
  if (!Number.isInteger(price)) {
    throw new Error('price must be an integer');
  }

  // キャッシング（パフォーマンスが問題になってから）
  const cacheKey = `${price}-${userType}`;
  if (discountCache.has(cacheKey)) {
    return discountCache.get(cacheKey)!;
  }

  // ... 実際の計算
}

// ✅ 最小限の実装（テストを通すのに必要な処理のみ）
export function calculateDiscount(price: number, userType: string): number {
  if (userType === 'member') return price * 0.9;
  if (userType === 'premium') return price * 0.8;
  return price;
}
```

### DRY（Don't Repeat Yourself） vs WET（Write Everything Twice）

**3回繰り返したら抽象化**を検討します。

```typescript
// ❌ 1回しか使わないのに抽象化
const createValidator = (min: number, max: number) =>
  (value: number) => value >= min && value <= max;
const isValidAge = createValidator(0, 120);
const isValidScore = createValidator(0, 100);

// ✅ シンプルな実装（まだ抽象化不要）
function validateAge(age: number): boolean {
  return age >= 0 && age <= 120;
}

function validateScore(score: number): boolean {
  return score >= 0 && score <= 100;
}
```

**抽象化のタイミング**:
1. 同じパターンが3回以上登場
2. 変更が複数箇所に影響する
3. テストで複数パターンを検証済み

### エラーハンドリング

必要最小限のエラーハンドリングのみ実装します。

```typescript
// ❌ 過剰なエラーハンドリング
export function calculateDiscount(price: number): number {
  if (price === null || price === undefined) {
    throw new Error('price is required');
  }
  if (typeof price !== 'number') {
    throw new Error('price must be a number');
  }
  if (isNaN(price)) {
    throw new Error('price must not be NaN');
  }
  if (!isFinite(price)) {
    throw new Error('price must be finite');
  }
  if (price < 0) {
    throw new Error('price must be non-negative');
  }
  // ... 実際の処理
}

// ✅ 必要最小限のエラーハンドリング
export function calculateDiscount(price: number): number {
  if (price < 0) {
    throw new Error('Price cannot be negative');
  }
  // ... 実際の処理
}
```

**エラーハンドリングが必要なケース**:
- ビジネスルール違反（負の価格など）
- 計算エラーを引き起こす値（ゼロ除算など）
- ドメインルール違反（無効な状態遷移など）

---

## エージェント活用

### エージェント実行は順次実行

**重要**: 依存関係のあるエージェントは**必ず順次実行**します。

```javascript
// ❌ 並列実行（依存関係があるため不可）
async function runPipeline() {
  await Promise.all([
    Task(test-writer),
    Task(implement)  // test-writerの結果に依存
  ]);
}

// ✅ 順次実行
async function runPipeline() {
  await Task(test-writer);
  // test-writerの完了を待つ

  await Task(test-runner, { expectation: 'RED_EXPECTED' });
  // test-runnerの完了を待つ

  await Task(implement);
  // implementの完了を待つ
}
```

### 状態の明示的な受け渡し

各エージェントの出力を次のエージェントに明示的に渡します。

```typescript
// ✅ 状態を明示的に受け渡し
const classifyResult = await Task(classifyFiles, {
  filePath: 'src/utils/formatters.ts'
});

const testWriterResult = await Task(testWriter, {
  testPattern: classifyResult.testPattern,  // classify-filesの結果を使用
  testFilePath: classifyResult.testFilePath,
  implFilePath: 'src/utils/formatters.ts'
});

const testRunnerResult = await Task(testRunner, {
  testFilePath: testWriterResult.testFilePath,  // test-writerの結果を使用
  expectation: 'RED_EXPECTED'
});
```

### フィードバックフックの活用

SubagentStop フックを信頼し、自動改善に任せます。

```markdown
## エージェント定義ファイル (.claude/agents/test-writer.md)

... (元の定義) ...

## 改善提案（過去のフィードバック）

### 2025-11-28
- 浮動小数点比較には toBeCloseTo() を使用する
- テストファイルには実装コードを含めない
- 境界値テストを必ず含める

### 2025-11-27
- AAA パターンを厳守する
- テストケース名を明確にする
```

**注意**:
- 手動編集は構造的な問題のみ
- 改善提案は自動で追記される
- 削除せずに履歴として残す

---

## パフォーマンス最適化

### 最適化は測定してから

パフォーマンスが問題になってから最適化します。

```typescript
// ❌ 早すぎる最適化
const priceCache = new Map<string, number>();

export function calculatePrice(items: Item[]): number {
  const cacheKey = items.map(i => i.id).join(',');
  if (priceCache.has(cacheKey)) {
    return priceCache.get(cacheKey)!;
  }
  const price = /* 計算 */;
  priceCache.set(cacheKey, price);
  return price;
}

// ✅ まずはシンプルに実装
export function calculatePrice(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}
```

**最適化のタイミング**:
1. パフォーマンス問題を測定で確認
2. ボトルネックを特定
3. 最適化を実装
4. 効果を測定

### メモ化が有効なケース

```typescript
// ✅ 計算コストが高い場合のみメモ化
const factorialCache = new Map<number, number>();

export function factorial(n: number): number {
  if (factorialCache.has(n)) {
    return factorialCache.get(n)!;
  }

  // 再帰的な計算（コストが高い）
  const result = n <= 1 ? 1 : n * factorial(n - 1);

  factorialCache.set(n, result);
  return result;
}
```

**メモ化が有効な条件**:
- 計算コストが高い（再帰、複雑なループなど）
- 同じ入力で何度も呼ばれる
- メモリコストが許容範囲

---

## メンテナンス

### TODO.md の定期的な更新

進捗に応じて TODO.md を更新します。

```markdown
## Phase 1: 基盤実装

### 1.1 ユーティリティ関数 (`src/utils/formatters.ts`)
- [x] `formatCurrency(amount)` 関数 (2025-11-28 完了)
- [x] `parseCurrency(text)` 関数 (2025-11-28 完了)
...

### 1.2 バリデーション (`src/utils/validators.ts`)
- [x] `validateEmail(email)` 関数 (2025-11-28 完了)
- [ ] `validatePassword(password)` 関数 (次のタスク)
- [ ] `validateAge(age)` 関数
```

### フィードバックレポートの定期確認

週1回、フィードバックレポートを確認します。

```bash
# 最新のレポートを確認
ls -lt .claude/reports/test-writer/ | head -3
cat .claude/reports/test-writer/evaluation_*.md
```

**確認項目**:
- 同じ問題が繰り返し発生していないか
- エージェント定義ファイルに改善が反映されているか
- 新しいパターンが見つかっていないか

### テストカバレッジの維持

カバレッジ100%を維持します。

```bash
# カバレッジレポートを生成
pnpm test -- --coverage

# カバレッジを確認
cat coverage/coverage-summary.json
```

**カバレッジ目標**:
- ユニット: 100%
- ストア: 100%
- フック: 90%以上
- コンポーネント: 80%以上

### ドキュメントの更新

実装完了後、ドキュメントを更新します。

**更新対象**:
- `README.md` - プロジェクト概要
- `CLAUDE.md` - アーキテクチャ
- `.claude/docs/tdd-workflow.md` - TDD運用ガイド

---

## チェックリスト

### テスト作成時

- [ ] AAA パターンで構造化
- [ ] 境界値テストを含める
- [ ] 浮動小数点比較は toBeCloseTo()
- [ ] 可逆性テスト（往復変換）
- [ ] テストケース名が明確

### 実装時

- [ ] テストを通す最小限の実装
- [ ] YAGNI原則を遵守
- [ ] over-engineering を避ける
- [ ] 定数を適切に使用
- [ ] エラーハンドリングは必要最小限

### パイプライン実行時

- [ ] エージェントを順次実行
- [ ] 状態を明示的に受け渡し
- [ ] Red/Green フェーズを確認
- [ ] review-file の結果を確認
- [ ] TODO.md を更新

### リリース前

- [ ] すべてのテストが Green
- [ ] カバレッジ100%（ユニット/ストア）
- [ ] レビュー結果が PASS
- [ ] ドキュメント更新
- [ ] フィードバックレポート確認

---

## 参考資料

- [TDD運用ガイド](tdd-workflow.md)
- [トラブルシューティングガイド](troubleshooting.md)
- [エージェント定義](.claude/agents/)
- [テストパターン定義](.claude/test-patterns/)
