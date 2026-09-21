# Steering Principles

Steering files are **project memory**, not exhaustive specifications.

The pattern and regeneration guidance below applies to core/custom files. `decisions.md` is the shared decision history: follow [the decision record rules](glossary_and_adr.md), preserve its entries, and never regenerate it from code. Source/Evidence may reference spec paths.

---

## Content Granularity

### Golden Rule

> "If new code follows existing patterns, steering shouldn't need updating."

### ✅ Document

- Organizational patterns (feature-first, layered)
- Naming conventions (PascalCase rules)
- Import strategies (absolute vs relative)
- Architectural decisions (state management)
- Technology standards (key frameworks)

### ❌ Avoid

- Complete file listings
- Every component description
- All dependencies
- Implementation details
- Agent-specific tooling directories (e.g. `.cursor/`, `.gemini/`, `.claude/`)
- Detailed documentation of `.mjun/` metadata directories

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

---

## Security

Never include:

- API keys, passwords, credentials
- Database URLs, internal IPs
- Secrets or sensitive data

---

## Quality Standards

- **Single domain**: One topic per file
- **Concrete examples**: Show patterns with code
- **Reference rationale**: Link to the relevant D-number in decisions.md instead of duplicating its history
- **Maintainable size**: 100-200 lines typical

---

## Preservation (when updating)

- Preserve user sections and custom examples
- Additive by default (add, don't replace)
- Note why changes were made

---

## Notes

- Templates are starting points, customize as needed
- All steering files loaded as project memory
- Light references to `.mjun/steering/` are acceptable; avoid documenting other `.mjun/` directories
- Custom files equally important as core files

---

## File-Specific Focus

- **product.md**: Purpose, value, business context (not exhaustive features)
- **tech.md**: Key frameworks, standards, conventions (not all dependencies)
- **structure.md**: Organization patterns, naming rules (not directory trees)
- **Custom files**: Specialized patterns (API, testing, security, etc.)
