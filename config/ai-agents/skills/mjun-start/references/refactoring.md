# refactoring

振る舞いを変えずに構造を変えることを重視する。振る舞いが変わっていないことは、変更の前後で同じ検査が同じく通ることで示す。

## 大きさ

ここで扱うのは、1つのtaskに収まる整理だけである。収まるかは、[mjun-to-tasksの分解規則](../../mjun-to-tasks/SKILL.md#分解規則) の大きさの基準 (1つのmoduleに収まる、変更ファイルが10を超えない見込み、など) で判断する。収まらない広範囲の整理は、taskに分けて承認を取るほうが安全なので、新規機能としてmjun-specifyへ渡す (SKILL.mdの手順3の確認を取る)。

## briefに集めること

- **目的**: 何を良くするのか (重複の解消、依存の向きの修正、読みやすさなど) を、変更後に観察できる形で書く。例: 「moduleAがmoduleBをimportしない」
- **変えない振る舞い**: 公開interface (関数の署名、CLIの引数と出力、APIの入出力、エラーの形)
- **範囲**: 触るmoduleと、触らないもの
- **完了条件**: 目的が観察できること、変更前から通っていた検査がすべて同じく通ること、公開interfaceが変わらないこと

## 実装で確かめられること

mjun-implementは、briefが `kind: refactor` のとき、implementerとreviewerに [refactoringの観点](../../mjun-implement/templates/kind-refactor.md) を読ませる。整理する箇所のテストが薄ければ、implementerは先に今の振る舞いを固定するテストを書いてから整理する。
