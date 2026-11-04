#!/usr/bin/env bash
# PreToolUse hook (Bash): stop agents from pushing directly to main.
# Changes reach main through a pull request instead.

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# "git push" or "git -C <dir> push"
push='git([[:space:]]+-C[[:space:]]+[^[:space:];&|]+)?[[:space:]]+push'

# Only look at git push commands.
printf '%s' "$cmd" | grep -Eq "(^|[;&|[:space:]])$push" || exit 0

# Words after "git push" that aren't flags: [remote] [refspec...]
args=$(printf '%s' "$cmd" | sed -nE "/$push/{s/.*$push//; s/[;&|].*//; p;}" | tr ' ' '\n' | grep -v '^-' | grep -v '^$')
nargs=$(printf '%s\n' "$args" | grep -c .)

# The directory the push runs in: the command's working directory, then the last "cd <dir>" before
# the push, then "git -C <dir>". A worktree has its own branch, so the project folder's branch can differ.
dir=$(printf '%s' "$input" | jq -r '.cwd // empty')
dir=${dir:-${CLAUDE_PROJECT_DIR:-.}}
follow() {
  local p=${1//[\"\']/}
  case $p in
    "~"*) p="$HOME${p#\~}" ;;
    /*) ;;
    *) p="$dir/$p" ;;
  esac
  dir=$p
}
before=$(printf '%s' "$cmd" | sed -E "s/$push.*//")
cd_dir=$(printf '%s' "$before" | grep -oE '(^|[;&|[:space:]])cd[[:space:]]+[^[:space:];&|]+' | tail -1 | sed -E 's/.*cd[[:space:]]+//')
[ -n "$cd_dir" ] && follow "$cd_dir"
c_dir=$(printf '%s' "$cmd" | grep -oE "$push" | head -1 | sed -nE 's/.*-C[[:space:]]+([^[:space:]]+).*/\1/p')
[ -n "$c_dir" ] && follow "$c_dir"
branch=$(git -C "$dir" branch --show-current 2>/dev/null || git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null)

blocked=0
# An explicit refspec targeting main: "main", "HEAD:main", "x:refs/heads/main", "+main"
printf '%s\n' "$args" | sed 1d | grep -Eq '(^|[:+/])main$' && blocked=1
# No refspec given while on main: pushes main.
if [ "$nargs" -le 1 ] && [ "$branch" = main ]; then
  blocked=1
fi

if [ "$blocked" = 1 ]; then
  echo "Pushing directly to main is not allowed. Create a branch (git switch -c <type>/<name>), push it, and open a PR with gh pr create." >&2
  exit 2
fi
exit 0
