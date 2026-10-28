#!/usr/bin/env zsh

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)
AGENT_SKILLS_SOURCE_DIR="$DOTPATH/config/ai-agents/skills"

# 展開先のdirectoryと、その退避先の名前
typeset -A SKILL_TARGETS=(
    "$HOME/.agents/skills" agents_skills
    "$HOME/.claude/skills" claude_skills
    "$HOME/.gemini/antigravity-cli/skills" antigravity_cli_skills
)

# APMが展開するdirectoryのsymlinkはdotfilesしか作らず、下で作り直す。
# 壊れたlinkや、skillがAPMへ移ったlinkが残ると、退避のcp -Lが失敗してAPMがupdateを止める
for target in ${(k)SKILL_TARGETS}; do
    for link in "$target"/*(@N); do
        rm -f "$link"
    done
done

# 旧Antigravity CLIのskills。壊れたlinkはcp -Lを失敗させる
for link in "$HOME/.gemini/skills"/*(@N); do
    [ -e "$link" ] || rm -f "$link"
done
cp -aLf "$HOME/.gemini/skills" "$DOTPATH/.backup/gemini_skills" 2>/dev/null && rm -rf "$HOME/.gemini/skills"

for target in ${(k)SKILL_TARGETS}; do
    cp -aLf "$target" "$DOTPATH/.backup/${SKILL_TARGETS[$target]}" 2>/dev/null || true
    mkdir -p "$target"
    for skill_dir in "$AGENT_SKILLS_SOURCE_DIR"/*(/N); do
        skill_name=${skill_dir:t}
        rm -rf "$target/$skill_name"
        ln -snfv "$skill_dir" "$target/$skill_name"
    done
done
