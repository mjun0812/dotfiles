# <reviewer-name> PR Review

<!--
Authoring rules:
- Findings only contains findings from the Finder, Standards, and Contract SubAgent that the verifier judged confirmed.
- Findings from the Standards and Contract SubAgent also block merge and affect the Verdict.
- If Findings has no items, keep the heading and write "N/A".
- Add a short category label describing the main harm or kind to each item.
- List Finder findings first, Standards findings second, and Contract findings third, numbering all Findings sequentially from 1.
- Each Finder finding must include `Problem` / `Execution path` / `Completion condition`.
- Each Standards or Contract finding must include `Problem` / `Basis` / `Completion condition`.
- A Finder finding's `Problem` combines the triggering condition, cause, and concrete harm.
- A Standards finding's `Problem` combines the facts visible in the diff and why deferring it until after merge is unsafe.
- A Contract finding's `Problem` combines the current state of the implementation and how it diverges from the contract's promise.
- A Contract finding's `Basis` quotes the relevant spec statement and cites the implementation `file:line`.
- Do not list Contract findings that come from a local spec as individual items; state their count and why they are withheld in one line in the Summary.
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

<!-- Findings from the Contract SubAgent. They diverge from the spec contract and block merge. -->

- 3: `filename:line` - **[Category] Description of the issue**
  - Problem: ...
  - Basis: ...
  - Completion condition: ...

---

Reviewed by <reviewer-name> at `<short-sha>`
