#!/usr/bin/env zsh

set -euo pipefail

usage() {
    print -u2 "Usage: $0 create-dirty --repo <path>"
    print -u2 "       $0 create-commit --repo <path> --commit <commit>"
    print -u2 "       $0 verify --metadata <metadata.json>"
    print -u2 "       $0 cleanup --metadata <metadata.json>"
    exit 2
}

write_state_manifest() {
    local repo_root="$1"
    local output_path="$2"
    local relative_path
    local file_type

    git -C "$repo_root" diff --binary --full-index HEAD -- >"$output_path"
    git -C "$repo_root" ls-files --others --exclude-standard -z |
        while IFS= read -r -d $'\0' relative_path; do
            if [[ -L "$repo_root/$relative_path" ]]; then
                file_type="symlink"
            elif [[ -x "$repo_root/$relative_path" ]]; then
                file_type="executable"
            else
                file_type="file"
            fi
            printf '\0untracked\0%s\0%s\0' "$relative_path" "$file_type"
            git -C "$repo_root" hash-object --no-filters -- "$relative_path"
        done >>"$output_path"
}

metadata_value() {
    local metadata_path="$1"
    local query="$2"

    jq -er "$query" "$metadata_path"
}

command_name="${1:-}"
[[ -n $command_name ]] || usage
shift

