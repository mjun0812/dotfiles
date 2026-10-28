// 手元で `textlint` を直接実行するときの設定。`mise dot apply` が conf.d/dotfiles.toml の宣言に従って ~/.textlintrc.js へsymlinkする。
// textlintは設定をカレントディレクトリから親へ探すため、ホーム配下で設定を持たないディレクトリから実行したときだけ使われる。
// `--config` には渡せない。拡張子付きのパスを渡すと、textlintの設定読み込み (rc-config-loader) がJSをYAMLとして読み、ルールが0件になる。
// ルールはagent用hookの2つの設定 (textlintrc.fix.json, textlintrc.report.json) をまとめたもの。
const fs = require("node:fs");
const path = require("node:path");

// symlink経由で読まれ __dirname がホームになるため、実体のディレクトリから相対パスを解決する
const dir = path.dirname(fs.realpathSync(__filename));
const report = require(path.join(dir, "textlintrc.report.json"));
const rules = {
  ...require(path.join(dir, "textlintrc.fix.json")).rules,
  ...report.rules,
};
// prhの辞書パスは設定ファイルのあるディレクトリ (ホーム) から解決されるため、絶対パスにする
rules.prh.rulePaths = rules.prh.rulePaths.map((p) => path.resolve(dir, p));

module.exports = { plugins: report.plugins, rules };
