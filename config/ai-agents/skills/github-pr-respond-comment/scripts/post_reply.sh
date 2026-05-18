#!/usr/bin/env bash
# Post a reply to a PR review comment (inline thread) or a PR-level issue
# comment, with the reply body always read from a file (never embedded in
# shell args, to avoid quoting/escape bugs).
#
# Usage:
#   post_reply.sh \
#     --repo <owner/repo> \
#     --pr <number> \
#     --body-file <path-to-markdown-body> \
#     ( --review-comment-id <id> | --issue-comment )
#
# --review-comment-id <id>
#   Reply to a review comment (inline thread). <id> MUST be the databaseId
#   of the thread's ROOT comment. POSTs to:
#     repos/{owner/repo}/pulls/{pr}/comments/{id}/replies
#
# --issue-comment
#   Post a new top-level PR comment (used to "reply" to review summaries or
#   issue-level comments — those have no native threading). POSTs to:
#     repos/{owner/repo}/issues/{pr}/comments
#
# On success, prints the HTML URL of the created comment to stdout.

set -euo pipefail

REPO=""
PR=""
BODY_FILE=""
REVIEW_COMMENT_ID=""
ISSUE_COMMENT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --pr) PR="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --review-comment-id) REVIEW_COMMENT_ID="$2"; shift 2 ;;
    --issue-comment) ISSUE_COMMENT=1; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

for var in REPO PR BODY_FILE; do
  if [[ -z "${!var}" ]]; then
    echo "Missing required argument: --${var,,}" >&2
    exit 2
  fi
done

if [[ ! -f "$BODY_FILE" ]]; then
  echo "Body file not found: $BODY_FILE" >&2
  exit 2
fi

if [[ -n "$REVIEW_COMMENT_ID" && "$ISSUE_COMMENT" -eq 1 ]]; then
  echo "Specify either --review-comment-id or --issue-comment, not both" >&2
  exit 2
fi

if [[ -z "$REVIEW_COMMENT_ID" && "$ISSUE_COMMENT" -eq 0 ]]; then
  echo "Must specify one of --review-comment-id or --issue-comment" >&2
  exit 2
fi

PAYLOAD_FILE=$(mktemp)
trap 'rm -f "$PAYLOAD_FILE"' EXIT

jq -n --rawfile body "$BODY_FILE" '{body: $body}' > "$PAYLOAD_FILE"

if [[ -n "$REVIEW_COMMENT_ID" ]]; then
  ENDPOINT="repos/${REPO}/pulls/${PR}/comments/${REVIEW_COMMENT_ID}/replies"
else
  ENDPOINT="repos/${REPO}/issues/${PR}/comments"
fi

RESPONSE=$(gh api -X POST "$ENDPOINT" --input "$PAYLOAD_FILE")

echo "$RESPONSE" | jq -r '.html_url'
