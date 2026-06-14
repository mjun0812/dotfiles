#!/usr/bin/env bash
# Post a new top-level PR comment, with the body always read from a file
# (never embedded in shell args, to avoid quoting/escape bugs).
#
# Used to "reply" to review summary bodies or PR-level issue comments — those
# have no native threading, so the convention is to post a new issue comment
# quoting the original.
#
# Usage:
#   post_issue_comment.sh \
#     --repo <owner/repo> \
#     --pr <number> \
#     --body-file <path-to-markdown-body>
#
# POSTs to:
#   repos/{owner/repo}/issues/{pr}/comments
#
# On success, prints the HTML URL of the created comment to stdout.

set -euo pipefail

REPO=""
PR=""
BODY_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --repo)
        REPO="$2"
        shift 2
        ;;
    --pr)
        PR="$2"
        shift 2
        ;;
    --body-file)
        BODY_FILE="$2"
        shift 2
        ;;
    *)
        echo "Unknown argument: $1" >&2
        exit 2
        ;;
    esac
done

for var in REPO PR BODY_FILE; do
    if [[ -z ${!var} ]]; then
        echo "Missing required argument: --${var,,}" >&2
        exit 2
    fi
done

if [[ ! -f $BODY_FILE ]]; then
    echo "Body file not found: $BODY_FILE" >&2
    exit 2
fi

PAYLOAD_FILE=$(mktemp)
trap 'rm -f "$PAYLOAD_FILE"' EXIT

jq -n --rawfile body "$BODY_FILE" '{body: $body}' >"$PAYLOAD_FILE"

ENDPOINT="repos/${REPO}/issues/${PR}/comments"
RESPONSE=$(gh api -X POST "$ENDPOINT" --input "$PAYLOAD_FILE")

echo "$RESPONSE" | jq -r '.html_url'
