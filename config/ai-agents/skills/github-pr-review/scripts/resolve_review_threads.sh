#!/usr/bin/env bash
# Resolve explicitly selected review threads.
#
# Usage:
#   resolve_review_threads.sh \
#     --thread-id <id> [--thread-id <id>]...
#
# Pass only thread IDs captured before posting the replacement review. The
# script performs no discovery, so it cannot resolve threads created by the new
# review.

set -euo pipefail

THREAD_IDS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
    --thread-id)
        THREAD_IDS+=("$2")
        shift 2
        ;;
    *)
        echo "Unknown argument: $1" >&2
        exit 2
        ;;
    esac
done

if [[ ${#THREAD_IDS[@]} -eq 0 ]]; then
    echo "Missing required argument: at least one --thread-id is required" >&2
    exit 2
fi

RESOLVED_COUNT=0

for thread_id in "${THREAD_IDS[@]}"; do
    echo "Resolving previous review thread $thread_id..." >&2
    # shellcheck disable=SC2016 # GraphQL variable, not a shell expansion.
    gh api graphql \
        -f query='mutation($threadId: ID!) {
          resolveReviewThread(input: {threadId: $threadId}) {
            thread { id isResolved }
          }
        }' \
        -f threadId="$thread_id" >/dev/null
    RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
done

echo "Resolved $RESOLVED_COUNT previous review thread(s)." >&2
