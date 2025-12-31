#!/bin/bash

# JSON 入力を読み取り、コマンドとツール名を抽出
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command' 2>/dev/null || echo "")
tool_name=$(echo "$input" | jq -r '.tool_name' 2>/dev/null || echo "")

# Bash コマンドのみをチェック
if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

# settings.json から拒否パターンを読み取り（グローバル + プロジェクトローカル）
global_settings="$HOME/.claude/settings.json"
local_settings=".claude/settings.json"

# グローバル設定から拒否パターンを取得
global_patterns=""
if [ -f "$global_settings" ]; then
  global_patterns=$(jq -r '.permissions.deny[]? | select(startswith("Bash(")) | gsub("^Bash\\("; "") | gsub("\\)$"; "")' "$global_settings" 2>/dev/null)
fi

# プロジェクトローカル設定から拒否パターンを取得
local_patterns=""
if [ -f "$local_settings" ]; then
  local_patterns=$(jq -r '.permissions.deny[]? | select(startswith("Bash(")) | gsub("^Bash\\("; "") | gsub("\\)$"; "")' "$local_settings" 2>/dev/null)
fi

# 両方のパターンをマージ
deny_patterns=$(printf "%s\n%s" "$global_patterns" "$local_patterns" | sort -u)

# コマンドが拒否パターンにマッチするかチェックする関数
matches_deny_pattern() {
  local cmd="$1"
  local pattern="$2"

  # 先頭・末尾の空白を削除
  cmd="${cmd#"${cmd%%[![:space:]]*}"}"
  cmd="${cmd%"${cmd##*[![:space:]]}"}"

  # glob パターンマッチング（ワイルドカード対応）
  [[ "$cmd" == $pattern ]]
}

# まずコマンド全体をチェック
while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue

  if matches_deny_pattern "$command" "$pattern"; then
    echo "Error: コマンドが拒否されました: '$command' (パターン: '$pattern')" >&2
    exit 2
  fi
done <<<"$deny_patterns"

# コマンドを論理演算子で分割し、各部分もチェック
temp_command="${command//;/$'\n'}"
temp_command="${temp_command//&&/$'\n'}"
temp_command="${temp_command//\|\|/$'\n'}"

IFS=$'\n'
for cmd_part in $temp_command; do
  [ -z "$(echo "$cmd_part" | tr -d '[:space:]')" ] && continue

  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue

    if matches_deny_pattern "$cmd_part" "$pattern"; then
      echo "Error: コマンドが拒否されました: '$cmd_part' (パターン: '$pattern')" >&2
      exit 2
    fi
  done <<<"$deny_patterns"
done

# コマンドを許可
exit 0
