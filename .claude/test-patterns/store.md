# テストパターン: Zustand ストアのテスト

## 対象

- `src/stores/` 配下の Zustand ストア
- グローバル状態管理、アクション、セレクター

## 特徴

- **テスト容易性**: 中（状態のリセットが必要）
- **TDD方式**: テストファースト
- **配置**: colocated（`xxxStore.ts` と `xxxStore.test.ts` を同階層）

## テストの構造

```typescript
import { describe, test, expect, beforeEach } from 'vitest';
import { useAppStore } from './appStore';

describe('useAppStore', () => {
  beforeEach(() => {
    // 各テスト前にストアをリセット
    useAppStore.setState(useAppStore.getInitialState());
  });

  describe('初期状態', () => {
    test('デフォルト値が正しく設定されている', () => {
      const state = useAppStore.getState();
      expect(state.theme).toBe('light');
      expect(state.isInitialized).toBe(false);
    });
  });

  describe('アクション', () => {
    test('setTheme でテーマを更新できる', () => { ... });
    test('initialize で初期化状態になる', () => { ... });
  });

  describe('セレクター', () => {
    test('計算済みの値が正しく取得できる', () => { ... });
  });
});
```

## カバーすべきシナリオ

1. **初期状態**: ストアのデフォルト値
2. **アクション実行**: 状態の更新
3. **状態遷移**: アプリケーション状態の遷移パターン
4. **セレクター**: 派生値の計算
5. **副作用**: ローカルストレージへの保存など

## 具体例: settingsStore.ts

```typescript
import { describe, test, expect, beforeEach, vi } from 'vitest';
import { useSettingsStore } from './settingsStore';

describe('useSettingsStore', () => {
  beforeEach(() => {
    // ストアをリセット
    useSettingsStore.setState(useSettingsStore.getInitialState());
  });

  describe('初期状態', () => {
    test('デフォルトテーマは light', () => {
      expect(useSettingsStore.getState().theme).toBe('light');
    });

    test('デフォルト言語は ja', () => {
      expect(useSettingsStore.getState().language).toBe('ja');
    });

    test('デフォルト設定が正しい', () => {
      const { preferences } = useSettingsStore.getState();
      expect(preferences.fontSize).toBe(14);
      expect(preferences.showNotifications).toBe(true);
      expect(preferences.autoSave).toBe(true);
    });
  });

  describe('setTheme', () => {
    test('テーマを変更できる', () => {
      // Arrange
      expect(useSettingsStore.getState().theme).toBe('light');

      // Act
      useSettingsStore.getState().setTheme('dark');

      // Assert
      expect(useSettingsStore.getState().theme).toBe('dark');
    });

    test('テーマ更新で新しいオブジェクトが生成される', () => {
      const before = useSettingsStore.getState();
      useSettingsStore.getState().setTheme('dark');
      const after = useSettingsStore.getState();

      expect(after).not.toBe(before); // 参照が異なる
    });
  });

  describe('updatePreferences', () => {
    test('部分的な設定更新が可能', () => {
      // Arrange
      const initialPrefs = useSettingsStore.getState().preferences;

      // Act
      useSettingsStore.getState().updatePreferences({ fontSize: 16 });

      // Assert
      const updatedPrefs = useSettingsStore.getState().preferences;
      expect(updatedPrefs.fontSize).toBe(16);
      expect(updatedPrefs.showNotifications).toBe(initialPrefs.showNotifications); // 他は変わらない
    });

    test('設定更新で新しいオブジェクトが生成される', () => {
      const before = useSettingsStore.getState().preferences;
      useSettingsStore.getState().updatePreferences({ fontSize: 18 });
      const after = useSettingsStore.getState().preferences;

      expect(after).not.toBe(before); // 参照が異なる
    });
  });

  describe('状態遷移', () => {
    test('toggleNotifications で通知設定を切り替える', () => {
      // Arrange
      expect(useSettingsStore.getState().preferences.showNotifications).toBe(true);

      // Act
      useSettingsStore.getState().toggleNotifications();

      // Assert
      expect(useSettingsStore.getState().preferences.showNotifications).toBe(false);
    });

    test('連続した切り替えで元に戻る', () => {
      // Arrange
      const initial = useSettingsStore.getState().preferences.showNotifications;

      // Act
      useSettingsStore.getState().toggleNotifications();
      useSettingsStore.getState().toggleNotifications();

      // Assert
      expect(useSettingsStore.getState().preferences.showNotifications).toBe(initial);
    });
  });

  describe('履歴管理', () => {
    test('設定変更履歴が記録される', () => {
      // Arrange
      expect(useSettingsStore.getState().changeHistory).toHaveLength(0);

      // Act
      useSettingsStore.getState().setTheme('dark');
      useSettingsStore.getState().updatePreferences({ fontSize: 16 });

      // Assert
      const history = useSettingsStore.getState().changeHistory;
      expect(history).toHaveLength(2);
      expect(history[0].type).toBe('theme');
      expect(history[1].type).toBe('preferences');
    });

    test('履歴がタイムスタンプを含む', () => {
      useSettingsStore.getState().setTheme('dark');

      const history = useSettingsStore.getState().changeHistory;
      expect(history[0].timestamp).toBeInstanceOf(Date);
    });
  });

  describe('リセット機能', () => {
    test('resetToDefaults で全設定がリセットされる', () => {
      // Arrange
      useSettingsStore.getState().setTheme('dark');
      useSettingsStore.getState().updatePreferences({ fontSize: 20 });

      // Act
      useSettingsStore.getState().resetToDefaults();

      // Assert
      const state = useSettingsStore.getState();
      expect(state.theme).toBe('light');
      expect(state.preferences.fontSize).toBe(14);
    });
  });
});
```

