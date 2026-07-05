---
name: ask-claude
description: Claude Codeに相談して回答を得るSkill。ユーザーが「Claudeに聞いて」「Claudeに相談して」と明示的に依頼したときのみ使用する。エージェント自身の判断で自発的に使わないこと。自分自身がClaude Codeの場合は使わない。
allowed-tools: Bash(claude:*)
disable-model-invocation: true
---

# Ask Claude

Claude Code CLIを非対話モードで呼び出し、相談への回答を得る。

## モデル指定

Claude Codeに相談する際は、作業の大きさや複雑さに応じてモデルを指定する。
モデルの選択は、`--model <モデル名>` で行い、作業の重さ・複雑さに応じて以下のように使い分ける。

- `haiku`: 軽い修正・定型的な相談
- `sonnet`: 通常の作業・調査・レビュー
- `opus`: 重い作業・複雑な判断・大規模な調査・レビュー

迷った場合は`opus`を指定する。

## 手順

0. `which claude` で `claude` CLIの存在を確認し、見つからなければ直ちに中止してユーザーに伝える。
1. 相談内容を自己完結したプロンプトにまとめる。相手はこの会話の文脈を知らないため、背景・関連ファイルパス・質問を明示的に含める。
2. 実行する:

   ```bash
   claude --model "<モデル名>" -p \
   --tools "Read,Grep,Glob" \
   --disallowedTools "Edit,Write,Bash" \
   --permission-mode "dontAsk" \
   --no-session-persistence <<'EOF'
   <prompt>
   EOF
   ```

3. 回答の要点をユーザーに提示し、自分の見解との一致点・相違点を一言添える。

## 注意

- 読み取り専用。ファイル編集などの作業は依頼せず自分で行う。
- Claudeの回答は第二意見として扱い、最終判断は呼び出し元エージェントが行う。
- Claudeの回答をそのまま転送せず、要点・根拠・一致点・相違点を整理して提示する。
- CLI未導入・認証エラー・permission error等で回答を得られない場合は、エラー内容を伝えて中止する。
