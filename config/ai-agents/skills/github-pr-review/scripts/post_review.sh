#!/usr/bin/env bash
# Post a new PR review (with optional inline comments) via GitHub API.
#
# Usage:
#   post_review.sh \
#     --repo <owner/repo> \
#     --pr <number> \
#     --commit <sha> \
#     --event <APPROVE|REQUEST_CHANGES|COMMENT> \
#     --body-file <path-to-markdown-body> \
#     [--comments-file <path-to-comments-json>]
#
# To dismiss existing reviews, use scripts/dismiss_my_reviews.sh separately.
# To resolve threads replaced by this review, use scripts/resolve_review_threads.sh.
#
# Comments JSON shape (array):
#   [
#     {"path": "src/foo.ts", "line": 42, "body": "...", "side": "RIGHT"},
#     ...
#   ]
#
# - "side" is optional. Default is "RIGHT" (post-change). Use "LEFT" to comment
#   on a deleted line in the original file.
# - Comments whose (path, line, side) is not part of the PR diff are omitted
#   from inline comments. The review body is not modified because it already
#   contains every finding.
#
# On success, prints the PR HTML URL to stdout.

set -euo pipefail

REPO=""
PR=""
COMMIT=""
EVENT=""
BODY_FILE=""
COMMENTS_FILE=""

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
    --commit)
        COMMIT="$2"
        shift 2
        ;;
    --event)
        EVENT="$2"
        shift 2
        ;;
    --body-file)
        BODY_FILE="$2"
        shift 2
        ;;
    --comments-file)
        COMMENTS_FILE="$2"
        shift 2
        ;;
    *)
        echo "Unknown argument: $1" >&2
        exit 2
        ;;
    esac
done

require() {
    local name="$1" value="$2" flag="$3"
    if [[ -z $value ]]; then
        echo "Missing required argument: $flag" >&2
        exit 2
    fi
}
require REPO "$REPO" --repo
require PR "$PR" --pr
require COMMIT "$COMMIT" --commit
require EVENT "$EVENT" --event
require BODY_FILE "$BODY_FILE" --body-file

case "$EVENT" in
APPROVE | REQUEST_CHANGES | COMMENT) ;;
*)
    echo "--event must be APPROVE, REQUEST_CHANGES, or COMMENT (got: $EVENT)" >&2
    exit 2
    ;;
esac

if [[ ! -f $BODY_FILE ]]; then
    echo "Body file not found: $BODY_FILE" >&2
    exit 2
fi

if [[ -n $COMMENTS_FILE && ! -f $COMMENTS_FILE ]]; then
    echo "Comments file not found: $COMMENTS_FILE" >&2
    exit 2
fi

PAYLOAD_FILE=$(mktemp)
PR_FILES_FILE=$(mktemp)
SPLIT_FILE=$(mktemp)
VALID_COMMENTS_FILE=$(mktemp)
trap 'rm -f "$PAYLOAD_FILE" "$PR_FILES_FILE" "$SPLIT_FILE" "$VALID_COMMENTS_FILE"' EXIT

# Preflight: split inline comments into (valid, invalid) by checking whether
# (path, line, side) is part of the PR diff. Invalid entries are omitted from
# inline comments without changing the review body.
if [[ -n $COMMENTS_FILE ]]; then
    gh api "repos/${REPO}/pulls/${PR}/files" --paginate >"$PR_FILES_FILE"

    jq --slurpfile comments "$COMMENTS_FILE" '
    def parse_patch:
      if . == null or . == "" then []
      else
        split("\n")
        | reduce .[] as $l (
            {old: 0, new: 0, lines: []};
            if ($l | test("^@@ -[0-9]+")) then
              ($l | capture("@@ -(?<os>[0-9]+)(,[0-9]+)? \\+(?<ns>[0-9]+)(,[0-9]+)? @@")) as $h
              | .old = ($h.os | tonumber)
              | .new = ($h.ns | tonumber)
            elif ($l | startswith("+++")) or ($l | startswith("---")) or ($l | startswith("\\")) then
              .
            elif ($l | startswith("+")) then
              .lines += [{line: .new, side: "RIGHT"}]
              | .new += 1
            elif ($l | startswith("-")) then
              .lines += [{line: .old, side: "LEFT"}]
              | .old += 1
            else
              .lines += [{line: .new, side: "RIGHT"}, {line: .old, side: "LEFT"}]
              | .new += 1
              | .old += 1
            end
          )
        | .lines
      end;

    (
      [ .[] | (.patch // "") as $p | .filename as $f | ($p | parse_patch) | map(. + {path: $f}) ]
      | flatten
      | map("\(.path):\(.line):\(.side)")
      | unique
    ) as $valid_set
    |
    ( $comments[0] | map(. + {_key: "\(.path):\(.line):\(.side // "RIGHT")"}) ) as $annotated
    | {
        valid:   [ $annotated[] | . as $c | select($valid_set | index($c._key) != null) | del(._key) ],
        invalid: [ $annotated[] | . as $c | select($valid_set | index($c._key) == null) | del(._key) ]
      }
  ' "$PR_FILES_FILE" >"$SPLIT_FILE"

    jq '.valid' "$SPLIT_FILE" >"$VALID_COMMENTS_FILE"

    INVALID_COUNT=$(jq '.invalid | length' "$SPLIT_FILE")
    VALID_COUNT=$(jq 'length' "$VALID_COMMENTS_FILE")

    if [[ $INVALID_COUNT -gt 0 ]]; then
        echo "Warning: ${INVALID_COUNT} inline comment(s) target lines not in the PR diff; omitting them from inline comments. Findings remain in the review body." >&2
    fi

    if [[ $VALID_COUNT -eq 0 ]]; then
        COMMENTS_FILE=""
    else
        COMMENTS_FILE="$VALID_COMMENTS_FILE"
    fi
fi

# Build the request payload via jq so the body is properly escaped.

if [[ -n $COMMENTS_FILE ]]; then
    jq -n \
        --rawfile body "$BODY_FILE" \
        --arg commit_id "$COMMIT" \
        --arg event "$EVENT" \
        --slurpfile comments "$COMMENTS_FILE" \
        '{body: $body, commit_id: $commit_id, event: $event, comments: $comments[0]}' \
        >"$PAYLOAD_FILE"
else
    jq -n \
        --rawfile body "$BODY_FILE" \
        --arg commit_id "$COMMIT" \
        --arg event "$EVENT" \
        '{body: $body, commit_id: $commit_id, event: $event}' \
        >"$PAYLOAD_FILE"
fi

RESPONSE=$(gh api -X POST \
    "repos/${REPO}/pulls/${PR}/reviews" \
    --input "$PAYLOAD_FILE")

echo "$RESPONSE" | jq -r '.html_url'
