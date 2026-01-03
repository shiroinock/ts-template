# テストパターン: React カスタムフックのテスト

## 対象

- `src/hooks/` 配下のカスタムフック
- useTimer, useDebounce, useKeyboardInput など

## 特徴

- **テスト容易性**: 中（React Testing Library の renderHook が必要）
- **TDD方式**: テストファースト
- **配置**: colocated（`useXxx.ts` と `useXxx.test.ts` を同階層）

## テストの構造

```typescript
import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useTimer } from './useTimer';

describe('useTimer', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  test('初期状態が正しい', () => {
    const { result } = renderHook(() => useTimer());
    expect(result.current.elapsedTime).toBe(0);
  });

  test('start() で時間が進む', () => {
    const { result } = renderHook(() => useTimer());

    act(() => {
      result.current.start();
    });

    act(() => {
      vi.advanceTimersByTime(3000);
    });

    expect(result.current.elapsedTime).toBe(3);
  });
});
```

## カバーすべきシナリオ

1. **初期状態**: フックの初期値
2. **状態更新**: setState などの動作
3. **副作用**: useEffect, タイマー, イベントリスナー
4. **クリーンアップ**: アンマウント時の処理
5. **依存配列**: 再レンダリング時の挙動

## 具体例: useTimer.ts

```typescript
import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useTimer } from './useTimer';

describe('useTimer', () => {
  beforeEach(() => {
    // タイマーをモック化
    vi.useFakeTimers();
  });

  afterEach(() => {
    // モックをリストア
    vi.restoreAllMocks();
  });

  describe('初期状態', () => {
    test('経過時間は0秒', () => {
      const { result } = renderHook(() => useTimer());
      expect(result.current.elapsedTime).toBe(0);
    });

    test('タイマーは停止状態', () => {
      const { result } = renderHook(() => useTimer());
      expect(result.current.isRunning).toBe(false);
    });
  });

  describe('start', () => {
    test('タイマーが開始される', () => {
      const { result } = renderHook(() => useTimer());

      act(() => {
        result.current.start();
      });

      expect(result.current.isRunning).toBe(true);
    });

    test('1秒ごとに経過時間がインクリメントされる', () => {
      const { result } = renderHook(() => useTimer());

      act(() => {
        result.current.start();
      });

      // 3秒進める
      act(() => {
        vi.advanceTimersByTime(3000);
      });

      expect(result.current.elapsedTime).toBe(3);
    });

    test('既に開始済みの場合は何もしない', () => {
      const { result } = renderHook(() => useTimer());

      act(() => {
        result.current.start();
        result.current.start(); // 2回呼ぶ
      });

      act(() => {
        vi.advanceTimersByTime(1000);
      });

      expect(result.current.elapsedTime).toBe(1); // 2倍になっていない
    });
  });

  describe('stop', () => {
    test('タイマーが停止される', () => {
      const { result } = renderHook(() => useTimer());

      act(() => {
        result.current.start();
        vi.advanceTimersByTime(2000);
        result.current.stop();
      });

      expect(result.current.isRunning).toBe(false);
      expect(result.current.elapsedTime).toBe(2);

      // さらに時間を進めても増えない
      act(() => {
        vi.advanceTimersByTime(3000);
      });

      expect(result.current.elapsedTime).toBe(2);
    });
  });

  describe('reset', () => {
    test('タイマーがリセットされる', () => {
      const { result } = renderHook(() => useTimer());

      act(() => {
        result.current.start();
        vi.advanceTimersByTime(5000);
        result.current.reset();
      });

      expect(result.current.elapsedTime).toBe(0);
      expect(result.current.isRunning).toBe(false);
    });
  });

  describe('クリーンアップ', () => {
    test('アンマウント時にタイマーがクリアされる', () => {
      const { result, unmount } = renderHook(() => useTimer());

      act(() => {
        result.current.start();
      });

      const clearIntervalSpy = vi.spyOn(global, 'clearInterval');

      // アンマウント
      unmount();

      expect(clearIntervalSpy).toHaveBeenCalled();
    });
  });
});
```

