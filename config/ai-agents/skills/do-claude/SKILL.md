---
name: do-claude
description: Claude Codeに作業を委譲して結果を得るSkill。ユーザーが「Claudeにやらせて」「Claudeに作業を任せて」と明示的に依頼したときのみ使用する。エージェント自身の判断で自発的に使わないこと。自分自身がClaude Codeの場合は使わない。
allowed-tools: Bash(claude:*)
disable-model-invocation: true
---

# Do Claude

Claude Code CLIを非対話モードで呼び出し、編集を伴う作業を委譲する。

## モデル指定

Claude Codeに作業を依頼する際は、作業の大きさや複雑さに応じてモデルを指定する。
モデルの選択は、`--model <モデル名>` で行い、作業の重さ・複雑さに応じて以下のように使い分ける。

- `haiku`: 軽い修正・定型的な作業
- `sonnet`: 通常の作業・調査・実装
- `opus`: 重い作業・複雑な判断・大規模な実装

迷った場合は`opus`を指定する。

## 手順

1. 依頼内容を自己完結したプロンプトにまとめる。相手はこの会話の文脈を知らないため、背景・関連ファイルパス・成功条件を明示的に含める。
2. 実行する:

   ```bash
   claude --model "<モデル名>" -p \
   --permission-mode "bypassPermissions" \
   --add-dir "<target_directory>" \
   --no-session-persistence <<'EOF'
   <prompt>
   EOF
   ```

3. 実行結果と変更箇所をユーザーに提示する。

## 注意

- 編集権限あり。`--permission-mode bypassPermissions` ですべてのツール (Edit/Write/Bash等) を自動許可する。
- `--add-dir` で作業対象ディレクトリへのアクセスを明示的に許可する。
- 委譲後の差分は呼び出し元エージェントが確認し、必要なら追加修正する。
- CLI未導入・認証エラー・permission error等で実行できない場合は、エラー内容を伝えて中止する。
