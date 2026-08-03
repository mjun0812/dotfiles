---
name: steering
description: >-
  `.mjun/steering/` をプロジェクトの永続メモリ (project memory) として作成・維持するSkill。
  core 3ファイル (product.md, tech.md, structure.md) が欠けていればコードベースを分析して生成し (Bootstrap)、
  揃っていればsteeringとコードのdriftを検出して追記更新する (Sync)。
  ユーザーが「steeringを作って」「steeringを更新して」「プロジェクトメモリを整備して」のように依頼したら使うこと。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(find:*), Bash(rg:*), Bash(git:*), Bash(cat:*), Bash(head:*), Bash(tail:*), Bash(wc:*), Bash(tree:*), Bash(mkdir:*)
---

# steering

## 目的

`.mjun/steering/` をプロジェクトの永続メモリとして維持する。

- **Bootstrap**: 初回にコードベースを分析してcore steeringを生成する
- **Sync**: steeringとコードベースの整合を保つ
- **Preserve**: ユーザーのカスタマイズは神聖。更新は追記で行い、置換しない

成功条件:

- steeringが網羅的なリストではなく、パターンと原則を記録している
- steeringとコードのdriftが検出・報告されている
- `.mjun/steering/*.md` はcore・customを問わずすべて等しく扱われている

## モード判定

`.mjun/steering/` の状態を確認してモードを自動判別する。

- **Bootstrap Mode**: ディレクトリが空、またはcoreファイル (product.md, tech.md, structure.md) のいずれかが欠けている
- **Sync Mode**: coreファイルが3つとも存在する

会話の中でsteeringの内容が既に得られている場合、重複するファイル読み込みは省略してよい。

## Bootstrap Flow

1. [`references/`](references) のテンプレートを読み込む
   - [`references/product_template.md`](references/product_template.md)
   - [`references/tech_template.md`](references/tech_template.md)
   - [`references/structure_template.md`](references/structure_template.md)
2. コードベースを分析する。以下の3観点は独立しているため、並列に調査する
   - **Product分析**: README、package.json等のマニフェスト、ドキュメントから、目的・価値・core capabilities を読み取る
   - **Tech分析**: 設定ファイル、依存関係、frameworkから、技術パターンと技術的決定を読み取る
   - **Structure分析**: ディレクトリツリー、命名規則、importパターンから、構成方針を読み取る
3. パターンを抽出する (リストではなく)
   - Product: 目的、価値、core capabilities
   - Tech: framework、決定事項、規約
   - Structure: 構成、命名、import
4. テンプレートに従って `.mjun/steering/` にsteeringファイルを生成する
5. [`references/steering_principles.md`](references/steering_principles.md) の原則に沿っているか確認する
6. サマリを提示してレビューを求める

**Focus**: 判断を導くパターンを書く。ファイルや依存の一覧 (カタログ) を書かない。

## Sync Flow

1. 既存の `.mjun/steering/*.md` をすべて読み込む
2. コードベースの変更を分析する
3. driftを検出する
   - **Steering → Code**: steeringに書かれているがコードに無い要素 → Warning
   - **Code → Steering**: コードに現れた新パターン → 更新候補
   - **Customファイル**: 内容がまだ有効か確認する
4. 更新を提案する (追記主義。ユーザーが書いた内容は保持する)
5. 報告する: 更新内容、警告、推奨事項

**Update Philosophy**: 置換せず追記する。ユーザーが書いたセクションは保持する。
詳細は [`references/steering_principles.md` の Preservation](references/steering_principles.md#preservation-when-updating) を参照。

## 粒度の原則

> "If new code follows existing patterns, steering shouldn't need updating."
> (新しいコードが既存パターンに従う限り、steeringの更新は不要であるべき)

パターンと原則を記録する。網羅的なリストを記録しない。
詳細は [`references/steering_principles.md` の Content Granularity](references/steering_principles.md#content-granularity) を参照。

- **Bad**: ディレクトリツリーの全ファイルを列挙する
- **Good**: 構成パターンを例付きで記述する

## 調査方針

ファイル探索・読み込み・パターン検索は必要になった時点で行う (JIT)。最初にすべてを読み込まない。

## 出力

チャットにはサマリのみを出す (ファイルは直接更新する)。

Bootstrap:

```text
Steering Created

## Generated:
- product.md: [概要]
- tech.md: [主要スタック]
- structure.md: [構成方針]

レビューし、Source of Truthとして承認してください。
```

Sync:

```text
Steering Updated

## Changes:
- tech.md: React 18 → 19
- structure.md: APIパターンを追記

## Code Drift:
- import規約に従っていないコンポーネントあり

## Recommendations:
- api-standards.md の追加を検討
```

## Examples

### Bootstrap

- **Input**: steeringが空のReact TypeScriptプロジェクト
- **Output**: "Feature-first"、"TypeScript strict"、"React 19" のようなパターンを記録した3ファイル

### Sync

- **Input**: steeringあり、新しい `/api` ディレクトリが追加されている
- **Output**: structure.mdを更新し、規約に従っていないファイルを警告し、api-standards.mdの追加を提案

## Safety & Fallback

- **Security**: API key、パスワード、secretは絶対に書かない ([`references/steering_principles.md` の Security](references/steering_principles.md#security) を参照)
- **Uncertainty**: steeringとコードのどちらが正か判断できない場合は、両方の状態を報告してユーザーに確認する
- **Preservation**: 迷ったら置換ではなく追記する

## Notes

- `.mjun/steering/*.md` はすべてプロジェクトメモリとして読み込まれる
- パターンを書き、カタログを書かない
- **Golden Rule**: 既存パターンに従う新コードのためにsteeringの更新が必要になってはいけない
- agent固有のツールディレクトリ (`.claude/`, `.codex/`, `.gemini/` など) や `.mjun/` 配下のメタ情報はsteeringに書かない
