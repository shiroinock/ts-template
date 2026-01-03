# テストパターン: 統合テスト

## 対象

- `src/__tests__/integration/` に配置
- 複数モジュールの連携、エンドツーエンドのシナリオ
- データフロー、全体フローなど

## 特徴

- **テスト容易性**: 低〜中（モック最小限、実際の連携を検証）
- **TDD方式**: テストレイター（実装完了後に統合を確認）
- **配置**: separated（`src/__tests__/integration/` に分離）

## テストの構造

```typescript
import { describe, test, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { App } from '../../App';

describe('統合テスト: Todoアプリフロー', () => {
  test('Todo追加 → 完了 → 削除の一連のフローが動作する', async () => {
    const user = userEvent.setup();
    render(<App />);

    // Todo追加
    await user.type(screen.getByPlaceholderText(/新しいTodo/i), '買い物に行く');
    await user.click(screen.getByRole('button', { name: /追加/i }));

    // 追加されたTodoを確認
    expect(screen.getByText('買い物に行く')).toBeInTheDocument();

    // 完了マーク
    await user.click(screen.getByRole('checkbox', { name: /買い物に行く/i }));
    expect(screen.getByText('買い物に行く')).toHaveStyle({ textDecoration: 'line-through' });

    // 削除
    await user.click(screen.getByRole('button', { name: /削除/i }));
    expect(screen.queryByText('買い物に行く')).not.toBeInTheDocument();
  });
});
```

## カバーすべきシナリオ

1. **ユーザーシナリオ**: 実際の使用フロー全体
2. **モジュール連携**: ストア ↔ コンポーネント ↔ ユーティリティ
3. **状態遷移**: アプリ全体の状態管理
4. **エッジケース統合**: 複数のエッジケースが組み合わさった場合

## 具体例: data-flow.test.ts（データフロー統合テスト）

```typescript
import { describe, test, expect, beforeEach } from 'vitest';
import { formatDate, parseDate } from '../../utils/dateHelpers';
import { validateTodoInput } from '../../utils/validators';
import { useTodoStore } from '../../stores/todoStore';

describe('統合テスト: Todoデータフロー', () => {
  beforeEach(() => {
    useTodoStore.setState(useTodoStore.getInitialState());
  });

  describe('Todo追加フロー', () => {
    test('入力 → バリデーション → ストア保存 → フォーマット表示', () => {
      const store = useTodoStore.getState();

      // 1. ユーザー入力
      const input = '買い物に行く';
      const dueDate = new Date('2026-01-15');

      // 2. バリデーション
      const validation = validateTodoInput(input);
      expect(validation.isValid).toBe(true);

      // 3. ストアに保存
      store.addTodo({
        id: '1',
        text: input,
        completed: false,
        dueDate,
      });

      // 4. ストアから取得
      const todos = store.todos;
      expect(todos).toHaveLength(1);
      expect(todos[0].text).toBe('買い物に行く');

      // 5. 日付フォーマット
      const formattedDate = formatDate(todos[0].dueDate);
      expect(formattedDate).toBe('2026年1月15日');
    });
  });

  describe('フィルタリングとソート', () => {
    test('複数のTodoを追加してフィルタリングできる', () => {
      const store = useTodoStore.getState();

      // 複数のTodoを追加
      store.addTodo({ id: '1', text: 'タスクA', completed: false });
      store.addTodo({ id: '2', text: 'タスクB', completed: true });
      store.addTodo({ id: '3', text: 'タスクC', completed: false });

      // 未完了のみフィルタ
      const activeTodos = store.todos.filter(todo => !todo.completed);
      expect(activeTodos).toHaveLength(2);
      expect(activeTodos.map(t => t.text)).toEqual(['タスクA', 'タスクC']);
    });
  });

  describe('永続化統合', () => {
    test('ストア更新時にlocalStorageに保存される', () => {
      const store = useTodoStore.getState();

      // LocalStorage モック
      const setItemSpy = vi.spyOn(Storage.prototype, 'setItem');

      // Todo追加
      store.addTodo({ id: '1', text: 'テスト', completed: false });

      // LocalStorageに保存されることを確認
      expect(setItemSpy).toHaveBeenCalledWith(
        'todos',
        expect.stringContaining('テスト')
      );
    });
  });
});
```

## 具体例: user-scenario.test.ts（E2Eシナリオ）

