# <reviewer-name> PR Review

<!--
Authoring rules:
- Required Changes only contains findings the verifier judged confirmed.
- Standards Suggestions only contains suggestions from the Standards SubAgent. They do not block merge and do not affect the Verdict.
- If either section has no items, keep the heading and write "N/A".
- Add a short category label describing the main harm or kind to each item.
- Each Required Change must include `Problem` / `Execution path` / `Completion condition`.
- Each Standards Suggestion must include `Problem` / `Basis` / `Suggestion`, numbered from S1.
- `Problem` combines the triggering condition, cause, and concrete harm.
- `Execution path` traces the runtime path that reaches the problem as a chain of `file:line`.
- `Completion condition` describes the state that demonstrates the problem is resolved, not an implementation method.
- Do not include the Finder's and verifier's raw `Evidence` or verification logs in the final review. Present reachability as a polished `Execution path`.
- Include `Verification details` only in inline comments, never in the final review.
- If CI has failing checks, mention it in one line in the Summary.
- Do not create finding sections other than Required Changes and Standards Suggestions in the final review.
- Only Required Changes and Standards Suggestions become inline comments.
-->

## Summary

<!-- 1-4 sentence summary of what this PR does and the review result -->

## Verdict

<!-- APPROVE or REQUEST_CHANGES -->

## Required Changes

- 1: `filename:line` - **[Category] Description of the issue**
  - Problem: ...
  - Execution path: `file:line` (note) -> `file:line` (note)
  - Completion condition: ...

## Standards Suggestions

<!-- Non-blocking suggestions. Addressing them is optional. -->

- S1: `filename:line` - **[Category] Description of the issue**
  - Problem: ...
  - Basis: ...
  - Suggestion: ...

---

Reviewed by <reviewer-name> at `<short-sha>`
