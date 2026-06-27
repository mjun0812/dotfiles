---
name: ask-codex
description: Codexに相談して回答を得るSkill。ユーザーが「Codexに聞いて」「Codexに相談して」と明示的に依頼したときのみ使用する。エージェント自身の判断で自発的に使わないこと。自分自身がCodexの場合は使わない。
allowed-tools: Bash(codex exec:*)
disable-model-invocation: true
---

# Ask Codex

Codex CLIを非対話モードで呼び出し、相談への回答を得る。

## モデル・Thinking Effort指定

Codex CLIに相談する際は、作業の大きさや複雑さに応じてモデルとthinking effortを指定する。
モデルは `--model <モデル名>`、thinking effortは `--config 'model_reasoning_effort="<effort>"'` で指定する。

- `gpt-5.4-mini` + `medium`: 軽い確認・定型的な相談・短いレビュー
- `gpt-5.5` + `medium`: 軽めだが少し考えさせたい相談・短い設計確認
- `gpt-5.5` + `high`: 通常の作業・調査・レビュー・複雑な判断
- `gpt-5.5` + `xhigh`: 特に難しい判断・大規模な調査・深いレビュー。モデルが対応している場合のみ

迷った場合は `gpt-5.5` + `medium` を指定する。
`xhigh` が失敗した場合は `high` に下げて再実行する。

## 手順

1. 相談内容を自己完結したプロンプトにまとめる。相手はこの会話の文脈を知らないため、背景・関連ファイルパス・質問を明示的に含める。
2. 実行する:

   ```bash
   codex -m "<モデル名>" \
   --config 'model_reasoning_effort="<effort>"' \
   --cd "<target_directory>" \
   -s read-only \
   -a never \
   --search \
   exec - <<'EOF'
   <prompt>
   EOF
   ```

3. 回答の要点をユーザーに提示し、自分の見解との一致点・相違点を一言添える。

## 注意

- 読み取り専用。ファイル編集などの作業は依頼せず自分で行う。
- Codexの回答は第二意見として扱い、最終判断は呼び出し元エージェントが行う。
- Codexの回答をそのまま転送せず、要点・根拠・一致点・相違点を整理して提示する。
- CLI未導入・認証エラー・permission error等で回答を得られない場合は、エラー内容を伝えて中止する。
