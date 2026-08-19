#!/usr/bin/env bash
#
# Install this repo's skills into your AI coding agents.
#
# Skills are symlinked rather than copied, so a `git pull` here updates every
# agent at once and editing an installed skill edits the repo.
#
#   ./install.sh                       prompt for agent, then for skills
#   ./install.sh claude                every skill into Claude Code
#   ./install.sh both why how          two skills into both agents
#   ./install.sh --uninstall codex     remove this repo's links from Codex
#
set -euo pipefail

script_path=$0
while [ -L "$script_path" ]; do
    link=$(readlink "$script_path")
    case $link in
        /*) script_path=$link ;;
        *)  script_path=$(dirname "$script_path")/$link ;;
    esac
done
REPO_DIR=$(cd -- "$(dirname -- "$script_path")" && pwd -P)
SKILLS_DIR="$REPO_DIR/skills"
PROG=$(basename -- "$script_path")

if [ -t 1 ]; then
    B=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; YLW=$'\033[33m'; RST=$'\033[0m'
else
    B=''; DIM=''; RED=''; YLW=''; RST=''
fi

die() { printf '%s%s:%s %s\n' "$RED" "$PROG" "$RST" "$1" >&2; exit 1; }

usage() {
    cat <<EOF
${B}Usage${RST}
  $PROG [--uninstall] [agent] [skill...]

${B}Arguments${RST}
  agent    claude | codex | both        prompted for if omitted
  skill    one or more skill names      prompted for if omitted; default all

${B}Options${RST}
  -u, --uninstall   Remove links this repo installed, instead of adding them
  -l, --list        List the skills in this repo and where each is installed
  -h, --help        Show this message

${B}Where skills go${RST}
  claude   ~/.claude/skills     read by Claude Code
  codex    ~/.agents/skills     read by Codex (~/.codex/skills is deprecated)

Existing real directories are never overwritten or deleted; only symlinks
pointing into this repo are managed.
EOF
}

# Directory each agent reads skills from.
agent_dir() {
    case $1 in
        claude) printf '%s\n' "$HOME/.claude/skills" ;;
        codex)  printf '%s\n' "$HOME/.agents/skills" ;;
        *)      die "unknown agent: $1" ;;
    esac
}

agent_label() {
    case $1 in
        claude) printf 'Claude Code\n' ;;
        codex)  printf 'Codex\n' ;;
    esac
}

# A skill is any directory under skills/ holding a SKILL.md.
discover_skills() {
    local dir name
    ALL_SKILLS=()
    for dir in "$SKILLS_DIR"/*/; do
        [ -f "$dir/SKILL.md" ] || continue
        name=$(basename -- "${dir%/}")
        ALL_SKILLS+=("$name")
    done
    [ "${#ALL_SKILLS[@]}" -gt 0 ] || die "no skills found in $SKILLS_DIR"
}

# Resolve a path through symlinks. Skills are directories, so cd -P does it
# without depending on realpath being present.
resolve_dir() { (cd -P -- "$1" 2>/dev/null && pwd -P) || true; }

contains() {
    local needle=$1 item
    shift
    for item in "$@"; do [ "$item" = "$needle" ] && return 0; done
    return 1
}

choose_agent() {
    local reply
    [ -t 0 ] || die "no agent given and stdin is not a terminal (try: $PROG claude)"
    printf '%sWhich agent?%s\n\n' "$B" "$RST"
    printf '  1) Claude Code  %s%s%s\n' "$DIM" "$(agent_dir claude)" "$RST"
    printf '  2) Codex        %s%s%s\n' "$DIM" "$(agent_dir codex)" "$RST"
    printf '  3) Both\n\n'
    while :; do
        printf 'Choice [1-3]: '
        read -r reply || die 'cancelled'
        case ${reply// /} in
            1|claude) AGENTS=(claude); break ;;
            2|codex)  AGENTS=(codex);  break ;;
            3|both)   AGENTS=(claude codex); break ;;
            *) printf 'Enter 1, 2, or 3.\n' ;;
        esac
    done
    printf '\n'
}