## renderHook の使い方

### 基本的な使い方

```typescript
const { result } = renderHook(() => useCustomHook());

// フックの戻り値にアクセス
expect(result.current.value).toBe(...);
```

### プロパティを渡す

```typescript
const { result } = renderHook(() => useCustomHook(initialValue));

// または
const { result } = renderHook(({ initialValue }) => useCustomHook(initialValue), {
  initialProps: { initialValue: 10 },
});
```

### プロパティを再レンダリングで変更

```typescript
const { result, rerender } = renderHook(
  ({ value }) => useCustomHook(value),
  { initialProps: { value: 10 } }
);

// プロパティを変更して再レンダリング
rerender({ value: 20 });

expect(result.current.value).toBe(20);
```

## act() の使用

状態更新やタイマー進行は `act()` で囲む：

```typescript
act(() => {
  result.current.increment();
});

act(() => {
  vi.advanceTimersByTime(1000);
});
```

## タイマーのテスト

### フェイクタイマーの使用

```typescript
beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.restoreAllMocks();
});

test('タイマーのテスト', () => {
  const { result } = renderHook(() => useTimer());

  act(() => {
    result.current.start();
  });

  // 時間を進める
  act(() => {
    vi.advanceTimersByTime(5000); // 5秒
  });

  expect(result.current.elapsedTime).toBe(5);
});
```

## イベントリスナーのテスト

### キーボードイベント

```typescript
import { describe, test, expect, vi } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useKeyboardInput } from './useKeyboardInput';

describe('useKeyboardInput', () => {
  test('Enterキーで onSubmit が呼ばれる', () => {
    const onSubmit = vi.fn();
    const { result } = renderHook(() => useKeyboardInput({ onSubmit }));

    act(() => {
      const event = new KeyboardEvent('keydown', { key: 'Enter' });
      window.dispatchEvent(event);
    });

    expect(onSubmit).toHaveBeenCalledOnce();
  });

  test('アンマウント時にイベントリスナーが削除される', () => {
    const removeEventListenerSpy = vi.spyOn(window, 'removeEventListener');
    const { unmount } = renderHook(() => useKeyboardInput({ onSubmit: vi.fn() }));

    unmount();

    expect(removeEventListenerSpy).toHaveBeenCalledWith('keydown', expect.any(Function));
  });
});
```

## 非同期処理のテスト

### データフェッチ

```typescript
import { waitFor } from '@testing-library/react';

test('データを非同期でフェッチする', async () => {
  const { result } = renderHook(() => useFetchData());

  // 初期状態
  expect(result.current.loading).toBe(true);
  expect(result.current.data).toBeNull();

  // フェッチ完了まで待つ
  await waitFor(() => {
    expect(result.current.loading).toBe(false);
  });

  expect(result.current.data).toEqual({ ... });
});
```

## ベストプラクティス

### 1. act() で状態更新を囲む

```typescript
// ✅ 良い例
act(() => {
  result.current.increment();
});

// ❌ 悪い例
result.current.increment(); // 警告が出る
```

### 2. クリーンアップをテスト

```typescript
test('アンマウント時にクリーンアップされる', () => {
  const spy = vi.spyOn(global, 'clearInterval');
  const { unmount } = renderHook(() => useTimer());

  unmount();

  expect(spy).toHaveBeenCalled();
});
```

### 3. 依存配列の検証

```typescript
test('依存配列の値が変わると effect が再実行される', () => {
  const effectSpy = vi.fn();
  const { rerender } = renderHook(
    ({ value }) => useCustomHook(value, effectSpy),
    { initialProps: { value: 1 } }
  );

  expect(effectSpy).toHaveBeenCalledTimes(1);

  rerender({ value: 2 });

  expect(effectSpy).toHaveBeenCalledTimes(2);
});
```
