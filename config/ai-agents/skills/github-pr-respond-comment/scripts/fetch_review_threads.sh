#!/usr/bin/env bash
# Fetch all review threads on a PR with their isResolved status via GraphQL.
#
# Usage:
#   fetch_review_threads.sh --repo <owner/repo> --pr <number> [--only-unresolved]
#
# Output (JSON to stdout): an array of review threads.
# Each thread is:
#   {
#     "thread_id": "<graphql node id>",
#     "is_resolved": true|false,
#     "is_outdated": true|false,
#     "path": "src/foo.ts",
#     "line": 42,
#     "root_comment_id": 1234567890,    # databaseId of the first comment; use this for /replies
#     "root_comment_node_id": "...",    # GraphQL node id of the first comment
#     "comments": [
#       {
#         "id": 1234567890,             # databaseId (used by REST /pulls/{n}/comments/{id}/replies)
#         "node_id": "...",
#         "author": "octocat",
#         "body": "...",
#         "created_at": "...",
#         "url": "..."
#       },
#       ...
#     ]
#   }
#
# With --only-unresolved, threads with is_resolved=true or is_outdated=true are filtered out.

set -euo pipefail

REPO=""
PR=""
ONLY_UNRESOLVED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --pr) PR="$2"; shift 2 ;;
    --only-unresolved) ONLY_UNRESOLVED=1; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

for var in REPO PR; do
  if [[ -z "${!var}" ]]; then
    echo "Missing required argument: --${var,,}" >&2
    exit 2
  fi
done

OWNER="${REPO%%/*}"
NAME="${REPO##*/}"

# Paginate through all review threads. Each thread can have many comments;
# we cap at 50 per thread which is well above any realistic discussion.
RESULT_FILE=$(mktemp)
trap 'rm -f "$RESULT_FILE"' EXIT
echo "[]" > "$RESULT_FILE"

CURSOR="null"
while :; do
  PAGE_JSON=$(gh api graphql \
    -F owner="$OWNER" \
    -F name="$NAME" \
    -F pr="$PR" \
    -F cursor="$CURSOR" \
    -f query='
      query($owner: String!, $name: String!, $pr: Int!, $cursor: String) {
        repository(owner: $owner, name: $name) {
          pullRequest(number: $pr) {
            reviewThreads(first: 50, after: $cursor) {
              pageInfo { hasNextPage endCursor }
              nodes {
                id
                isResolved
                isOutdated
                path
                line
                originalLine
                comments(first: 50) {
                  nodes {
                    id
                    databaseId
                    author { login }
                    body
                    createdAt
                    url
                  }
                }
              }
            }
          }
        }
      }
    ')

  PAGE_THREADS=$(echo "$PAGE_JSON" | jq '
    .data.repository.pullRequest.reviewThreads.nodes
    | map({
        thread_id: .id,
        is_resolved: .isResolved,
        is_outdated: .isOutdated,
        path: .path,
        line: (.line // .originalLine),
        root_comment_id: (.comments.nodes[0].databaseId),
        root_comment_node_id: (.comments.nodes[0].id),
        comments: [ .comments.nodes[] | {
          id: .databaseId,
          node_id: .id,
          author: (.author.login // "ghost"),
          body: .body,
          created_at: .createdAt,
          url: .url
        } ]
      })
  ')

  jq --argjson page "$PAGE_THREADS" '. + $page' "$RESULT_FILE" > "$RESULT_FILE.new"
  mv "$RESULT_FILE.new" "$RESULT_FILE"

  HAS_NEXT=$(echo "$PAGE_JSON" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  END_CURSOR=$(echo "$PAGE_JSON" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')

  if [[ "$HAS_NEXT" != "true" ]]; then
    break
  fi
  CURSOR="$END_CURSOR"
done

if [[ "$ONLY_UNRESOLVED" -eq 1 ]]; then
  jq '[ .[] | select(.is_resolved == false and .is_outdated == false) ]' "$RESULT_FILE"
else
  cat "$RESULT_FILE"
fi
