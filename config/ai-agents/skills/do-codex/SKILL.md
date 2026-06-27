---
name: do-codex
description: Codexに作業を委譲して結果を得るSkill。ユーザーが「Codexにやらせて」「Codexに作業を任せて」と明示的に依頼したときのみ使用する。エージェント自身の判断で自発的に使わないこと。自分自身がCodexの場合は使わない。
allowed-tools: Bash(codex exec:*)
disable-model-invocation: true
---

# Do Codex

Codex CLIを非対話モードで呼び出し、編集を伴う作業を委譲する。

## モデル・Thinking Effort指定

Codex CLIに作業を依頼する際は、作業の大きさや複雑さに応じてモデルとthinking effortを指定する。
モデルは `--model <モデル名>`、thinking effortは `--config 'model_reasoning_effort="<effort>"'` で指定する。

- `gpt-5.4-mini` + `medium`: 軽い修正・定型的な作業
- `gpt-5.5` + `medium`: 軽めだが少し考えさせたい作業・短い実装
- `gpt-5.5` + `high`: 通常の作業・調査・実装・複雑な判断
- `gpt-5.5` + `xhigh`: 特に難しい判断・大規模な実装・深いリファクタ。モデルが対応している場合のみ

迷った場合は `gpt-5.5` + `medium` を指定する。
`xhigh` が失敗した場合は `high` に下げて再実行する。

## 手順

1. 依頼内容を自己完結したプロンプトにまとめる。相手はこの会話の文脈を知らないため、背景・関連ファイルパス・成功条件を明示的に含める。
2. 実行する:

   ```bash
   codex -m "<モデル名>" \
   --config 'model_reasoning_effort="<effort>"' \
   --cd "<target_directory>" \
   -s workspace-write \
   -a never \
   --search \
   exec - <<'EOF'
   <prompt>
   EOF
   ```

3. 実行結果と変更箇所をユーザーに提示する。

## 注意

- 編集権限あり。`-s workspace-write` でワーキングディレクトリ内の編集を許可する。
- `-a never` で非対話モード中に承認を求めずに実行する。
- 委譲後の差分は呼び出し元エージェントが確認し、必要なら追加修正する。
- CLI未導入・認証エラー・permission error等で実行できない場合は、エラー内容を伝えて中止する。
