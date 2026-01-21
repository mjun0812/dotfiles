#!/bin/bash
# Instruct Claude to rename the most recent plan file
TODAY=$(date +%Y-%m-%d)
cat <<EOF
{
  "decision": "block",
  "reason": "Check current plan filename and rename it to ${TODAY}-<english-slug>.md format (kebab-case). The english-slug should be a concise, descriptive summary of the plan's main objective (e.g., 'add-user-auth', 'fix-api-timeout', 'refactor-database-layer'). If the file already follows this format or no such file exists, proceed without action."
}
EOF
