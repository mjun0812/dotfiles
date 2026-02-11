#!/bin/bash
# PostToolUse hook for ExitPlanMode: auto-rename plan files to YYYY-MM-DD-<slug>.md
# Reads PostToolUse JSON from stdin, finds the most recent unformatted plan file,
# extracts a slug from its title, and renames it.

set -euo pipefail

# Read stdin (PostToolUse JSON) - consumed but not currently used for path extraction
input=$(cat)

# Determine project directory
project_dir="${CLAUDE_PROJECT_DIR:-.}"

# Determine plans directory from settings.json or use default
plans_dir=""
settings_file="$project_dir/.claude/settings.json"
if [[ -f "$settings_file" ]] && command -v jq &>/dev/null; then
  plans_dir=$(jq -r '.plansDirectory // empty' "$settings_file" 2>/dev/null || true)
fi

# Resolve plans directory (may be relative to project)
if [[ -n "$plans_dir" ]]; then
  # Handle relative paths
  if [[ "$plans_dir" != /* ]]; then
    plans_dir="$project_dir/$plans_dir"
  fi
else
  plans_dir="$project_dir/.claude/plans"
fi

# Exit silently if plans directory doesn't exist
if [[ ! -d "$plans_dir" ]]; then
  exit 0
fi

# Find the most recently modified .md file that does NOT match YYYY-MM-DD-* pattern
target=""
while IFS= read -r -d '' file; do
  name=$(basename "$file")
  if [[ ! "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}- ]]; then
    target="$file"
    break
  fi
done < <(find "$plans_dir" -maxdepth 1 -name "*.md" -type f -print0 | xargs -0 ls -t 2>/dev/null | tr '\n' '\0')

# Exit silently if no rename target found
if [[ -z "$target" ]]; then
  exit 0
fi

# Skip empty files
if [[ ! -s "$target" ]]; then
  exit 0
fi

# Extract slug from the first markdown heading
slug=""
title_line=$(grep -m1 '^#\s' "$target" 2>/dev/null || true)
if [[ -n "$title_line" ]]; then
  # Remove leading # and trim
  title="${title_line#\#}"
  title="${title## }"

  # Extract ASCII words (letters, digits) and build slug
  slug=$(echo "$title" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9 ]/ /g' \
    | xargs \
    | tr ' ' '-' \
    | sed 's/--*/-/g; s/^-//; s/-$//')

  # Require at least 2 words for a meaningful slug
  word_count=$(echo "$slug" | tr '-' '\n' | wc -l | xargs)
  if [[ "$word_count" -lt 2 ]]; then
    slug=""
  fi
fi

# Fallback: try git branch name
if [[ -z "$slug" ]]; then
  branch=$(git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  if [[ -n "$branch" && "$branch" != "main" && "$branch" != "master" && "$branch" != "develop" && "$branch" != "HEAD" ]]; then
    # Strip common prefixes like feat/, fix/, etc.
    slug=$(echo "$branch" \
      | sed 's|^[a-z]*/||' \
      | tr '[:upper:]' '[:lower:]' \
      | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//')
  fi
fi

# Final fallback
if [[ -z "$slug" ]]; then
  slug="plan"
fi

# Build new filename with today's date
today=$(date +%Y-%m-%d)
new_name="${today}-${slug}.md"
new_path="$plans_dir/$new_name"

# Handle name collisions with -2, -3, etc.
if [[ -e "$new_path" ]]; then
  counter=2
  while [[ -e "$plans_dir/${today}-${slug}-${counter}.md" ]]; do
    ((counter++))
  done
  new_name="${today}-${slug}-${counter}.md"
  new_path="$plans_dir/$new_name"
fi

old_name=$(basename "$target")

# Rename the file
mv "$target" "$new_path"

# Output additionalContext for Claude
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Plan file renamed: ${old_name} → ${new_name}"
  }
}
EOF
