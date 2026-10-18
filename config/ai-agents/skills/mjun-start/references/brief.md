# briefの形式

briefは、バグ修正・refactoring・性能改善で、mjun-startが集めた事実をmjun-implementへ渡すファイルである。mjun-implementはdoc modeでこれを読み、`完了条件` を成功の定義、`範囲` をBoundaryとして扱う。implementerとreviewerはbriefに書かれたことだけを頼りに作業するので、依頼者しか知らない事実を書き漏らさない。

```markdown
---
kind: bug | refactor | perf
status: active
---

# <作業を表す短いタイトル>

Source: #<Issue番号> (Issueから始めた場合だけ)

## 背景

<依頼の要約と、調べて分かった関係するコード>

<種類ごとの節>

## 完了条件

- [ ] <観察できる結果。1件を1つの確認コマンドで判定できる形>

## 範囲

- 触る: <moduleやdirectory>
- 触らない: <変更してはいけない領域>

## Run Log
```

種類ごとの節は次のとおり。

- `kind: bug`: `## 再現手順`、`## 期待する動作` (期待を定めている文書・コード・テストの `file:line` か引用を添える)、`## 実際の動作`、`## 原因の見当`
- `kind: refactor`: `## 目的` (変更後に観察できる形)、`## 変えない振る舞い`
- `kind: perf`: `## 計測方法` (コマンドと条件)、`## 変更前の値`、`## 目標値`、`## 変えない振る舞い`

`status` は、作業を終えた時点でmjun-implementが `done` にする。`## Run Log` には、mjun-implementがgroupごとの結果を追記する。briefは作業を終えた後も残し、同じ作業の再実行と、種類ごとの結果の振り返りに使う。
