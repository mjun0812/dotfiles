#!/usr/bin/env zsh
set -eu

aliases_file=${1:-${0:A:h:h:h}/config/dot_config/zsh/aliases.zsh}
test_dir=$(mktemp -d)
trap 'command rm -rf "$test_dir"' EXIT

cat >"$test_dir/claude" <<'STUB'
#!/bin/sh
printf '%s\n' "${0##*/}" "${ANTHROPIC_BASE_URL-unset}" "${ANTHROPIC_AUTH_TOKEN-unset}" "${CLAUDE_CODE_ALWAYS_ENABLE_EFFORT-unset}" "${CLAUDE_CODE_MAX_CONTEXT_TOKENS-unset}" "${ANTHROPIC_DEFAULT_FABLE_MODEL-unset}" "${ANTHROPIC_DEFAULT_OPUS_MODEL-unset}" "${ANTHROPIC_DEFAULT_SONNET_MODEL-unset}" "${ANTHROPIC_DEFAULT_HAIKU_MODEL-unset}"
printf 'arg=<%s>\n' "$@"
exit "${WRAPPER_TEST_EXIT_CODE:-0}"
STUB
command chmod +x "$test_dir/claude"
command cp "$test_dir/claude" "$test_dir/codex"
command cp "$test_dir/claude" "$test_dir/agy"
export PATH="$test_dir:$PATH"
export CLIPROXY_API_KEY=wrapper-test-token
unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_ALWAYS_ENABLE_EFFORT CLAUDE_CODE_MAX_CONTEXT_TOKENS
unset ANTHROPIC_DEFAULT_FABLE_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL

# Define hostile aliases before parsing wrappers and functions after parsing.
alias codex='false alias-was-used'
alias agy='false alias-was-used'
source "$aliases_file"
function claude codex agy { return 91; }

claudex 'two words' '' '--flag=value' >"$test_dir/result"
result=$(<"$test_dir/result")
[[ $result == *$'claude\nhttp://127.0.0.1:8317\nwrapper-test-token\n1\n900000\ngpt-5.6-sol\ngpt-5.6-sol\ngpt-5.6-luna\ngpt-5.6-luna\n'* ]]
[[ $result == *$'arg=<two words>\narg=<>\narg=<--flag=value>' ]]
[[ ${+ANTHROPIC_BASE_URL} == 0 && ${+ANTHROPIC_AUTH_TOKEN} == 0 ]]
for variable_name in CLAUDE_CODE_ALWAYS_ENABLE_EFFORT CLAUDE_CODE_MAX_CONTEXT_TOKENS ANTHROPIC_DEFAULT_FABLE_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL; do
    [[ ${(P)+variable_name} == 0 ]]
done

export ANTHROPIC_BASE_URL=original-url ANTHROPIC_AUTH_TOKEN=original-token
export WRAPPER_TEST_EXIT_CODE=23
wrapper_status=0
claudex >"$test_dir/result" || wrapper_status=$?
[[ $wrapper_status == 23 ]]
[[ $ANTHROPIC_BASE_URL == original-url && $ANTHROPIC_AUTH_TOKEN == original-token ]]
unset WRAPPER_TEST_EXIT_CODE

claude-headroom 'two words' '' >"$test_dir/result"
result=$(<"$test_dir/result")
[[ $result == *$'claude\nhttp://127.0.0.1:8787\noriginal-token\n'* ]]
[[ $result == *$'arg=<two words>\narg=<>' ]]
[[ $ANTHROPIC_BASE_URL == original-url && $ANTHROPIC_AUTH_TOKEN == original-token ]]
unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN
claude-headroom >"$test_dir/result"
[[ ${+ANTHROPIC_BASE_URL} == 0 ]]
export WRAPPER_TEST_EXIT_CODE=23
wrapper_status=0
claude-headroom >"$test_dir/result" || wrapper_status=$?
[[ $wrapper_status == 23 && ${+ANTHROPIC_BASE_URL} == 0 ]]
unset WRAPPER_TEST_EXIT_CODE

for wrapper_name in cc-commit cc-commit-ja codex-full codex-headroom codex-headroom-full codex-commit codex-commit-ja agy-commit agy-commit-ja gemini-commit gemini-commit-ja; do
    eval "$wrapper_name" >"$test_dir/result"
    result=$(<"$test_dir/result")
    [[ $result == claude$'\n'* || $result == codex$'\n'* || $result == agy$'\n'* ]]
done

print -r -- 'PASS: executable resolution, arguments, proxy environment, environment isolation, exit status, and all AI wrappers'
