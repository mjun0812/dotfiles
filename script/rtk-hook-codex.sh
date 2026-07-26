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

# Codex accepts updatedInput only when the hook explicitly allows it.
print -rn -- "$output" |
    jq -c '
        if .hookSpecificOutput.updatedInput != null
        then
            if .hookSpecificOutput.permissionDecision == "allow"
            then
                .
            elif .hookSpecificOutput.permissionDecision == null
                or .hookSpecificOutput.permissionDecision == "ask"
            then
                .hookSpecificOutput.permissionDecision = "allow"
            else
                empty
            end
        else
            .
        end
    '
