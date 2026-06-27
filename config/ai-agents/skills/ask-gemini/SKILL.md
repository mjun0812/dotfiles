---
name: ask-gemini
description: Gemini (Antigravity CLI, agy) に相談して回答を得るSkill。ユーザーが「Geminiに聞いて」「Geminiに相談して」と明示的に依頼したときのみ使用する。エージェント自身の判断で自発的に使わないこと。自分自身がGemini (Antigravity) の場合は使わない。
allowed-tools: Bash(agy:*)
disable-model-invocation: true
---

# Ask Gemini (agy)

Antigravity CLI (`agy`, Geminiモデル) を非対話モードで呼び出し、相談への回答を得る。

## モデル指定

Geminiに相談する際は、作業の大きさや複雑さに応じてモデルを指定する。
モデルの選択は、`--model <モデル名>` で行い、作業の重さ・複雑さに応じて以下のように使い分ける。

- `Gemini 3.5 Flash (Low)`: 軽い確認・定型的な相談・短いレビュー
- `Gemini 3.5 Flash (Medium)`: 通常の相談・調査・レビュー
- `Gemini 3.5 Flash (High)`: やや重い相談・詳しめのレビュー・設計確認

迷った場合は `Gemini 3.5 Flash (Medium)` を指定する。

## 手順

1. 相談内容を自己完結したプロンプトにまとめる。相手はこの会話の文脈を知らないため、背景・関連ファイルパス・質問を明示的に含める。

2. 実行する:

```bash
agy --model "<モデル名>" \
   --print \
   --sandbox \
   --print-timeout 10m <<'EOF'
<prompt>
EOF
```

3. 回答の要点をユーザーに提示し、自分の見解との一致点・相違点を一言添える。

## 注意

- 読み取り専用。ファイル編集などの作業は依頼せず自分で行う。
- Geminiの回答は第二意見として扱い、最終判断は呼び出し元エージェントが行う。
- Geminiの回答をそのまま転送せず、要点・根拠・一致点・相違点を整理して提示する。
- `--sandbox` を指定し、相談用途での安全性を高める。
- `--dangerously-skip-permissions` は使用しない。
- CLI未導入・認証エラー・permission error・timeout等で回答を得られない場合は、エラー内容を伝えて中止する。
