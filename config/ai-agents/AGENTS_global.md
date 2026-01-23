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

Check current plan filename and rename it to `YYYYMMDD-<english-slug>.md` format (kebab-case).
The english-slug should be a concise, descriptive summary of the plan's main objective (e.g., 'add-user-auth', 'fix-api-timeout', 'refactor-database-layer').

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
