# テストパターン: 純粋関数のユニットテスト

## 対象

- `src/utils/` 配下の純粋関数
- 数値計算、データ変換、バリデーション、フォーマッターなど
- 副作用がなく、同じ入力に対して常に同じ出力を返す関数

## 特徴

- **テスト容易性**: 高（モック不要）
- **TDD方式**: テストファースト
- **配置**: colocated（`xxx.ts` と `xxx.test.ts` を同階層）

## テストの構造

```typescript
import { describe, test, expect } from 'vitest';
import { targetFunction } from './targetFunction';

describe('targetFunction', () => {
  describe('正常系', () => {
    test('基本的な入力で正しい出力を返す', () => {
      // Arrange
      const input = ...;
      const expected = ...;

      // Act
      const result = targetFunction(input);

      // Assert
      expect(result).toBe(expected);
    });
  });

  describe('境界値', () => {
    test('最小値で正しく動作する', () => { ... });
    test('最大値で正しく動作する', () => { ... });
    test('境界値ちょうどで正しく動作する', () => { ... });
  });

  describe('エッジケース', () => {
    test('ゼロで正しく動作する', () => { ... });
    test('負の値で正しく動作する', () => { ... });
  });

  describe('異常系', () => {
    test('無効な入力でエラーをスローする', () => {
      expect(() => targetFunction(invalidInput)).toThrow();
    });
  });
});
```

## カバーすべきシナリオ

1. **正常系**: 典型的な入力パターン
2. **境界値**: 範囲の最小値、最大値、境界ちょうど
3. **エッジケース**: ゼロ、負の値、空文字列、空配列など
4. **異常系**: 無効な入力、型違い、範囲外

## アサーションパターン

### 数値の等価性

```typescript
// 厳密な等価性
expect(result).toBe(60);

// 浮動小数点の比較（誤差許容）
expect(result).toBeCloseTo(103.5, 1); // 小数点1桁まで
```

### オブジェクトの等価性

```typescript
// 構造的等価性
expect(result).toEqual({ x: 100, y: 200 });

// 部分一致
expect(result).toMatchObject({ x: 100 }); // y は任意
```

### 配列の検証

```typescript
// 完全一致
expect(result).toEqual([1, 2, 3]);

// 要素を含む
expect(result).toContain(2);

// 長さ
expect(result).toHaveLength(3);
```

### エラーのテスト

```typescript
// エラーがスローされる
expect(() => targetFunction(invalid)).toThrow();

// 特定のエラーメッセージ
expect(() => targetFunction(invalid)).toThrow('Invalid input');

// エラーの型
expect(() => targetFunction(invalid)).toThrow(TypeError);
```

## 具体例: formatCurrency.ts

```typescript
import { describe, test, expect } from 'vitest';
import { formatCurrency, parseCurrency } from './formatCurrency';

describe('formatCurrency', () => {
  describe('正常系', () => {
    test('整数を通貨形式にフォーマットする', () => {
      expect(formatCurrency(1000)).toBe('¥1,000');
    });

    test('小数を通貨形式にフォーマットする', () => {
      expect(formatCurrency(1234.56)).toBe('¥1,234.56');
    });

    test('ゼロを正しくフォーマットする', () => {
      expect(formatCurrency(0)).toBe('¥0');
    });
  });

  describe('境界値', () => {
    test('大きな数値を正しくフォーマットする', () => {
      expect(formatCurrency(1000000)).toBe('¥1,000,000');
    });

    test('小さな小数を正しくフォーマットする', () => {
      expect(formatCurrency(0.01)).toBe('¥0.01');
    });
  });

  describe('エッジケース', () => {
    test('負の値を正しくフォーマットする', () => {
      expect(formatCurrency(-1000)).toBe('-¥1,000');
    });

    test('非常に小さい値を正しくフォーマットする', () => {
      expect(formatCurrency(0.001)).toBe('¥0.00');
    });
  });

  describe('異常系', () => {
    test('NaNでエラーをスローする', () => {
      expect(() => formatCurrency(NaN)).toThrow('Invalid number');
    });

    test('Infinityでエラーをスローする', () => {
      expect(() => formatCurrency(Infinity)).toThrow('Invalid number');
    });
  });
});

describe('parseCurrency', () => {
  describe('正常系', () => {
    test('通貨形式の文字列を数値にパースする', () => {
      expect(parseCurrency('¥1,000')).toBe(1000);
    });

    test('小数を含む通貨をパースする', () => {
      expect(parseCurrency('¥1,234.56')).toBe(1234.56);
    });
  });

  describe('境界値', () => {
    test('記号なしの数値文字列をパースする', () => {
      expect(parseCurrency('1000')).toBe(1000);
    });
  });

  describe('異常系', () => {
    test('無効な文字列でエラーをスローする', () => {
      expect(() => parseCurrency('invalid')).toThrow('Invalid currency format');
    });

    test('空文字列でエラーをスローする', () => {
      expect(() => parseCurrency('')).toThrow('Invalid currency format');
    });
  });

  describe('往復変換', () => {
    test('フォーマットとパースで元の値に戻る', () => {
      const original = 1234.56;
      const formatted = formatCurrency(original);
      const parsed = parseCurrency(formatted);

      expect(parsed).toBeCloseTo(original, 2);
    });
  });
});
```

## ベストプラクティス

### 1. テストケースの独立性

各テストは他のテストに依存しない：

```typescript
// ✅ 良い例
describe('calculator', () => {
  test('加算', () => {
    expect(add(1, 2)).toBe(3);
  });

  test('減算', () => {
    expect(subtract(5, 3)).toBe(2);
  });
});

// ❌ 悪い例
let result;
describe('calculator', () => {
  test('加算', () => {
    result = add(1, 2); // 外部変数に依存
  });

  test('結果が3', () => {
    expect(result).toBe(3); // 前のテストに依存
  });
});
```

### 2. 明確なテスト名

何をテストしているかが一目で分かる名前：

```typescript
// ✅ 良い例
test('1000を"¥1,000"にフォーマットする', () => { ... });

// ❌ 悪い例
test('test1', () => { ... });
test('動作する', () => { ... });
```

### 3. Arrange-Act-Assert の分離

コメントで明確に区切る：

```typescript
test('説明', () => {
  // Arrange
  const input = 100;
  const expected = 200;

  // Act
  const result = targetFunction(input);

  // Assert
  expect(result).toBe(expected);
});
```

## 注意事項

- **副作用を持たない**: テスト対象が純粋関数であることを確認
- **モックは不要**: 純粋関数は外部依存がないため、モック不要
- **数値精度**: 浮動小数点は `toBeCloseTo()` を使用
- **往復変換**: データ変換などは往復して元に戻ることを確認
