#!/usr/bin/env zsh

input=$(<&0)
output=$(print -rn -- "$input" | rtk hook claude)
rtk_status=$?

if ((rtk_status != 0)); then
    exit "$rtk_status"
fi

if [[ -z $output ]] ||
    ! print -rn -- "$output" | jq -e 'type == "object"' >/dev/null 2>&1; then
    exit 0
fi

permission_mode=$(print -rn -- "$input" | jq -r '.permission_mode // "default"' 2>/dev/null)
missing_decision="ask"

# Keep bypass mode non-interactive while prompting for other rewritten commands.
if [[ $permission_mode == "bypassPermissions" ]]; then
    missing_decision="allow"
fi

print -rn -- "$output" |
    jq -c --arg decision "$missing_decision" '
        if .hookSpecificOutput.updatedInput != null
            and .hookSpecificOutput.permissionDecision == null
        then
            .hookSpecificOutput.permissionDecision = $decision
        else
            .
        end
    '
