## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues ({{REPO}}) via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Git workflow

Never push directly to `main`; every change reaches `main` through a pull request. Before coding, branch off an up-to-date `main` (`git switch main && git pull && git switch -c <type>/<short-name>`, e.g. `feat/meta-pixel-stats`, `fix/consent-check`), push the branch, and open a PR with `gh pr create`. The `easyrate-core` plugin (from claude-kit) has a hook that enforces this.
