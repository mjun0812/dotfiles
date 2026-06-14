#!/usr/bin/env bash
# Post a reply to a PR inline review thread, with the reply body always read
# from a file (never embedded in shell args, to avoid quoting/escape bugs).
#
# Usage:
#   post_review_reply.sh \
#     --repo <owner/repo> \
#     --pr <number> \
#     --review-comment-id <id> \
#     --body-file <path-to-markdown-body>
#
# --review-comment-id <id>
#   <id> MUST be the databaseId of the thread's ROOT comment. POSTs to:
#     repos/{owner/repo}/pulls/{pr}/comments/{id}/replies
#
# On success, prints the HTML URL of the created comment to stdout.

set -euo pipefail

REPO=""
PR=""
BODY_FILE=""
REVIEW_COMMENT_ID=""

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
    --review-comment-id)
        REVIEW_COMMENT_ID="$2"
        shift 2
        ;;
    *)
        echo "Unknown argument: $1" >&2
        exit 2
        ;;
    esac
done

for var in REPO PR BODY_FILE REVIEW_COMMENT_ID; do
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

ENDPOINT="repos/${REPO}/pulls/${PR}/comments/${REVIEW_COMMENT_ID}/replies"
RESPONSE=$(gh api -X POST "$ENDPOINT" --input "$PAYLOAD_FILE")

echo "$RESPONSE" | jq -r '.html_url'
