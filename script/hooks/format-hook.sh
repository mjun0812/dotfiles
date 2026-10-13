#!/usr/bin/env zsh
# agentが編集したファイルに、formatterと自動修正だけをかけるPostToolUse hook。
# 自動で直らないlintエラーはagentへ返さない。
# 編集されたファイルは edited-files.sh で取り出す。
#
# formatterが無い・失敗した場合もagentを止めないよう、常にexit 0で終える。

set -u

DOTPATH=${0:A:h:h:h}

command -v jq >/dev/null 2>&1 || exit 0

files=("${(@f)$("$DOTPATH/script/hooks/edited-files.sh")}")

# 以降のformatterの出力はagentに見せない
exec >/dev/null 2>&1

for file in "${files[@]}"; do
    [[ -n $file ]] || continue

    # styluaは作業ディレクトリから上に向かって設定を探すため、ファイルの場所へ移動する
    cd "${file%/*}" || continue

    case $file in
    *.py)
        # F401 (未使用import) は直さない。agentはimportを先に書き、使う側を後の編集で書くことがあるため
        # --force-exclude: 明示したパスにもプロジェクトのexclude設定を適用する
        ruff check --fix --unfixable F401 --force-exclude --quiet "$file"
        ruff format --force-exclude --quiet "$file"
        ;;
    *.md)
        # 全角括弧と、英数字と日本語の間のスペースを直す (ルールは config/ai-agents/textlint)
        "$DOTPATH/script/tools/textlint.sh" fix --fix "$file"
        oxfmt "$file"
        ;;
    *.sh | *.bash | *.zsh)
        shfmt -w "$file"
        ;;
    *.lua)
        stylua -s "$file"
        ;;
    esac
done

exit 0
