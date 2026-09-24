#!/usr/bin/env zsh
# Report GitHub Actions `uses:` refs that lag behind the action's latest release.
# Claude Code PostToolUse hook (event JSON on stdin) or standalone with file paths.

set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/gha-version-hook"
CACHE_TTL_MIN=$((24 * 60))

command -v gh >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

typeset -a files
if (($# > 0)); then
    hook_mode=0
    files=("$@")
else
    hook_mode=1
    file=$(jq -r '.tool_input.file_path // ""' 2>/dev/null)
    [[ $file == */.github/workflows/*.(yml|yaml) || $file == */action.(yml|yaml) ]] || exit 0
    files=("$file")
fi

# Latest release tag for owner/repo, cached for CACHE_TTL_MIN minutes.
latest_tag() {
    local repo=$1
    local cache="$CACHE_DIR/${repo//\//_}"
    if [[ -f $cache && -z $(find "$cache" -mmin +$CACHE_TTL_MIN 2>/dev/null) ]]; then
        cat "$cache"
        return 0
    fi

    local tag
    tag=$(gh api "repos/$repo/releases/latest" --jq '.tag_name' 2>/dev/null)
    if [[ -z $tag ]]; then
        # Actions that publish tags without releases.
        tag=$(gh api "repos/$repo/tags" --jq '.[].name' 2>/dev/null |
            grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -1)
    fi
    [[ -n $tag ]] || return 1

    mkdir -p "$CACHE_DIR"
    print -r -- "$tag" >|"$cache"
    print -r -- "$tag"
}

# Compare only as precisely as the workflow pins: `v4` ignores patch bumps.
is_outdated() {
    local -a cur lat
    cur=(${(s:.:)${1#v}})
    lat=(${(s:.:)${2#v}})
    local n=${#cur}
    ((n > ${#lat})) && n=${#lat}
    [[ ${(j:.:)cur[1,$n]} != ${(j:.:)lat[1,$n]} ]]
}

typeset -a findings segments
for file in $files; do
    [[ -f $file ]] || continue
    for line in ${(f)"$(grep -oE 'uses:[[:space:]]*[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9._/-]+@[A-Za-z0-9._-]+' "$file" 2>/dev/null)"}; do
        entry=${${line#*uses:}// /}
        ref=${entry##*@}
        # Only version refs: SHA pins and branch refs are left alone.
        [[ $ref =~ '^[0-9a-f]{40}$' ]] && continue
        [[ $ref == [0-9]* || $ref == v[0-9]* ]] || continue

        # Trim the subdirectory of actions like `owner/repo/sub@v1`.
        segments=(${(s:/:)${entry%@*}})
        repo="${segments[1]}/${segments[2]}"

        tag=$(latest_tag "$repo") || continue
        is_outdated "$ref" "$tag" || continue
        findings+=("${repo}@${ref} -> ${tag} (${file})")
    done
done

((${#findings} > 0)) || exit 0

if ((hook_mode)); then
    jq -n --arg body "${(F)findings}" '{
        hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: ("以下のGitHub Actionsが最新版ではありません。意図的な固定でなければ最新版へ更新してください。\n" + $body)
        }
    }'
    exit 0
fi

print -rl -- $findings
exit 1
