# TypeScript型安全性チェック

## 説明
TypeScriptの型安全性を確認し、`any`型の使用や型エラーを検出します。

## 適用条件
- すべての `.ts`, `.tsx` ファイル

## チェック項目
- [ ] `any` 型が使用されていないか
- [ ] 型アサーション（`as`）が適切に使われているか
- [ ] `null` / `undefined` の扱いが適切か
- [ ] 関数の戻り値型が明示されているか
- [ ] インターフェースと型定義が `src/types/` に集約されているか

## 重要度
high

## チェックコマンド
```bash
# TypeScriptコンパイルチェック
npx tsc --noEmit

# any型の検索
grep -r "any" src/ --include="*.ts" --include="*.tsx"
```