# Turn a selection string ("all", "1 3", "why,how") into SKILLS.
parse_selection() {
    local raw=${1//,/ } token idx picked=()
    if [ -z "${raw// /}" ] || [ "$raw" = all ]; then
        SKILLS=("${ALL_SKILLS[@]}")
        return 0
    fi
    for token in $raw; do
        if [[ $token =~ ^[0-9]+$ ]]; then
            idx=$((token - 1))
            if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#ALL_SKILLS[@]}" ]; then
                printf 'No skill numbered %s.\n' "$token" >&2
                return 1
            fi
            token=${ALL_SKILLS[$idx]}
        elif ! contains "$token" "${ALL_SKILLS[@]}"; then
            printf 'Unknown skill: %s (known: %s)\n' "$token" "${ALL_SKILLS[*]}" >&2
            return 1
        fi
        contains "$token" ${picked[@]+"${picked[@]}"} || picked+=("$token")
    done
    SKILLS=("${picked[@]}")
}

choose_skills() {
    local i reply verb=install
    [ "$UNINSTALL" = 1 ] && verb=remove
    [ -t 0 ] || { SKILLS=("${ALL_SKILLS[@]}"); return; }
    printf '%sWhich skills to %s?%s\n\n' "$B" "$verb" "$RST"
    for i in "${!ALL_SKILLS[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${ALL_SKILLS[$i]}"
    done
    printf '\n'
    while :; do
        printf 'Numbers or names, blank for all: '
        read -r reply || die 'cancelled'
        parse_selection "$reply" && break
    done
    printf '\n'
}

install_skill() {
    local target=$1 name=$2
    local src="$SKILLS_DIR/$name" dest="$target/$name"
    if [ -L "$dest" ]; then
        if [ "$(resolve_dir "$dest")" = "$src" ]; then
            printf '  %s= %s%s already linked\n' "$DIM" "$name" "$RST"
            n_current=$((n_current + 1))
            return
        fi
        ln -sfn -- "$src" "$dest"
        printf '  + %s %s(relinked from another location)%s\n' "$name" "$DIM" "$RST"
        n_updated=$((n_updated + 1))
        return
    fi
    if [ -e "$dest" ]; then
        printf '  %s! %s skipped: a real %s already exists there%s\n' \
            "$YLW" "$name" "$([ -d "$dest" ] && echo directory || echo file)" "$RST"
        n_skipped=$((n_skipped + 1))
        return
    fi
    ln -s -- "$src" "$dest"
    printf '  + %s\n' "$name"
    n_linked=$((n_linked + 1))
}

uninstall_skill() {
    local target=$1 name=$2
    local src="$SKILLS_DIR/$name" dest="$target/$name"
    if [ -L "$dest" ]; then
        if [ "$(resolve_dir "$dest")" = "$src" ]; then
            rm -- "$dest"
            printf '  - %s\n' "$name"
            n_removed=$((n_removed + 1))
        else
            printf '  %s! %s left alone: links outside this repo%s\n' "$YLW" "$name" "$RST"
            n_skipped=$((n_skipped + 1))
        fi
    elif [ -e "$dest" ]; then
        printf '  %s! %s left alone: a real %s, not our link%s\n' \
            "$YLW" "$name" "$([ -d "$dest" ] && echo directory || echo file)" "$RST"
        n_skipped=$((n_skipped + 1))
    else
        printf '  %s= %s not installed%s\n' "$DIM" "$name" "$RST"
        n_current=$((n_current + 1))
    fi
}

list_state() {
    local name agent dir dest state
    printf '%sSkills in %s%s\n\n' "$B" "$REPO_DIR" "$RST"
    for name in "${ALL_SKILLS[@]}"; do
        printf '  %s\n' "$name"
        for agent in claude codex; do
            dir=$(agent_dir "$agent")
            dest="$dir/$name"
            if [ -L "$dest" ] && [ "$(resolve_dir "$dest")" = "$SKILLS_DIR/$name" ]; then
                state='installed'
            elif [ -L "$dest" ]; then
                state='links elsewhere'
            elif [ -e "$dest" ]; then
                state='real directory, not ours'
            else
                state='-'
            fi
            printf '      %s%-12s %s%s\n' "$DIM" "$(agent_label "$agent")" "$state" "$RST"
        done
    done
}

UNINSTALL=0
LIST=0
AGENTS=()
SKILLS=()
args=()

while [ $# -gt 0 ]; do
    case $1 in
        -u|--uninstall) UNINSTALL=1 ;;
        -l|--list)      LIST=1 ;;
        -h|--help)      usage; exit 0 ;;
        -*)             die "unknown option: $1 (see $PROG --help)" ;;
        *)              args+=("$1") ;;
    esac
    shift
done

discover_skills

if [ "$LIST" = 1 ]; then
    list_state
    exit 0
fi

if [ "${#args[@]}" -gt 0 ]; then
    case ${args[0]} in
        claude) AGENTS=(claude) ;;
        codex)  AGENTS=(codex) ;;
        both)   AGENTS=(claude codex) ;;
        *)      die "first argument must be claude, codex, or both (got: ${args[0]})" ;;
    esac
    if [ "${#args[@]}" -gt 1 ]; then
        parse_selection "${args[*]:1}" || exit 1
    else
        SKILLS=("${ALL_SKILLS[@]}")
    fi
else
    choose_agent
    choose_skills
fi

n_linked=0; n_updated=0; n_current=0; n_skipped=0; n_removed=0

for agent in "${AGENTS[@]}"; do
    dir=$(agent_dir "$agent")
    printf '%s%s%s %s%s%s\n' "$B" "$(agent_label "$agent")" "$RST" "$DIM" "$dir" "$RST"
    if [ "$UNINSTALL" = 1 ]; then
        if [ ! -d "$dir" ]; then
            printf '  %s= nothing installed there%s\n\n' "$DIM" "$RST"
            continue
        fi
        for name in "${SKILLS[@]}"; do uninstall_skill "$dir" "$name"; done
    else
        mkdir -p -- "$dir"
        for name in "${SKILLS[@]}"; do install_skill "$dir" "$name"; done
    fi
    printf '\n'
done

if [ "$UNINSTALL" = 1 ]; then
    printf '%s%d removed%s, %d untouched' "$B" "$n_removed" "$RST" "$n_current"
else
    printf '%s%d linked%s, %d relinked, %d already current' \
        "$B" "$n_linked" "$RST" "$n_updated" "$n_current"
fi
[ "$n_skipped" -gt 0 ] && printf ', %s%d skipped%s' "$YLW" "$n_skipped" "$RST"
printf '\n'
