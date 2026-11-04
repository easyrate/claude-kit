#!/usr/bin/env bash
# claude-kit installer: sets up Easyrate's Claude Code conventions in the current git repo.
#
#   curl -fsSL https://raw.githubusercontent.com/easyrate/claude-kit/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/easyrate/claude-kit/main/install.sh | bash -s -- --cloudflare
#
# Safe to re-run: it updates what it installed and leaves everything else alone.
# It never commits; review `git diff` and open a PR as usual.
set -euo pipefail

KIT_REPO="easyrate/claude-kit"
MARKETPLACE="claude-kit"
START="<!-- claude-kit:start (managed by claude-kit; edits here are overwritten on update) -->"
END="<!-- claude-kit:end -->"

cloudflare=0
ref=main
while [ $# -gt 0 ]; do
  case $1 in
    --cloudflare) cloudflare=1 ;;
    --ref) ref=$2; shift ;;
    -h|--help)
      echo "Usage: install.sh [--cloudflare] [--ref <branch|tag>]   (run from inside the target repo)"
      echo "Options: --cloudflare (also block wrangler deploys), --ref <branch|tag> (default main)"
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

for tool in git jq curl tar; do
  command -v "$tool" >/dev/null || { echo "claude-kit needs '$tool' installed." >&2; exit 1; }
done

root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Run this inside a git repository." >&2; exit 1; }
cd "$root"

# The kit's files: a local checkout when KIT_DIR is set (for testing), otherwise a download.
if [ -n "${KIT_DIR:-}" ]; then
  kit=$KIT_DIR
else
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://github.com/$KIT_REPO/archive/$ref.tar.gz" | tar -xz -C "$tmp" --strip-components=1
  kit=$tmp
fi
t="$kit/templates"

say() { printf '  %s\n' "$*"; }
echo "Installing claude-kit ($ref) into $root"

# owner/repo of this repository, for the CLAUDE.md snippet
remote=$(git remote get-url origin 2>/dev/null || true)
repo=$(printf '%s' "$remote" | sed -E 's#^(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')
if [ -z "$repo" ]; then
  repo="<owner>/<repo>"
  say "No 'origin' remote: CLAUDE.md says $repo; fix it by hand or add the remote and re-run."
fi

# 1. docs/agents: kit-owned files are updated; triage-labels.md is yours to edit, so only created once.
mkdir -p docs/agents
cp "$t/docs/agents/domain.md" "$t/docs/agents/issue-tracker.md" docs/agents/
if [ ! -f docs/agents/triage-labels.md ]; then cp "$t/docs/agents/triage-labels.md" docs/agents/; fi
say "docs/agents/ updated"

# 2. CLAUDE.md: replace the managed block, or append it.
block=$(mktemp)
{
  echo "$START"
  sed "s#{{REPO}}#$repo#g" "$t/CLAUDE.core.md"
  if [ "$cloudflare" = 1 ]; then cat "$t/CLAUDE.cloudflare.md"; fi
  echo "$END"
} > "$block"
touch CLAUDE.md
if grep -qF "claude-kit:start" CLAUDE.md; then
  awk -v blockfile="$block" '
    /claude-kit:start/ { while ((getline line < blockfile) > 0) print line; skip = 1; next }
    /claude-kit:end/   { skip = 0; next }
    !skip
  ' CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
else
  if [ -s CLAUDE.md ]; then printf '\n' >> CLAUDE.md; fi
  cat "$block" >> CLAUDE.md
fi
rm -f "$block"
say "CLAUDE.md managed block updated"

# 3. .claude/settings.json: register the marketplace and enable the plugins (other settings are kept).
mkdir -p .claude
[ -s .claude/settings.json ] || echo '{}' > .claude/settings.json
jq --arg m "$MARKETPLACE" --arg r "$KIT_REPO" --argjson cf "$cloudflare" '
  .extraKnownMarketplaces[$m] = {source: {source: "github", repo: $r}, autoUpdate: true}
  | .enabledPlugins["easyrate-core@" + $m] = true
  | if $cf == 1 then .enabledPlugins["easyrate-cloudflare@" + $m] = true else . end
' .claude/settings.json > .claude/settings.json.tmp && mv .claude/settings.json.tmp .claude/settings.json
say ".claude/settings.json: plugins enabled"

# 4. GitHub workflows: thin callers of the reusable workflows in claude-kit.
mkdir -p .github/workflows
for f in "$t"/workflows/*.yml; do
  sed "s#@main\$#@$ref#" "$f" > ".github/workflows/$(basename "$f")"
done
say ".github/workflows/: claude.yml, claude-code-review.yml, thermo-nuclear-review.yml"

# 5. .gitignore: Claude Code worktrees
if ! grep -qxF ".claude/worktrees/" .gitignore 2>/dev/null; then
  echo ".claude/worktrees/" >> .gitignore
  say ".gitignore: added .claude/worktrees/"
fi

# 6. GitHub: review label and secret check (needs gh; skipped quietly without it)
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && [ "$repo" != "<owner>/<repo>" ]; then
  if gh label create agent-review --repo "$repo" --color 5319e7 \
       --description "Runs the Claude code reviews" --force >/dev/null 2>&1; then
    say "GitHub label 'agent-review' ready"
  fi
  if ! gh secret list --repo "$repo" --json name -q '.[].name' 2>/dev/null | grep -qx CLAUDE_CODE_OAUTH_TOKEN; then
    echo
    echo "  ! No CLAUDE_CODE_OAUTH_TOKEN secret on $repo (an org-level one also works)."
    echo "    Create a token with 'claude setup-token', then: gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo $repo"
  fi
fi

echo
echo "Done. Review the changes, then commit them on a branch and open a PR:"
git status --short -- CLAUDE.md .claude/settings.json docs/agents .github/workflows .gitignore | sed 's/^/  /'
