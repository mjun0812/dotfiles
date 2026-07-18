#!/usr/bin/env bash
# Dismiss the authenticated user's reviews on a PR.
#
# Usage:
#   dismiss_my_reviews.sh \
#     --repo <owner/repo> \
#     --pr <number> \
#     [--review-id <id>]... \
#     [--message <message>]
#
# Behavior:
#   - Dismisses exactly the review IDs passed with --review-id.
#   - Pass a snapshot captured before posting the replacement review so that
#     the freshly posted review is never dismissed by accident.
#
# On success, prints "Dismissed <n> review(s)." to stderr.

set -euo pipefail

REPO=""
PR=""
REVIEW_IDS=()
MESSAGE="Superseded by new review"

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
    --review-id)
        REVIEW_IDS+=("$2")
        shift 2
        ;;
    --message)
        MESSAGE="$2"
        shift 2
        ;;
    *)
        echo "Unknown argument: $1" >&2
        exit 2
        ;;
    esac
done

if [[ -z $REPO || -z $PR ]]; then
    echo "Missing required argument: --repo and --pr are required" >&2
    exit 2
fi

if [[ ${#REVIEW_IDS[@]} -eq 0 ]]; then
    echo "Missing required argument: at least one --review-id is required" >&2
    exit 2
fi

DISMISSED_COUNT=0
for review_id in "${REVIEW_IDS[@]}"; do
    echo "Dismissing existing review #${review_id}..." >&2
    gh api -X PUT \
        "repos/${REPO}/pulls/${PR}/reviews/${review_id}/dismissals" \
        -f message="$MESSAGE" >/dev/null
    DISMISSED_COUNT=$((DISMISSED_COUNT + 1))
done

echo "Dismissed ${DISMISSED_COUNT} review(s)." >&2
