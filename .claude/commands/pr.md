# 現在のブランチでプルリクエストを作成

現在のブランチの変更内容を分析し、プルリクエストを作成してください。

## 手順

1. **現在の状態を確認**（並列実行）：
   - `git branch --show-current` で現在のブランチ名を取得
   - `git log origin/main..HEAD --oneline` でmainからのコミット一覧を取得
   - `git diff origin/main...HEAD --stat` で変更ファイルの統計を取得
   - `git status` で未コミットの変更がないか確認

2. **変更内容を分析**：
   - コミットメッセージを読み解く
   - 変更されたファイルの種類と目的を把握
   - 必要に応じて `git diff origin/main...HEAD` で詳細を確認

3. **PRタイトルとサマリーを生成**：
   - タイトル: 変更の要約（日本語、50文字以内）
   - サマリー: 箇条書きで主な変更点を列挙

4. **ユーザーに確認**を求める：
   - 提案するタイトル
   - 提案するサマリー
   - 変更の影響範囲

5. **承認されたらPRを作成**：
   ```bash
   git push -u origin <branch-name>
   gh pr create --title "タイトル" --body "$(cat <<'EOF'
   ## Summary
   - 変更点1
   - 変更点2

   ## Test plan
   - [ ] テスト項目1
   - [ ] テスト項目2

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```

## PRテンプレート

```markdown
## Summary
<1-3行の箇条書きで変更の概要>

## Test plan
<テスト方法や確認事項のチェックリスト>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## 注意事項

- mainブランチからのPR作成は警告を出す
- 未プッシュのコミットがある場合は先にプッシュ
- 未コミットの変更がある場合は警告を出す
- PRのURLを最後に表示する
