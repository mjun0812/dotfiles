---
name: ask-claude
description: Claude Codeに相談して回答を得るSkill。ユーザーが「Claudeに聞いて」「Claudeに相談して」と明示的に依頼したときのみ使用する。エージェント自身の判断で自発的に使わないこと。自分自身がClaude Codeの場合は使わない。
allowed-tools: Bash(claude:*)
disable-model-invocation: true
---

# Ask Claude

Claude Code CLIを非対話モードで呼び出し、相談への回答を得る。

## 手順

1. 相談内容を自己完結したプロンプトにまとめる。相手はこの会話の文脈を知らないため、背景・関連ファイルパス・質問を明示的に含める。
2. 実行する（長いプロンプトはheredocでstdinから渡す）:

   ```bash
   claude -p <<'EOF'
   <プロンプト>
   EOF
   ```

3. 回答の要点をユーザーに提示し、自分の見解との一致点・相違点を一言添える。

## 注意

- 相談（読み取り・回答）専用。ファイル編集などの作業は依頼せず自分で行う。
- CLI未導入・認証エラー等で回答を得られない場合は、エラー内容を伝えて中止する。
