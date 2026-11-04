
## Deploys

Agents never change the live Worker: no `wrangler deploy`, `rollback`, `delete`, `secret put/delete`, `npm run deploy` or `scripts/setup.sh`. Your job ends with a PR; a person merges it, and Cloudflare Workers Builds deploys `main` automatically. If a change needs a new secret or a remote migration, say so in the PR. `wrangler deploy --dry-run` is fine for checking the build. The `easyrate-cloudflare` plugin (from claude-kit) has a hook that enforces this.
