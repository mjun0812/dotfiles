---
name: do-gemini
description: Gemini (Antigravity CLI, agy) に作業を委譲して結果を得るSkill。ユーザーが「Geminiにやらせて」「Geminiに作業を任せて」と明示的に依頼したときのみ使用する。エージェント自身の判断で自発的に使わないこと。自分自身がGemini (Antigravity) の場合は使わない。
allowed-tools: Bash(agy:*)
disable-model-invocation: true
---

# Do Gemini (agy)

Antigravity CLI (`agy`, Geminiモデル) を非対話モードで呼び出し、編集を伴う作業を委譲する。

## モデル指定

Geminiに作業を依頼する際は、作業の大きさや複雑さに応じてモデルを指定する。
モデルの選択は、`--model <モデル名>` で行い、作業の重さ・複雑さに応じて以下のように使い分ける。

- `Gemini 3.5 Flash (Low)`: 軽い修正・定型的な作業
- `Gemini 3.5 Flash (Medium)`: 通常の作業・調査・実装
- `Gemini 3.5 Flash (High)`: やや重い作業・詳しめの実装・設計を伴う作業

迷った場合は `Gemini 3.5 Flash (Medium)` を指定する。

## 手順

1. 依頼内容を自己完結したプロンプトにまとめる。相手はこの会話の文脈を知らないため、背景・関連ファイルパス・成功条件を明示的に含める。

2. 実行する:

```bash
agy --model "<モデル名>" \
   --print \
   --dangerously-skip-permissions \
   --print-timeout 10m <<'EOF'
<prompt>
EOF
```

3. 実行結果と変更箇所をユーザーに提示する。

## 注意

- 編集権限あり。`--dangerously-skip-permissions` でツール使用の承認プロンプトをスキップして編集を許可する。
- `--sandbox` は指定しない。ターミナル制限が編集タスクを妨げる可能性があるため。
- 委譲後の差分は呼び出し元エージェントが確認し、必要なら追加修正する。
- CLI未導入・認証エラー・permission error・timeout等で実行できない場合は、エラー内容を伝えて中止する。
