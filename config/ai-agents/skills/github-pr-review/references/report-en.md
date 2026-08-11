# <reviewer-name> PR Review

<!--
Authoring rules:
- Findings only contains findings from the Finder and Standards SubAgent that the verifier judged confirmed.
- Findings from the Standards SubAgent also block merge and affect the Verdict.
- If Findings has no items, keep the heading and write "N/A".
- Add a short category label describing the main harm or kind to each item.
- List Finder findings first and Standards findings second, numbering all Findings sequentially from 1.
- Each Finder finding must include `Problem` / `Execution path` / `Completion condition`.
- Each Standards finding must include `Problem` / `Basis` / `Completion condition`.
- A Finder finding's `Problem` combines the triggering condition, cause, and concrete harm.
- A Standards finding's `Problem` combines the facts visible in the diff and why deferring it until after merge is unsafe.
- `Execution path` traces the runtime path that reaches the problem as a chain of `file:line`.
- `Completion condition` describes the state that demonstrates the problem is resolved, not an implementation method.
- Do not include the Finder's and verifier's raw `Evidence` or verification logs in the review body or inline comments. Present reachability as a polished `Execution path`.
- If CI has failing checks, mention it in one line in the Summary.
- Do not create finding sections other than Findings in the final review.
- Only Findings become inline comments.
-->

## Summary

<!-- 1-4 sentence summary of what this PR does and the review result -->

## Verdict

<!-- APPROVE or REQUEST_CHANGES -->

## Findings

<!-- Findings from the Finder -->

- 1: `filename:line` - **[Category] Description of the issue**
  - Problem: ...
  - Execution path: `file:line` (note) -> `file:line` (note)
  - Completion condition: ...

<!-- Findings from the Standards SubAgent. They are unsafe to defer past merge and block merge. -->

- 2: `filename:line` - **[Category] Description of the issue**
  - Problem: ...
  - Basis: ...
  - Completion condition: ...

---

Reviewed by <reviewer-name> at `<short-sha>`
