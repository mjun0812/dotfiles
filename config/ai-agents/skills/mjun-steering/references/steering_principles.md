# Steering Principles

Steering files are project memory: they tell an agent how this project is built so that new code fits in. They are neither specifications nor a copy of the code, so anything an agent can see by listing or reading files does not need repeating.

The test for granularity:

> "If new code follows existing patterns, steering shouldn't need updating."

A file that needs editing whenever a component or dependency is added is a catalog, not project memory.

These principles apply to core and custom files. ADRs record why hard-to-reverse decisions were made. They follow [glossary_and_adr.md](glossary_and_adr.md) and are never regenerated from code. When a steering file relies on a decision's rationale, link the ADR instead of restating it.

## Content Granularity

Document what guides decisions in new code:

- Organizational patterns (feature-first, layered)
- Naming conventions
- Import strategies (absolute vs relative)
- Architectural decisions (state management)
- Key technology standards

Leave out:

- Complete file listings, per-component descriptions, every dependency, and implementation details. They go stale with each change and are visible in the repo
- Agent-specific tooling directories (`.claude/`, `.codex/`, `.gemini/`, `.cursor/`) and `.mjun/` metadata. They describe the agent setup, not the project. A light reference to `.mjun/steering/` is fine

### Example Comparison

**Bad** (Specification-like):

```markdown
- /components/Button.tsx - Primary button with variants
- /components/Input.tsx - Text input with validation
- /components/Modal.tsx - Modal dialog
  ... (50+ files)
```

**Good** (Project Memory):

```markdown
## UI Components (`/components/ui/`)

Reusable, design-system aligned primitives

- Named by function (Button, Input, Modal)
- Export component + TypeScript interface
- No business logic
```

## File-Specific Focus

Templates give a starting structure. Adapt the headings to what the project actually has.

- **product.md**: Purpose, value, business context (not exhaustive features)
- **tech.md**: Key frameworks, standards, conventions (not all dependencies)
- **structure.md**: Organization patterns, naming rules (not directory trees)
- **Custom files**: One domain per file. Show its patterns with short code examples drawn from the files they come from
