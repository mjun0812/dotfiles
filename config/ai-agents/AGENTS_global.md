# Global Instructions

- Always respond in Japanese.
- Use English for all code comments and documentation within code blocks.
- Maintain Japanese for error explanations and troubleshooting guidance.

## Tools

You can use the following cli tools:

- fd
- rg
- gh
- bat
- eza

## Plan Mode

### Plan File Naming Convention

Plan files should be saved in `YYYYMMDD-<english-slug>.md` format.
- `english-slug`: A concise, descriptive summary of the plan's main objective (kebab-case)
- Examples: `20250125-add-user-auth.md`, `20250125-fix-api-timeout.md`, `20250125-refactor-database-layer.md`

### Exiting Plan Mode

Before exiting Plan Mode and starting implementation:
1. Rename the plan file to `YYYYMMDD-<english-slug>.md` format
2. Proceed with implementation only after renaming is complete

Note: Temporary filenames (e.g., `plan.md`, `draft-plan.md`) are acceptable during planning.

## Versioning

- Follow Semantic Versioning 2.0.0 when handling version numbers.

## Python

- Use `uv` for environment and package management.
- Use `uvx ruff format` and `uvx ruff check --fix` for code formatting and linting.

## Git

- Commit messages must be in English.
- Always follow the conventional commits format when making commit messages.
- Always insert blank line on the second line and begin the commit description starting from the third line.
- When using Git tags, please use the format “v1.0.0” or “v2.1.3” for version control.