case "$command_name" in
create-dirty | create-commit)
    if [[ $command_name == "create-dirty" ]]; then
        [[ $# -eq 2 && $1 == "--repo" ]] || usage
        repo_arg="$2"
        mode="dirty"
    else
        [[ $# -eq 4 && $1 == "--repo" && $3 == "--commit" ]] || usage
        repo_arg="$2"
        commit_arg="$4"
        mode="commit"
    fi

    repo_root=$(git -C "$repo_arg" rev-parse --show-toplevel)
    if [[ $mode == "dirty" ]]; then
        baseline_sha=$(git -C "$repo_root" rev-parse --verify HEAD)
        untracked_count=$(git -C "$repo_root" ls-files --others --exclude-standard -z | wc -c | tr -d ' ')
        if git -C "$repo_root" diff --quiet HEAD -- && ((untracked_count == 0)); then
            print -u2 "No uncommitted changes to review."
            exit 3
        fi
    else
        if ! snapshot_id=$(git -C "$repo_root" rev-parse --verify --end-of-options "${commit_arg}^{commit}"); then
            print -u2 "Commit not found: $commit_arg"
            exit 10
        fi
        if ! baseline_sha=$(git -C "$repo_root" rev-parse --verify "${snapshot_id}^1"); then
            print -u2 "Root commits are not supported: $snapshot_id"
            exit 10
        fi
        if git -C "$repo_root" diff --quiet "$baseline_sha" "$snapshot_id" --; then
            print -u2 "The commit has no changes to review: $snapshot_id"
            exit 3
        fi
    fi

    snapshot_root=$(mktemp -d /tmp/self-review.XXXXXX)
    snapshot_root=$(cd "$snapshot_root" && pwd -P)
    worktree_path="$snapshot_root/worktree"
    metadata_path="$snapshot_root/metadata.json"
    diff_path="$snapshot_root/diff.patch"
    changed_files_path="$snapshot_root/changed-files.txt"
    tracked_patch="$snapshot_root/tracked.patch"
    state_before="$snapshot_root/state.before"
    state_after="$snapshot_root/state.after"
    worktree_state="$snapshot_root/worktree.state"

    if [[ "$snapshot_root/" == "$repo_root/"* ]]; then
        print -u2 "Snapshot directory must be outside the repository."
        rm -rf "$snapshot_root"
        exit 4
    fi

    trap '
            exit_code=$?
            if ((exit_code != 0)); then
                if [[ -n "${worktree_path:-}" && -d "$worktree_path" ]]; then
                    git -C "$repo_root" worktree remove --force "$worktree_path" >/dev/null 2>&1 || true
                fi
                if [[ -n "${snapshot_root:-}" && "${snapshot_root:t}" == self-review.* ]]; then
                    rm -rf "$snapshot_root"
                fi
            fi
        ' EXIT

    if [[ $mode == "dirty" ]]; then
        write_state_manifest "$repo_root" "$state_before"
        snapshot_id=$(git -C "$repo_root" hash-object "$state_before")
        git -C "$repo_root" diff --binary --full-index HEAD -- >"$tracked_patch"

        git -C "$repo_root" worktree add --detach "$worktree_path" "$baseline_sha" >/dev/null
        if [[ -s $tracked_patch ]]; then
            git -C "$worktree_path" apply --binary --whitespace=nowarn "$tracked_patch"
        fi

        git -C "$repo_root" ls-files --others --exclude-standard -z |
            while IFS= read -r -d $'\0' relative_path; do
                destination="$worktree_path/$relative_path"
                mkdir -p "${destination:h}"
                cp -a "$repo_root/$relative_path" "$destination"
            done

        git -C "$worktree_path" add -A
        git -C "$worktree_path" diff --cached --binary --full-index HEAD -- >"$diff_path"
        git -C "$worktree_path" diff --cached --name-status HEAD -- >"$changed_files_path"

        write_state_manifest "$repo_root" "$state_after"
        current_snapshot_id=$(git -C "$repo_root" hash-object "$state_after")
        if [[ $current_snapshot_id != "$snapshot_id" ]]; then
            print -u2 "The working tree changed while the snapshot was being created."
            exit 5
        fi
        worktree_head="$baseline_sha"
    else
        git -C "$repo_root" worktree add --detach "$worktree_path" "$snapshot_id" >/dev/null
        git -C "$worktree_path" diff --binary --full-index "$baseline_sha" "$snapshot_id" -- >"$diff_path"
        git -C "$worktree_path" diff --name-status "$baseline_sha" "$snapshot_id" -- >"$changed_files_path"
        worktree_head="$snapshot_id"
    fi

    write_state_manifest "$worktree_path" "$worktree_state"
    worktree_state_id=$(git -C "$worktree_path" hash-object "$worktree_state")

    jq -n \
        --arg mode "$mode" \
        --arg repoRoot "$repo_root" \
        --arg worktree "$worktree_path" \
        --arg worktreeHead "$worktree_head" \
        --arg worktreeStateId "$worktree_state_id" \
        --arg baselineSha "$baseline_sha" \
        --arg snapshotId "$snapshot_id" \
        --arg diffFile "$diff_path" \
        --arg changedFilesFile "$changed_files_path" \
        '{
                version: 2,
                mode: $mode,
                repoRoot: $repoRoot,
                worktree: $worktree,
                worktreeHead: $worktreeHead,
                worktreeStateId: $worktreeStateId,
                baselineSha: $baselineSha,
                snapshotId: $snapshotId,
                diffFile: $diffFile,
                changedFilesFile: $changedFilesFile
            }' >"$metadata_path"

    rm -f "$tracked_patch" "$state_before" "$state_after" "$worktree_state"
    trap - EXIT
    print -r -- "$metadata_path"
    ;;
verify)
    [[ $# -eq 2 && $1 == "--metadata" ]] || usage
    metadata_path="$2"
    [[ -f $metadata_path ]] || {
        print -u2 "Snapshot metadata not found: $metadata_path"
        exit 6
    }

    metadata_path="${metadata_path:A}"
    snapshot_root="${metadata_path:h}"
    [[ $snapshot_root == /tmp/self-review.* || $snapshot_root == /private/tmp/self-review.* ]] || {
        print -u2 "Unexpected snapshot directory: $snapshot_root"
        exit 9
    }

    version=$(metadata_value "$metadata_path" '.version')
    mode=$(metadata_value "$metadata_path" '.mode')
    repo_root=$(metadata_value "$metadata_path" '.repoRoot')
    worktree_path=$(metadata_value "$metadata_path" '.worktree')
    worktree_head=$(metadata_value "$metadata_path" '.worktreeHead')
    worktree_state_id=$(metadata_value "$metadata_path" '.worktreeStateId')
    baseline_sha=$(metadata_value "$metadata_path" '.baselineSha')
    snapshot_id=$(metadata_value "$metadata_path" '.snapshotId')

    [[ $version == "2" && ($mode == "dirty" || $mode == "commit") ]] || {
        print -u2 "Unsupported snapshot metadata."
        exit 6
    }
    [[ $worktree_path == "$snapshot_root/worktree" && -d $worktree_path ]] || {
        print -u2 "Review worktree is missing or invalid."
        exit 9
    }

    current_worktree_head=$(git -C "$worktree_path" rev-parse --verify HEAD)
    if [[ $current_worktree_head != "$worktree_head" ]]; then
        print -u2 "The review worktree HEAD changed after the snapshot was created."
        exit 11
    fi

    state_file=$(mktemp /tmp/self-review-state.XXXXXX)
    trap 'rm -f "$state_file"' EXIT
    write_state_manifest "$worktree_path" "$state_file"
    current_worktree_state_id=$(git -C "$worktree_path" hash-object "$state_file")
    if [[ $current_worktree_state_id != "$worktree_state_id" ]]; then
        print -u2 "The review worktree changed after the snapshot was created."
        exit 11
    fi

    if [[ $mode == "dirty" ]]; then
        current_baseline_sha=$(git -C "$repo_root" rev-parse --verify HEAD)
        if [[ $current_baseline_sha != "$baseline_sha" ]]; then
            print -u2 "HEAD changed after the snapshot was created."
            exit 7
        fi

        write_state_manifest "$repo_root" "$state_file"
        current_snapshot_id=$(git -C "$repo_root" hash-object "$state_file")
        if [[ $current_snapshot_id != "$snapshot_id" ]]; then
            print -u2 "The working tree changed after the snapshot was created."
            exit 8
        fi
    fi

    rm -f "$state_file"
    trap - EXIT
    print -r -- "$snapshot_id"
    ;;
cleanup)
    [[ $# -eq 2 && $1 == "--metadata" ]] || usage
    metadata_path="$2"
    [[ -f $metadata_path ]] || {
        print -u2 "Snapshot metadata not found: $metadata_path"
        exit 6
    }

    metadata_path="${metadata_path:A}"
    snapshot_root="${metadata_path:h}"
    repo_root=$(metadata_value "$metadata_path" '.repoRoot')
    worktree_path=$(metadata_value "$metadata_path" '.worktree')

    [[ $snapshot_root == /tmp/self-review.* || $snapshot_root == /private/tmp/self-review.* ]] || {
        print -u2 "Refusing to remove an unexpected snapshot directory: $snapshot_root"
        exit 9
    }
    [[ $worktree_path == "$snapshot_root/worktree" ]] || {
        print -u2 "Snapshot metadata contains an unexpected worktree path."
        exit 9
    }
    [[ $snapshot_root != "/" && $snapshot_root != "$repo_root" ]] || {
        print -u2 "Refusing to remove an unsafe snapshot directory."
        exit 9
    }

    if [[ -d $worktree_path ]]; then
        git -C "$repo_root" worktree remove --force "$worktree_path" >/dev/null
    fi
    rm -rf "$snapshot_root"
    ;;
*)
    usage
    ;;
esac