## ストアのリセット

各テスト前に必ずストアをリセット：

```typescript
beforeEach(() => {
  // 方法1: getInitialState() を使用
  useSettingsStore.setState(useSettingsStore.getInitialState());

  // 方法2: 直接デフォルト値を設定
  useSettingsStore.setState({
    theme: 'light',
    language: 'ja',
    preferences: {
      fontSize: 14,
      showNotifications: true,
      autoSave: true,
    },
    changeHistory: [],
  });
});
```

## ローカルストレージのモック

副作用がある場合はモック化：

```typescript
import { vi, beforeEach, afterEach } from 'vitest';

describe('useSettingsStore（永続化）', () => {
  beforeEach(() => {
    // localStorage をモック
    const localStorageMock = {
      getItem: vi.fn(),
      setItem: vi.fn(),
      clear: vi.fn(),
    };
    global.localStorage = localStorageMock as any;
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  test('設定変更時に localStorage に保存される', () => {
    // Act
    useSettingsStore.getState().setTheme('dark');

    // Assert
    expect(localStorage.setItem).toHaveBeenCalledWith(
      'appSettings',
      expect.stringContaining('"theme":"dark"')
    );
  });

  test('初期化時に localStorage から読み込まれる', () => {
    // Arrange
    const savedSettings = JSON.stringify({ theme: 'dark', language: 'en' });
    (localStorage.getItem as any).mockReturnValue(savedSettings);

    // Act
    useSettingsStore.getState().loadFromStorage();

    // Assert
    expect(localStorage.getItem).toHaveBeenCalledWith('appSettings');
    expect(useSettingsStore.getState().theme).toBe('dark');
  });
});
```

## ベストプラクティス

### 1. 状態のイミュータビリティ

Zustand は自動的に新しいオブジェクトを生成するが、確認する：

```typescript
test('状態更新で参照が変わる', () => {
  const before = useSettingsStore.getState().preferences;
  useSettingsStore.getState().updatePreferences({ fontSize: 20 });
  const after = useSettingsStore.getState().preferences;

  expect(after).not.toBe(before);
});
```

### 2. 状態遷移の網羅

すべての遷移パターンをテスト：

```typescript
describe('状態遷移', () => {
  test('初期状態 → テーマ変更', () => { ... });
  test('テーマ変更 → リセット', () => { ... });
  test('設定更新 → 保存', () => { ... });
});
```

### 3. 計算済みセレクターのテスト

セレクターがある場合はその結果をテスト：

```typescript
test('isDarkMode セレクターが正しく計算される', () => {
  useSettingsStore.setState({ theme: 'dark' });

  const isDark = useSettingsStore.getState().isDarkMode;
  expect(isDark).toBe(true);
});
```

### 4. 副作用の分離

localStorage などの副作用はモックでテスト：

```typescript
test('設定保存時のみ localStorage を呼び出す', () => {
  // Arrange
  const setItemSpy = vi.spyOn(localStorage, 'setItem');

  // Act
  useSettingsStore.getState().setTheme('dark');

  // Assert
  expect(setItemSpy).toHaveBeenCalledTimes(1);
});
```
