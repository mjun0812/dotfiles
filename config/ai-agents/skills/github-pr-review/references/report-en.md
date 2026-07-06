# <reviewer-name> PR Review

<!--
Authoring rules:
- The final review only contains Must Fix items (only findings the verifier judged confirmed).
- `[reviewer category]` must be **bold**; multi-category: `**[correctness / security]**`.
- If there are no Must Fix items, keep the heading and write "N/A".
- Each Must Fix item must include `Reason` / `Impact` / `Action` / `Confidence` / `Evidence`.
- Confidence must be `high` or `medium`; do not include findings with weak confidence in the final review.
- `Evidence` is the execution path that actually reaches the problem (a chain of `file:line`).
- If CI has failing checks, mention it in one line in the Summary.
- Do not create Should Fix or Question sections in the final review.
- Only Must Fix items become inline comments.
-->

## Summary

<!-- 1-4 sentence summary of what this PR does and the review result -->

## Verdict

<!-- APPROVE or REQUEST_CHANGES -->

## Must Fix

- 1: `filename:line` - **[reviewer category]** Description of the issue
  - Reason: ...
  - Impact: ...
  - Action: ...
  - Confidence: high | medium
  - Evidence: chain of `file:line` -> `file:line`

---

Reviewed by <reviewer-name> at `<short-sha>`
