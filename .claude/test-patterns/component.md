# テストパターン: React コンポーネントのテスト

## 対象

- `src/components/` 配下の UI コンポーネント
- Button, Input, Modal, Form など

## 特徴

- **テスト容易性**: 中〜高（React Testing Library使用）
- **TDD方式**: テストレイター（実装後にテスト）
- **配置**: colocated（`Component.tsx` と `Component.test.tsx` を同階層）

## テストの構造

```typescript
import { describe, test, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Component } from './Component';

describe('Component', () => {
  test('レンダリングされる', () => {
    render(<Component />);
    expect(screen.getByRole('...')).toBeInTheDocument();
  });

  test('ユーザー操作で状態が変わる', async () => {
    const user = userEvent.setup();
    render(<Component />);

    await user.click(screen.getByRole('button'));

    expect(screen.getByText('...')).toBeInTheDocument();
  });
});
```

## カバーすべきシナリオ

1. **レンダリング**: 初期表示が正しいか
2. **ユーザー操作**: クリック、入力、フォーカスなど
3. **条件付きレンダリング**: props や state に応じた表示切り替え
4. **イベントハンドラ**: コールバック関数の呼び出し
5. **アクセシビリティ**: role, aria属性の検証

## 具体例: Counter.tsx

```typescript
import { describe, test, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Counter } from './Counter';

describe('Counter', () => {
  describe('レンダリング', () => {
    test('初期値0が表示される', () => {
      render(<Counter />);
      expect(screen.getByText('Count: 0')).toBeInTheDocument();
    });

    test('カスタム初期値が表示される', () => {
      render(<Counter initialValue={10} />);
      expect(screen.getByText('Count: 10')).toBeInTheDocument();
    });

    test('増加ボタンが表示される', () => {
      render(<Counter />);
      expect(screen.getByRole('button', { name: /increment|\+/i })).toBeInTheDocument();
    });

    test('減少ボタンが表示される', () => {
      render(<Counter />);
      expect(screen.getByRole('button', { name: /decrement|\-/i })).toBeInTheDocument();
    });

    test('リセットボタンが表示される', () => {
      render(<Counter />);
      expect(screen.getByRole('button', { name: /reset/i })).toBeInTheDocument();
    });
  });

  describe('ユーザー操作', () => {
    test('増加ボタンをクリックするとカウントが増える', async () => {
      const user = userEvent.setup();
      render(<Counter />);

      await user.click(screen.getByRole('button', { name: /increment|\+/i }));
      expect(screen.getByText('Count: 1')).toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: /increment|\+/i }));
      expect(screen.getByText('Count: 2')).toBeInTheDocument();
    });

    test('減少ボタンをクリックするとカウントが減る', async () => {
      const user = userEvent.setup();
      render(<Counter initialValue={5} />);

      await user.click(screen.getByRole('button', { name: /decrement|\-/i }));
      expect(screen.getByText('Count: 4')).toBeInTheDocument();
    });

    test('リセットボタンで初期値に戻る', async () => {
      const user = userEvent.setup();
      render(<Counter initialValue={10} />);

      await user.click(screen.getByRole('button', { name: /increment|\+/i }));
      await user.click(screen.getByRole('button', { name: /increment|\+/i }));
      expect(screen.getByText('Count: 12')).toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: /reset/i }));
      expect(screen.getByText('Count: 10')).toBeInTheDocument();
    });

    test('onChange コールバックが呼ばれる', async () => {
      const user = userEvent.setup();
      const onChange = vi.fn();
      render(<Counter onChange={onChange} />);

      await user.click(screen.getByRole('button', { name: /increment|\+/i }));

      expect(onChange).toHaveBeenCalledWith(1);
    });
  });

  describe('制限値', () => {
    test('最大値を超えて増加できない', async () => {
      const user = userEvent.setup();
      render(<Counter initialValue={9} max={10} />);

      await user.click(screen.getByRole('button', { name: /increment|\+/i }));
      expect(screen.getByText('Count: 10')).toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: /increment|\+/i }));
      expect(screen.getByText('Count: 10')).toBeInTheDocument(); // 変わらない
    });

    test('最小値を下回って減少できない', async () => {
      const user = userEvent.setup();
      render(<Counter initialValue={1} min={0} />);

      await user.click(screen.getByRole('button', { name: /decrement|\-/i }));
      expect(screen.getByText('Count: 0')).toBeInTheDocument();

      await user.click(screen.getByRole('button', { name: /decrement|\-/i }));
      expect(screen.getByText('Count: 0')).toBeInTheDocument(); // 変わらない
    });

    test('最大値に達すると増加ボタンが無効になる', async () => {
      const user = userEvent.setup();
      render(<Counter initialValue={9} max={10} />);

      const incrementBtn = screen.getByRole('button', { name: /increment|\+/i });
      expect(incrementBtn).not.toBeDisabled();

      await user.click(incrementBtn);
      expect(incrementBtn).toBeDisabled();
    });
  });

  describe('無効状態', () => {
    test('disabled prop で全ボタンが無効になる', () => {
      render(<Counter disabled />);

      const buttons = screen.getAllByRole('button');
      buttons.forEach((button) => {
        expect(button).toBeDisabled();
      });
    });
  });
});
```

