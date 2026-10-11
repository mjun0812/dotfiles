#!/usr/bin/env bash
set -euo pipefail

NOTIFY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin" "$TEST_DIR/log"
export NOTIFY_TEST_LOG="$TEST_DIR/log"
export PATH="$TEST_DIR/bin:$PATH"
export TERM_PROGRAM=herdr
unset WEZTERM_PANE SSH_CONNECTION SSH_CLIENT SSH_TTY

assert() {
    if ! "$@"; then
        printf 'Assertion failed: %s\n' "$*" >&2
        exit 1
    fi
}

cat >"$TEST_DIR/bin/mock" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "${0##*/}" in
uname)
    printf 'Darwin\n'
    ;;
nohup)
    printf '%s\n' "$@" >"$NOTIFY_TEST_LOG/nohup"
    ;;
osascript | open | wezterm)
    printf '%s\n' "$@" >"$NOTIFY_TEST_LOG/${0##*/}"
    ;;
yobirin)
    if [[ ${1:-} == list ]]; then
        printf '{"bundles":[{"profile":"codex"}]}\n'
    else
        printf '%s\n' "$@" >"$NOTIFY_TEST_LOG/yobirin"
        printf 'clicked\n'
    fi
    ;;
herdr)
    if [[ ${2:-} == list ]]; then
        printf '{"result":{"agents":[{"agent_session":{"value":"notify-test-session"},"pane_id":"w1:p1"}]}}\n'
    else
        printf '%s\n' "$@" >"$NOTIFY_TEST_LOG/herdr"
    fi
    ;;
esac
MOCK
chmod +x "$TEST_DIR/bin/mock"
for name in uname nohup osascript open wezterm yobirin herdr; do
    ln -s mock "$TEST_DIR/bin/$name"
done

# HerdrでWezTermのpane IDが無くてもyobirinへ通知を送る。
bash "$NOTIFY_DIR/notify.sh" --native title message notify-test-session codex
for ((attempt = 0; attempt < 50; attempt++)); do
    [[ -f "$NOTIFY_TEST_LOG/nohup" ]] && break
    sleep 0.02
done
assert test -f "$NOTIFY_TEST_LOG/nohup"
assert test "$(head -n 1 "$NOTIFY_TEST_LOG/nohup")" = "$HOME/.dotfiles/script/notify/yobirin-wezterm-notify.sh"
assert test ! -f "$NOTIFY_TEST_LOG/osascript"

# 通知クリックからHerdrのsessionに戻る。WezTerm用URLは開かない。
bash "$NOTIFY_DIR/yobirin-wezterm-notify.sh" title message '' notify-test-session codex
assert test -f "$NOTIFY_TEST_LOG/yobirin"
assert test "$(cat "$NOTIFY_TEST_LOG/herdr")" = $'agent\nfocus\nw1:p1'
assert test ! -f "$NOTIFY_TEST_LOG/open"

# 既存のWezTerm通知クリックはWezTermとHerdrの両方へ戻る。
bash "$NOTIFY_DIR/yobirin-wezterm-notify.sh" title message 42 notify-test-session codex
assert test "$(cat "$NOTIFY_TEST_LOG/open")" = $'-g\nhammerspoon://wezterm-focus?session=notify-test-session&pane=42'

# session IDが無いWezTerm通知はpane IDで直接戻る。
bash "$NOTIFY_DIR/activate-wezterm-pane.sh" 42
assert test "$(cat "$NOTIFY_TEST_LOG/wezterm")" = $'cli\nactivate-pane\n--pane-id\n42'

printf '通知経路とクリック時の復帰先の検証に成功\n'
