#!/usr/bin/env bash
# Fetch review threads on a PR with their resolved status via GitHub GraphQL.
#
# Usage:
#   fetch_review_threads.sh --repo <owner/repo> --pr <number> [--only-unresolved]
#
# Output: JSON array of review threads.

set -euo pipefail

REPO=""
PR=""
ONLY_UNRESOLVED=0

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
    --only-unresolved)
      ONLY_UNRESOLVED=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$REPO" ]]; then
  echo "Missing required argument: --repo" >&2
  exit 2
fi

if [[ -z "$PR" ]]; then
  echo "Missing required argument: --pr" >&2
  exit 2
fi

OWNER="${REPO%%/*}"
NAME="${REPO##*/}"
RESULT_FILE="$(mktemp)"
trap 'rm -f "$RESULT_FILE" "$RESULT_FILE.new"' EXIT

echo "[]" > "$RESULT_FILE"

CURSOR="null"
while :; do
  PAGE_JSON="$(gh api graphql \
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
    ')"

  PAGE_THREADS="$(echo "$PAGE_JSON" | jq '
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
  ')"

  jq --argjson page "$PAGE_THREADS" '. + $page' "$RESULT_FILE" > "$RESULT_FILE.new"
  mv "$RESULT_FILE.new" "$RESULT_FILE"

  HAS_NEXT="$(echo "$PAGE_JSON" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')"
  END_CURSOR="$(echo "$PAGE_JSON" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')"

  if [[ "$HAS_NEXT" != "true" ]]; then
    break
  fi

  CURSOR="$END_CURSOR"
done

if [[ "$ONLY_UNRESOLVED" -eq 1 ]]; then
  jq '[ .[] | select(.is_resolved == false) ]' "$RESULT_FILE"
else
  cat "$RESULT_FILE"
fi
