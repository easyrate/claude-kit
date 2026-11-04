#!/usr/bin/env bash
# PreToolUse hook (Bash): stop agents from changing the live Worker.
# Code reaches production through a PR merged to main; deploys, rollbacks and
# secrets are done by a person. `wrangler deploy --dry-run` is allowed (build check).

cmd=$(jq -r '.tool_input.command // ""')

# A command segment starts at line start or after ; & | ( (so text inside e.g. a commit message doesn't count)
start='(^|[;&|(])[[:space:]]*'
wrangler="${start}((npx|bunx)[[:space:]]+)?wrangler[[:space:]]+"
end='([[:space:]]|$|[;&|)])'
changes_live="${wrangler}(publish|rollback|delete|versions[[:space:]]+deploy|secret[[:space:]]+(put|delete|bulk))${end}"
deploy="${wrangler}deploy${end}"
scripts="${start}(npm[[:space:]]+run[[:space:]]+(deploy|setup)|(bash|sh)[[:space:]]+([^[:space:]]*/)?setup\.sh|\./scripts/setup\.sh)${end}"

blocked=0
printf '%s' "$cmd" | grep -Eq "$changes_live" && blocked=1
printf '%s' "$cmd" | grep -Eq "$scripts" && blocked=1
# A dry run builds without uploading
if printf '%s' "$cmd" | grep -Eq "$deploy" && ! printf '%s' "$cmd" | grep -Eq -- '--dry-run'; then blocked=1; fi

if [ "$blocked" = 1 ]; then
  echo "Agents must not deploy or change the live Worker (deploy, rollback, delete, secrets). Open a PR and get it merged to main; a person handles deploys and secrets. 'wrangler deploy --dry-run' is allowed to check the build." >&2
  exit 2
fi
exit 0
