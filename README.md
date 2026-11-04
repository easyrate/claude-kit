# claude-kit

Easyrate's shared Claude Code setup: skills, guardrail hooks, agent docs and GitHub workflows. Install it once per repo; skills, hooks and workflow logic then update on their own when this repo changes.

## Install

Run from the root of the target repo:

```sh
curl -fsSL https://raw.githubusercontent.com/easyrate/claude-kit/main/install.sh | bash
```

For a Cloudflare Workers repo, which also blocks agents from deploying:

```sh
curl -fsSL https://raw.githubusercontent.com/easyrate/claude-kit/main/install.sh | bash -s -- --cloudflare
```

If feature PRs in the repo target another branch than `main` (e.g. `dev`), add `--base dev`. The `CLAUDE.md` text then says to branch off `dev` and open PRs against it, and later runs remember it:

```sh
curl -fsSL https://raw.githubusercontent.com/easyrate/claude-kit/main/install.sh | bash -s -- --base dev
```

Needs `git`, `jq` and `curl`. `gh` is optional; with it the installer also creates the `agent-review` label and checks the secret. The installer never commits: review `git diff`, then commit on a branch and open a PR.

Then make sure the repo (or the org) has the `CLAUDE_CODE_OAUTH_TOKEN` secret. The installer tells you if it's missing:

```sh
claude setup-token                                   # prints a token
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<repo>
```

Re-running the command is safe. It updates what it installed and leaves the rest alone.

## What you get

| What | Where it lives | How it updates |
| --- | --- | --- |
| `easyrate-core` plugin: hook that blocks `git push` to `main`; `/easyrate-core:thermo-nuclear-code-quality-review` skill | `plugins/easyrate-core` | Automatically (plugin auto-update) |
| `easyrate-cloudflare` plugin (`--cloudflare`): hook that blocks `wrangler deploy`, `rollback`, `delete`, `secret put/delete`, `npm run deploy`, `scripts/setup.sh`. `wrangler deploy --dry-run` is allowed | `plugins/easyrate-cloudflare` | Automatically |
| GitHub workflows: `@claude` in issues and PRs; Claude Code Review and the thermo-nuclear review when a PR gets the `agent-review` label | Logic in `.github/workflows/` here; each repo has short caller files | Automatically (reusable workflows, `@main`) |
| `docs/agents/*.md` (issue tracker, triage labels, domain docs) for the mattpocock skills | Copied into the repo | Re-run the install command |
| `CLAUDE.md` section on agent skills, the git workflow and deploys | Between `<!-- claude-kit:start -->` and `<!-- claude-kit:end -->` in the repo's `CLAUDE.md` | Re-run the install command |

What the installer changes in the target repo:

- `.claude/settings.json`: registers this marketplace (`extraKnownMarketplaces`, with `autoUpdate`) and enables the plugins (`enabledPlugins`). Other settings are kept.
- `CLAUDE.md`: adds or replaces the managed block. Write your own text outside the markers. If `CLAUDE.md` is a symlink (e.g. to `AGENTS.md`), it becomes a real file that imports the target (`@AGENTS.md`), so the target file is never changed.
- `docs/agents/`: `domain.md` and `issue-tracker.md` are overwritten. `triage-labels.md` is only created if it's missing, so you can edit the label names.
- `.github/workflows/claude.yml`, `claude-code-review.yml`, `thermo-nuclear-review.yml`: overwritten with callers of the workflows here.
- `.gitignore`: adds `.claude/worktrees/`.

## For teammates

When you open a repo that has the kit and trust the folder, Claude Code fetches this marketplace and the enabled plugins in the background. Check with `/plugin`. If a plugin shows as "enabled in project settings but isn't installed here", install it there, or run:

```
/plugin marketplace add easyrate/claude-kit
/plugin install easyrate-core@claude-kit
```

Updates arrive at most ten minutes into a session and take effect on the next launch or after `/reload-plugins`.

## Changing the kit

- **Skill or hook:** edit it under `plugins/`. There is no `version` in `plugin.json` on purpose, so every commit to `main` is a new version for everyone.
- **Workflow:** edit `.github/workflows/` here (the reusable part). Triggers and permissions sit in `templates/workflows/` and only reach a repo when the install command is re-run. A caller's permissions cap what the reusable workflow can get, so a new permission must be added in both places.
- **CLAUDE.md text or agent docs:** edit `templates/`. Repos pick it up when they re-run the install command.
- Check plugin manifests with `claude plugin validate ./`.
- Test the installer against a local checkout: `KIT_DIR=/path/to/claude-kit bash /path/to/claude-kit/install.sh` from inside a test repo.

Pin a repo to a tag instead of `main` with `--ref v1`. That pins the workflow callers and the downloaded templates; plugins always follow `main`.
