---
name: claude
description: >-
  Claude Code CLIを非対話モードで呼び出し、相談への回答または委譲した作業の結果を得るSkill。
  デフォルトはread-onlyの相談モードで、ユーザーが作業の実行を明示的に依頼したときだけ編集権限付きで実行する。
  ユーザーが「Claudeに聞いて」「Claudeに相談して」「Claudeにやらせて」「Claudeに任せて」と明示的に依頼したときのみ使用する。
  エージェント自身の判断で自発的に使わないこと。自分自身がClaude Codeの場合は使わない。
allowed-tools: Bash(claude:*)
disable-model-invocation: true
---

# Claude

Claude Code CLIを非対話モードで呼び出し、相談または作業委譲を行う。

## モード判定

ユーザーの依頼の言い方でモードを決める。

- **相談モード (デフォルト)**: 「聞いて」「相談して」「レビューして」など、回答を求める依頼。read-onlyで実行する
- **委譲モード**: 「やらせて」「任せて」「作業させて」など、編集を伴う作業の実行を明示的に求める依頼。編集権限付きで実行する

判断に迷う場合は相談モード (read-only) を選ぶ。

## Arguments

- `--dry-run`: 委譲モードを編集権限なしで実行する。ファイルは一切変更されず、変更方針・変更予定箇所の提案のみを得る

## モデル指定

作業の大きさや複雑さに応じて `--model <モデル名>` でモデルを指定する。

- `haiku`: 軽い修正・定型的な相談・作業
- `sonnet`: 通常の作業・調査・レビュー・実装
- `opus`: 重い作業・複雑な判断・大規模な調査・実装・レビュー

迷った場合は`opus`を指定する。

## 手順

0. `which claude` で `claude` CLIの存在を確認し、見つからなければ直ちに中止してユーザーに伝える。
1. 内容を自己完結したプロンプトにまとめる。相手はこの会話の文脈を知らないため、背景・関連ファイルパスに加え、相談モードでは質問を、委譲モードでは成功条件を明示的に含める。
2. モードに応じて実行する:

   相談モード (`--dry-run` 指定時の委譲モードもこの形式):

   ```bash
   claude --model "<モデル名>" -p \
   --tools "Read,Grep,Glob" \
   --disallowedTools "Edit,Write,Bash" \
   --permission-mode "dontAsk" \
   --add-dir "<target_directory>" \
   --no-session-persistence <<'EOF'
   <prompt>
   EOF
   ```

   委譲モード:

   ```bash
   claude --model "<モデル名>" -p \
   --permission-mode "bypassPermissions" \
   --add-dir "<target_directory>" \
   --no-session-persistence <<'EOF'
   <prompt>
   EOF
   ```

3. 結果を提示する:
   - 相談モード: 回答の要点をユーザーに提示し、自分の見解との一致点・相違点を一言添える
   - 委譲モード: 実行結果と変更箇所を提示する。`--dry-run` 指定時は変更方針の提案のみを提示する

## 注意

- 相談モードは読み取り専用。回答は第二意見として扱い、最終判断は呼び出し元エージェントが行う。回答をそのまま転送せず、要点・根拠・一致点・相違点を整理して提示する
- 委譲モードは `--permission-mode bypassPermissions` ですべてのツール (Edit/Write/Bash等) を自動許可する。`--add-dir` で作業対象ディレクトリへのアクセスを明示的に許可する。委譲後の差分は呼び出し元エージェントが確認し、必要なら追加修正する
- CLI未導入・認証エラー・permission error等で実行できない場合は、エラー内容を伝えて中止する
