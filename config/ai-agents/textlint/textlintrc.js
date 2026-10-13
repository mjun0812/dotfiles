// 手元で `textlint` を直接実行するときの設定。install.sh が ~/.textlintrc.js へsymlinkする。
// textlintは設定をカレントディレクトリから親へ探すため、ホーム配下で設定を持たないディレクトリでだけ使われる。
// ルールはagent用hookの2つの設定 (textlintrc.fix.json, textlintrc.report.json) をまとめたもの。
const fs = require("node:fs");
const path = require("node:path");

// symlink経由で読まれ __dirname がホームになるため、実体のディレクトリから相対パスを解決する
const dir = path.dirname(fs.realpathSync(__filename));
const rules = {
  ...require(path.join(dir, "textlintrc.fix.json")).rules,
  ...require(path.join(dir, "textlintrc.report.json")).rules,
};
// prhの辞書パスは設定ファイルのあるディレクトリ (ホーム) から解決されるため、絶対パスにする
rules.prh.rulePaths = rules.prh.rulePaths.map((p) => path.resolve(dir, p));

module.exports = { rules };
