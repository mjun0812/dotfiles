#!/usr/bin/env zsh
# request_user_inputが時間切れになったときに、同じ質問を出し直させるCodexのPostToolUse hook (request_user_input)。
# 通常のmodeの質問は120秒で自動的に打ち切られ、結果は {"answers":{}} になる。
# Codex本体は「回答が無ければ自分の判断で続ける」とモデルへ指示しているため、空の回答を渡さずに出し直しを指示する。
# ユーザーが送信した回答には質問ごとのキーが必ず入るので、answersが空になるのは時間切れだけである。
# 出し直しのたびにモデルが1往復するため、同じターンで続けてmax_reasks回出し直しても回答が無ければ、
# 文章での質問に切り替えさせる。

set -u

max_reasks=5

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
count_file=${TMPDIR:-/tmp}/codex-user-input-timeout-$(jq -r '.turn_id' <<<"$input")

# tool_responseはJSON文字列で届く場合もあるので、objectに揃える
if ! jq -e '.tool_response | if type == "string" then fromjson else . end | .answers == {}' <<<"$input" >/dev/null 2>&1; then
    rm -f "$count_file"
    exit 0
fi

timeouts=$(($(cat "$count_file" 2>/dev/null || echo 0) + 1))
if ((timeouts > max_reasks)); then
    rm -f "$count_file"
    echo 'request_user_inputが続けて時間切れになった。ユーザーは離席している。推測で先へ進まず、質問と選択肢を最終メッセージに書いてターンを終え、返信を待つこと。' >&2
    exit 2
fi

echo "$timeouts" >"$count_file"
echo 'request_user_inputは回答が無いまま時間切れになった。これはユーザーの回答ではない。推測で先へ進まず、同じ質問をrequest_user_inputで出し直し、回答を待つこと。' >&2
exit 2
