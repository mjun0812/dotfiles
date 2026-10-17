---
name: mjun-start
description: >-
  開発作業の依頼を、軽微な修正・バグ修正・refactoring・性能改善・新規機能のどれかに振り分け、種類に合った重さの流れで進めるSkill。
  ユーザーが「これを直して」「この不具合を修正して」「ここを整理して」「遅いので速くして」「この機能を足して」のように作業を依頼したときや、
  mjun-specify・mjun-implementから前提に合わない依頼を渡されたときに使うこと。
  「specを作って」のようにspec作りを明示した依頼と、承認済みspecの実装の依頼は、mjun-specify・mjun-implementが直接受ける。調査や質問への回答だけの依頼には使わない。
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(git:*), Bash(gh:*), Bash(zsh:*), Bash(ls:*), Bash(cat:*), Bash(mkdir:*), Skill(mjun-specify), Skill(mjun-implement), Skill(git-commit), Skill(github-pr-create)
---

# mjun-start

作業の種類によって、重視すべき点が違う。軽微な修正では速さと既存を壊さないことが、バグ修正では原因の特定、再現、再発防止が大事になる。refactoringでは振る舞いを変えないこと、性能改善では計測で確かめること、新規機能では人間が決めるべきことを決めて設計とAcceptance Criteriaを整えることが要になる。どれも同じ重さの流れに通すと、軽い作業は遅くなり、種類に固有の確かめ方が抜ける。

このskillは作業の最初に呼び、依頼の種類を見極めて、合った流れへ渡す。

## 作業の種類

| 種類        | 当てはまる依頼                                                                                                            | 重視すること                                                              | 進め方                                                                                                                                         |
| ----------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 軽微        | 振る舞いを変えない、または変化が自明で人間の判断が要らない変更。局所的で、完了条件が自明 (typo、文言、設定値、小さな整理) | 速さ、既存を壊さないこと                                                  | このskillの中で直す ([references/minor.md](references/minor.md))                                                                               |
| バグ修正    | 既存の振る舞いが、文書・コード・テストで決まっている期待から外れている                                                    | 原因の特定、再現、再発防止                                                | briefを書き、mjun-implementのdoc modeへ渡す ([references/bugfix.md](references/bugfix.md))                                                     |
| refactoring | 振る舞いを変えずに構造を変える。1つのtaskに収まるもの                                                                     | 振る舞いを変えないこと                                                    | briefを書き、mjun-implementのdoc modeへ渡す ([references/refactoring.md](references/refactoring.md))                                           |
| 性能改善    | 計測できる遅さや重さを減らす                                                                                              | 計測で確かめること                                                        | 目標値と計測方法を決めて変更前の値を測り、briefを書いてmjun-implementのdoc modeへ渡す ([references/performance.md](references/performance.md)) |
| 新規機能    | 新しい振る舞いを足す、または期待する振る舞い自体を変える。1つのtaskに収まらない広範囲のrefactoringもここに入れる          | 人間が決めるべきことを決め、設計を整え、Acceptance Criteriaを網羅すること | mjun-specifyへ渡す。承認後にmjun-implementで実装する                                                                                           |

判断を誤りやすいのは次の4つである。

- 動作の誤りを直すものは、修正が1行でもバグ修正にする。再現テストを残すことが、バグ修正の品質を支えるからである
- 「正しい動作」が文書、コード、テストのどれでも決まっていない不具合は、バグではなく仕様の判断なので、新規機能にする
- refactoringが1つのtaskに収まるかは、[mjun-to-tasksの分解規則](../mjun-to-tasks/SKILL.md#分解規則) の大きさの基準で判断する
- 複数の種類を含む依頼は、分けられるなら分けて順に進める。分けられなければ重いほうの種類で扱う

## 進め方

1. 依頼を読む。Issue番号なら `gh issue view <N> --json number,state,title,body,labels,comments,url` で取得し、closedなら中止して報告する。`.mjun/specs/` に `Source: #N` を持つactiveなspecがあれば、そのspecの作業である。`approval: approved` ならmjun-implementへ、そうでなければmjun-specifyへ渡す
2. 種類を決める。判断に要る範囲だけコードを読み、調べれば分かることは人間に聞かない
3. 新規機能 (広範囲のrefactoringを含む) になるときと、種類の判断に迷うときだけ、理由を添えてAskUserQuestionで確認する。新規機能はspec作りと承認で人間の時間を使うので、入る前に確かめる価値がある。それ以外は、選んだ種類と理由を1行で伝えて進む
4. 新規機能以外は、配送方法をここで1回だけ聞く。軽微なら「PRを作る / commitまで」、それ以外はmjun-implementの `--pr` / `--no-pr` / `--merge` から選んでもらう。`gh repo view` が失敗する (GitHub remoteが無い) ならPRの選択肢を出さない。最初にまとめて聞けば、以降は止まらずに最後まで進められる。新規機能の配送方法は、spec承認後にmjun-implementが聞く
5. 種類ごとのreferenceを読んで進める
6. 結果を報告する。選んだ種類と理由、途中で種類を切り替えた場合はその経緯、成果 (PRのURLやcommit)、briefのパスを含める

## brief

バグ修正、refactoring、性能改善では、依頼から集めた事実をbriefに書き、mjun-implementへ渡す。briefは、implementerとreviewerが従う成功の定義になる。形式は [references/brief.md](references/brief.md) に従い、`.mjun/briefs/<slug>.md` に置く (slugはタイトルの英語kebab-case。既存のファイルと重なれば末尾に `-2` を付ける)。配送の後も残し、mjun-implementがRun Logを追記する。

mjun-implementは、Skill toolで `mjun-implement .mjun/briefs/<slug>.md <配送のflag>` の形で呼ぶ。

## 重い種類へ切り替える

作業中に、選んだ種類の前提が崩れたら、より重い種類へ自動で切り替え、切り替えたことと理由を1行で伝えて続ける。軽い種類のまま押し切ると、その流れでは確かめない誤りが残るからである。

- 軽微のつもりが、振る舞いの誤りを直していると分かった → バグ修正
- 軽微・refactoring・性能改善のつもりが、振る舞いを変える必要があると分かった → 新規機能
- バグの「正しい動作」が決まっていない、または変えるべきだと分かった → 新規機能
- refactoringが1つのtaskに収まらないと分かった → 新規機能 (mjun-specifyでtaskに分ける)
- mjun-implementが、contractと現実の矛盾 (debuggerの `RETURN_TO_SPEC`) やbriefの不足で止まった → 新規機能。briefと止まった理由を素材として渡す

新規機能へ切り替えるときは、手順3の確認をせずにmjun-specifyへ渡す。人間が決めるべき点は、specifyが聞く。
