#!/usr/bin/env bash
# Post a PR review (with optional inline comments) via GitHub API.
#
# Usage:
#   post_review.sh \
#     --repo <owner/repo> \
#     --pr <number> \
#     --commit <sha> \
#     --event <APPROVE|REQUEST_CHANGES|COMMENT> \
#     --body-file <path-to-markdown-body> \
#     [--comments-file <path-to-comments-json>] \
#     [--dismiss-review-id <id>] \
#     [--dismiss-message <message>]
#
# Comments JSON shape (array):
#   [
#     {"path": "src/foo.ts", "line": 42, "body": "..."},
#     ...
#   ]
#
# On success, prints the PR HTML URL to stdout.

set -euo pipefail

REPO=""
PR=""
COMMIT=""
EVENT=""
BODY_FILE=""
COMMENTS_FILE=""
DISMISS_REVIEW_ID=""
DISMISS_MESSAGE="Superseded by new review"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --pr) PR="$2"; shift 2 ;;
    --commit) COMMIT="$2"; shift 2 ;;
    --event) EVENT="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --comments-file) COMMENTS_FILE="$2"; shift 2 ;;
    --dismiss-review-id) DISMISS_REVIEW_ID="$2"; shift 2 ;;
    --dismiss-message) DISMISS_MESSAGE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

for var in REPO PR COMMIT EVENT BODY_FILE; do
  if [[ -z "${!var}" ]]; then
    echo "Missing required argument: --${var,,}" >&2
    exit 2
  fi
done

case "$EVENT" in
  APPROVE|REQUEST_CHANGES|COMMENT) ;;
  *) echo "--event must be APPROVE, REQUEST_CHANGES, or COMMENT (got: $EVENT)" >&2; exit 2 ;;
esac

if [[ ! -f "$BODY_FILE" ]]; then
  echo "Body file not found: $BODY_FILE" >&2
  exit 2
fi

if [[ -n "$COMMENTS_FILE" && ! -f "$COMMENTS_FILE" ]]; then
  echo "Comments file not found: $COMMENTS_FILE" >&2
  exit 2
fi

if [[ -n "$DISMISS_REVIEW_ID" ]]; then
  echo "Dismissing existing review #$DISMISS_REVIEW_ID..." >&2
  gh api -X PUT \
    "repos/${REPO}/pulls/${PR}/reviews/${DISMISS_REVIEW_ID}/dismissals" \
    -f message="$DISMISS_MESSAGE" >/dev/null
fi

# Build the request payload via jq so the body is properly escaped.
PAYLOAD_FILE=$(mktemp)
trap 'rm -f "$PAYLOAD_FILE"' EXIT

if [[ -n "$COMMENTS_FILE" ]]; then
  jq -n \
    --rawfile body "$BODY_FILE" \
    --arg commit_id "$COMMIT" \
    --arg event "$EVENT" \
    --slurpfile comments "$COMMENTS_FILE" \
    '{body: $body, commit_id: $commit_id, event: $event, comments: $comments[0]}' \
    > "$PAYLOAD_FILE"
else
  jq -n \
    --rawfile body "$BODY_FILE" \
    --arg commit_id "$COMMIT" \
    --arg event "$EVENT" \
    '{body: $body, commit_id: $commit_id, event: $event}' \
    > "$PAYLOAD_FILE"
fi

RESPONSE=$(gh api -X POST \
  "repos/${REPO}/pulls/${PR}/reviews" \
  --input "$PAYLOAD_FILE")

echo "$RESPONSE" | jq -r '.html_url'