```typescript
import { describe, test, expect } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { App } from '../../App';

describe('統合テスト: ユーザーシナリオ', () => {
  describe('基本的なTodo管理フロー', () => {
    test('Todo追加 → 編集 → 完了 → フィルタ表示', async () => {
      const user = userEvent.setup();
      render(<App />);

      // 1. 初期状態確認
      expect(screen.getByRole('heading', { name: /Todo/i })).toBeInTheDocument();
      expect(screen.queryByRole('listitem')).not.toBeInTheDocument();

      // 2. Todoを追加
      const input = screen.getByPlaceholderText(/新しいTodo/i);
      await user.type(input, '書類を提出する');
      await user.click(screen.getByRole('button', { name: /追加/i }));

      // Todoが表示されることを確認
      expect(screen.getByText('書類を提出する')).toBeInTheDocument();

      // 3. もう1つ追加
      await user.type(input, 'メールを返信する');
      await user.click(screen.getByRole('button', { name: /追加/i }));

      // 2つのTodoが表示される
      const todos = screen.getAllByRole('listitem');
      expect(todos).toHaveLength(2);

      // 4. 1つ目を完了にする
      const firstTodo = within(todos[0]);
      await user.click(firstTodo.getByRole('checkbox'));

      // 完了スタイルが適用される
      expect(firstTodo.getByText('書類を提出する')).toHaveStyle({
        textDecoration: 'line-through',
      });

      // 5. フィルタリング: 「未完了のみ」
      await user.click(screen.getByRole('button', { name: /未完了/i }));

      // 未完了のみ表示される
      expect(screen.getByText('メールを返信する')).toBeInTheDocument();
      expect(screen.queryByText('書類を提出する')).not.toBeInTheDocument();

      // 6. フィルタリング: 「すべて」
      await user.click(screen.getByRole('button', { name: /すべて/i }));

      // 両方表示される
      expect(screen.getByText('書類を提出する')).toBeInTheDocument();
      expect(screen.getByText('メールを返信する')).toBeInTheDocument();
    });
  });

  describe('一括操作フロー', () => {
    test('複数Todo追加 → 一括完了 → 一括削除', async () => {
      const user = userEvent.setup();
      render(<App />);

      const input = screen.getByPlaceholderText(/新しいTodo/i);

      // 3つのTodoを追加
      const tasks = ['タスク1', 'タスク2', 'タスク3'];
      for (const task of tasks) {
        await user.type(input, task);
        await user.click(screen.getByRole('button', { name: /追加/i }));
      }

      // すべて表示されることを確認
      expect(screen.getAllByRole('listitem')).toHaveLength(3);

      // 一括完了
      await user.click(screen.getByRole('button', { name: /すべて完了/i }));

      // すべてのチェックボックスがチェックされる
      const checkboxes = screen.getAllByRole('checkbox');
      checkboxes.forEach(checkbox => {
        expect(checkbox).toBeChecked();
      });

      // 一括削除
      await user.click(screen.getByRole('button', { name: /完了済みを削除/i }));

      // すべて削除される
      expect(screen.queryByRole('listitem')).not.toBeInTheDocument();
      expect(screen.getByText(/Todoがありません/i)).toBeInTheDocument();
    });
  });

  describe('エラーハンドリング', () => {
    test('空の入力でエラーメッセージが表示される', async () => {
      const user = userEvent.setup();
      render(<App />);

      // 何も入力せずに追加ボタンをクリック
      await user.click(screen.getByRole('button', { name: /追加/i }));

      // エラーメッセージが表示される
      expect(await screen.findByText(/入力してください/i)).toBeInTheDocument();
    });

    test('長すぎる入力は制限される', async () => {
      const user = userEvent.setup();
      render(<App />);

      const input = screen.getByPlaceholderText(/新しいTodo/i);
      const longText = 'a'.repeat(200);

      await user.type(input, longText);

      // 100文字に制限される
      expect(input).toHaveValue(longText.slice(0, 100));
    });
  });
});
```

## モックの最小化

統合テストではモックは最小限に：

```typescript
// ✅ 良い例: 外部依存のみモック
vi.mock('api/client', () => ({ ... }));

// ❌ 悪い例: 内部モジュールをモック（統合テストの意味がない）
vi.mock('../../utils/validators');
vi.mock('../../stores/todoStore');
```

## ディレクトリ構造

```
src/__tests__/
├── integration/
│   ├── data-flow.test.ts       # データフロー統合テスト
│   ├── state-management.test.ts # 状態管理統合テスト
│   └── user-scenarios.test.ts  # ユーザーシナリオE2E
└── e2e/
    └── full-app.test.ts        # 完全なアプリフロー
```

## ベストプラクティス

### 1. 実際のユーザー操作を再現

```typescript
// ✅ 良い例
await user.type(input, '買い物に行く');
await user.click(screen.getByRole('button', { name: /追加/i }));

// ❌ 悪い例
fireEvent.change(input, { target: { value: '買い物に行く' } }); // 直接値を設定
```

### 2. 状態遷移を確認

```typescript
expect(screen.queryByText('Todoがありません')).toBeInTheDocument();
// → 操作
expect(screen.queryByText('Todoがありません')).not.toBeInTheDocument();
expect(screen.getByRole('listitem')).toBeInTheDocument();
```

### 3. findBy で非同期を待つ

```typescript
// エラーメッセージの表示を待つ
const error = await screen.findByText(/入力してください/i);
expect(error).toBeInTheDocument();
```

### 4. モジュール間の連携を検証

```typescript
// バリデーション → ストア → UI の連携
const validation = validateInput(value);
if (validation.isValid) {
  store.add(value);
  expect(screen.getByText(value)).toBeInTheDocument();
}
```