## クエリの優先順位

React Testing Library は「ユーザーがどう見えるか」を重視：

### 1. role（最優先）

```typescript
screen.getByRole('button', { name: '送信' });
screen.getByRole('textbox');
screen.getByRole('heading', { level: 1 });
```

### 2. label

```typescript
screen.getByLabelText('ユーザー名');
```

### 3. placeholder

```typescript
screen.getByPlaceholderText('メールアドレスを入力');
```

### 4. text

```typescript
screen.getByText('こんにちは');
```

### 5. testId（最終手段）

```typescript
screen.getByTestId('custom-element');
```

## userEvent の使用

ユーザー操作をシミュレート：

```typescript
const user = userEvent.setup();

// クリック
await user.click(element);

// ダブルクリック
await user.dblClick(element);

// テキスト入力
await user.type(element, 'Hello');

// キー入力
await user.keyboard('{Enter}');
await user.keyboard('{Escape}');

// フォーカス
await user.tab(); // 次の要素にフォーカス

// ホバー
await user.hover(element);
```

## 非同期処理の待機

### waitFor

```typescript
import { waitFor } from '@testing-library/react';

test('非同期で表示される', async () => {
  render(<AsyncComponent />);

  await waitFor(() => {
    expect(screen.getByText('読み込み完了')).toBeInTheDocument();
  });
});
```

### findBy（waitFor の糖衣構文）

```typescript
test('非同期で表示される', async () => {
  render(<AsyncComponent />);

  const element = await screen.findByText('読み込み完了');
  expect(element).toBeInTheDocument();
});
```

## モックとスタブ

### Props のモック

```typescript
const mockOnClick = vi.fn();
render(<Button onClick={mockOnClick} />);

await user.click(screen.getByRole('button'));

expect(mockOnClick).toHaveBeenCalledOnce();
```

### Context のモック

```typescript
import { AppContext } from './AppContext';

test('Context の値を使用する', () => {
  const mockContextValue = { user: { name: 'Alice' }, isLoggedIn: true };

  render(
    <AppContext.Provider value={mockContextValue}>
      <Component />
    </AppContext.Provider>
  );

  expect(screen.getByText('Alice')).toBeInTheDocument();
});
```

### Zustand Store のモック

```typescript
import { useAppStore } from './appStore';

vi.mock('./appStore', () => ({
  useAppStore: vi.fn(),
}));

test('ストアの値を使用する', () => {
  useAppStore.mockReturnValue({
    theme: 'dark',
    user: { name: 'Bob' },
    updateTheme: vi.fn(),
  });

  render(<Component />);

  expect(screen.getByText('Bob')).toBeInTheDocument();
});
```

## アクセシビリティのテスト

### role の検証

```typescript
test('適切な role が設定されている', () => {
  render(<Component />);

  expect(screen.getByRole('button')).toBeInTheDocument();
  expect(screen.getByRole('navigation')).toBeInTheDocument();
  expect(screen.getByRole('main')).toBeInTheDocument();
});
```

### aria属性の検証

```typescript
test('aria-label が設定されている', () => {
  render(<IconButton icon="close" />);

  const button = screen.getByRole('button', { name: /close|閉じる/i });
  expect(button).toBeInTheDocument();
});

test('aria-expanded が動的に変わる', async () => {
  const user = userEvent.setup();
  render(<Accordion />);

  const button = screen.getByRole('button');
  expect(button).toHaveAttribute('aria-expanded', 'false');

  await user.click(button);

  expect(button).toHaveAttribute('aria-expanded', 'true');
});
```

## スナップショットテスト（補助的）

```typescript
test('スナップショット', () => {
  const { container } = render(<Component />);
  expect(container).toMatchSnapshot();
});
```

注意: スナップショットは補助的に使用。メインは具体的なアサーション。

## ベストプラクティス

### 1. 実装詳細に依存しない

```typescript
// ✅ 良い例（ユーザー視点）
expect(screen.getByRole('button', { name: '送信' })).toBeInTheDocument();

// ❌ 悪い例（実装詳細）
expect(container.querySelector('.submit-button')).toBeInTheDocument();
```

### 2. 非同期は await を使う

```typescript
// ✅ 良い例
await user.click(button);

// ❌ 悪い例
user.click(button); // await なし
```

### 3. cleanup は自動

```typescript
// 不要（自動で実行される）
afterEach(() => {
  cleanup();
});
```
