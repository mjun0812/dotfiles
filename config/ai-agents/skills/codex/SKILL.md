---
name: codex
description: >-
  Codex CLIを非対話モードで呼び出し、相談への回答または委譲した作業の結果を得るSkill。
  デフォルトはread-onlyの相談モードで、ユーザーが作業の実行を明示的に依頼したときだけ編集権限付きで実行する。
  ユーザーが「Codexに聞いて」「Codexに相談して」「Codexにやらせて」「Codexに任せて」と明示的に依頼したときのみ使用する。
  エージェント自身の判断で自発的に使わないこと。自分自身がCodexの場合は使わない。
allowed-tools: Bash(codex:*)
disable-model-invocation: true
---

# Codex

Codex CLIを非対話モードで呼び出し、相談または作業委譲を行う。

## モード判定

ユーザーの依頼の言い方でモードを決める。

- **相談モード (デフォルト)**: 「聞いて」「相談して」「レビューして」など、回答を求める依頼。read-onlyで実行する
- **委譲モード**: 「やらせて」「任せて」「作業させて」など、編集を伴う作業の実行を明示的に求める依頼。workspace-writeで実行する

判断に迷う場合は相談モード (read-only) を選ぶ。

## Arguments

- `--dry-run`: 委譲モードをread-onlyで実行する。ファイルは一切変更されず、変更方針・変更予定箇所の提案のみを得る

## モデル・Thinking Effort指定

作業の大きさや複雑さに応じてモデルとthinking effortを指定する。
モデルは `--model <モデル名>`、thinking effortは `--config 'model_reasoning_effort="<effort>"'` で指定する。
GPT-5.6 Family以外のモデルを指定しないこと。

- `gpt-5.6-luna` + `medium`: 軽い確認・定型的な相談・軽い修正
- `gpt-5.6-luna` + `xhigh`: 通常の作業・調査・レビュー・実装
- `gpt-5.6-terra` + `high`: 設計判断・曖昧な要件・複雑な調査・大きめの実装・難しいデバッグ
- `gpt-5.6-sol` + `xhigh`: Terraよりさらに慎重な検討が必要な、特に難しい判断・大規模な実装・深いレビュー

迷った場合は `gpt-5.6-luna` + `xhigh` を指定する。
`xhigh` が失敗した場合は `high` に下げて再実行する。

## 手順

0. `which codex` で `codex` CLIの存在を確認し、見つからなければ直ちに中止してユーザーに伝える。
1. 内容を自己完結したプロンプトにまとめる。相手はこの会話の文脈を知らないため、背景・関連ファイルパスに加え、相談モードでは質問を、委譲モードでは成功条件を明示的に含める。
2. 実行する:

   ```bash
   codex -m "<モデル名>" \
   --config 'model_reasoning_effort="<effort>"' \
   --cd "<target_directory>" \
   -s <sandbox> \
   -a never \
   --search \
   exec - <<'EOF'
   <prompt>
   EOF
   ```

   `<sandbox>` はモードで決める:
   - 相談モード: `read-only`
   - 委譲モード: `workspace-write` (`--dry-run` 指定時は `read-only`)

3. 結果を提示する:
   - 相談モード: 回答の要点をユーザーに提示し、自分の見解との一致点・相違点を一言添える
   - 委譲モード: 実行結果と変更箇所を提示する。`--dry-run` 指定時は変更方針の提案のみを提示する

## 注意

- 相談モードは読み取り専用。回答は第二意見として扱い、最終判断は呼び出し元エージェントが行う。回答をそのまま転送せず、要点・根拠・一致点・相違点を整理して提示する
- 委譲モードは `-a never` で非対話モード中に承認を求めずに実行する。委譲後の差分は呼び出し元エージェントが確認し、必要なら追加修正する
- CLI未導入・認証エラー・permission error等で実行できない場合は、エラー内容を伝えて中止する
