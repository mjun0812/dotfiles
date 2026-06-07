#!/usr/bin/env bash
# Resolve outdated review threads authored by the authenticated user on a PR.
#
# Usage:
#   resolve_outdated_threads.sh \
#     --repo <owner/repo> \
#     --pr <number>
#
# Behavior:
#   - Looks up the authenticated user via GraphQL `viewer { login }`.
#   - Fetches all review threads on the PR (paginated, 100 per page).
#   - Selects threads that are:
#       * not yet resolved (isResolved: false)
#       * outdated (isOutdated: true)
#       * authored by the authenticated user (the *first* comment's author.login
#         matches viewer login; this is the GitHub convention for thread ownership)
#   - Calls `resolveReviewThread` mutation for each selected thread.
#
# On success, prints "Resolved <n> outdated review thread(s)." to stderr.
# Errors are propagated via `set -e`.

set -euo pipefail

REPO=""
PR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --pr) PR="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$REPO" || -z "$PR" ]]; then
  echo "Missing required argument: --repo and --pr are required" >&2
  exit 2
fi

OWNER="${REPO%%/*}"
NAME="${REPO##*/}"

VIEWER=$(gh api graphql -f query='{ viewer { login } }' --jq '.data.viewer.login')

# Paginate review threads. GitHub returns up to 100 per page.
CURSOR="null"
RESOLVED_COUNT=0

while true; do
  if [[ "$CURSOR" == "null" ]]; then
    AFTER_ARG="null"
  else
    AFTER_ARG="\"$CURSOR\""
  fi

  RESPONSE=$(gh api graphql -f query="
    query {
      repository(owner: \"$OWNER\", name: \"$NAME\") {
        pullRequest(number: $PR) {
          reviewThreads(first: 100, after: $AFTER_ARG) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              isResolved
              isOutdated
              comments(first: 1) {
                nodes { author { login } }
              }
            }
          }
        }
      }
    }
  ")

  # Collect thread ids that are outdated, unresolved, and authored by viewer.
  THREAD_IDS=$(echo "$RESPONSE" | jq -r --arg viewer "$VIEWER" '
    .data.repository.pullRequest.reviewThreads.nodes[]
    | select(.isResolved == false)
    | select(.isOutdated == true)
    | select(.comments.nodes[0].author.login == $viewer)
    | .id
  ')

  while IFS= read -r thread_id; do
    [[ -z "$thread_id" ]] && continue
    echo "Resolving outdated thread $thread_id..." >&2
    gh api graphql -f query="
      mutation {
        resolveReviewThread(input: {threadId: \"$thread_id\"}) {
          thread { id isResolved }
        }
      }
    " >/dev/null
    RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
  done <<< "$THREAD_IDS"

  HAS_NEXT=$(echo "$RESPONSE" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  if [[ "$HAS_NEXT" != "true" ]]; then
    break
  fi
  CURSOR=$(echo "$RESPONSE" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
done

echo "Resolved $RESOLVED_COUNT outdated review thread(s)." >&2
