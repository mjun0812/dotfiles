---
name: ask-gemini
description: Gemini (Antigravity CLI, agy) に相談して回答を得るSkill。ユーザーが「Geminiに聞いて」「agyに相談して」と明示的に依頼したときのみ使用する。エージェント自身の判断で自発的に使わないこと。自分自身がGemini (Antigravity) の場合は使わない。
allowed-tools: Bash(agy:*)
disable-model-invocation: true
---

# Ask Gemini (agy)

Antigravity CLI (`agy`) を非対話モードで呼び出し、相談への回答を得る。

## 手順

1. 相談内容を自己完結したプロンプトにまとめる。相手はこの会話の文脈を知らないため、背景・関連ファイルパス・質問を明示的に含める。
2. 実行する:

   ```bash
   agy --sandbox -p "<プロンプト>"
   ```

   - `--sandbox`: 相談専用のため、ターミナル操作を制限したsandboxで実行する

3. 回答の要点をユーザーに提示し、自分の見解との一致点・相違点を一言添える。

## 注意

- 相談（読み取り・回答）専用。ファイル編集などの作業は依頼せず自分で行う。
- CLI未導入・認証エラー等で回答を得られない場合は、エラー内容を伝えて中止する。
