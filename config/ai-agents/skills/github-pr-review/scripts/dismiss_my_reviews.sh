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
#   - If one or more --review-id are passed, dismiss exactly those review IDs.
#     This is the recommended path: pass a snapshot of pre-existing review IDs
#     captured BEFORE posting the new review, so that the freshly posted review
#     is never dismissed by accident.
#   - If no --review-id is passed, fall back to "dismiss every APPROVED or
#     CHANGES_REQUESTED review authored by the authenticated user on this PR".
#     WARNING: with this fallback, a review posted moments before will also be
#     dismissed. Prefer the snapshot approach when calling right after posting.
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

# If no explicit IDs given, discover all of the authenticated user's
# APPROVED/CHANGES_REQUESTED reviews on this PR.
if [[ ${#REVIEW_IDS[@]} -eq 0 ]]; then
    VIEWER=$(gh api graphql -f query='{ viewer { login } }' --jq '.data.viewer.login')
    while IFS= read -r review_id; do
        [[ -z $review_id ]] && continue
        REVIEW_IDS+=("$review_id")
    done < <(gh api "repos/${REPO}/pulls/${PR}/reviews" --jq "
    [.[]
      | select(.user.login == \"${VIEWER}\")
      | select(.state == \"APPROVED\" or .state == \"CHANGES_REQUESTED\")
      | .id
    ] | .[]
  ")
fi

DISMISSED_COUNT=0
if [[ ${#REVIEW_IDS[@]} -gt 0 ]]; then
    for review_id in "${REVIEW_IDS[@]}"; do
        echo "Dismissing existing review #${review_id}..." >&2
        gh api -X PUT \
            "repos/${REPO}/pulls/${PR}/reviews/${review_id}/dismissals" \
            -f message="$MESSAGE" >/dev/null
        DISMISSED_COUNT=$((DISMISSED_COUNT + 1))
    done
fi

echo "Dismissed ${DISMISSED_COUNT} review(s)." >&2
