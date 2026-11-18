---
name: security-review
description: Review a branch or pull request's changes for exploitable security vulnerabilities (injection, auth and access-control flaws, secrets, unsafe data handling, SSRF, XSS, insecure config). Use for a security review, security audit of a PR, or vulnerability check of the current changes.
disable-model-invocation: true
---

# Security Review

Review the changes on the current branch or pull request for security vulnerabilities that the change **introduces or makes reachable**. Do not audit the whole codebase; read surrounding code only to judge whether a changed line is exploitable.

The goal is a short list of real, exploitable issues. A review with zero findings is a good outcome when the change is safe. A false positive costs the author time and trains people to ignore the review, so every finding must survive the verification step below.

## Process

1. **Get the diff.** On a PR use `gh pr diff <number>`; locally use `git diff <base>...HEAD`. Note which files are server code, client code, config, migrations, CI and infrastructure.
2. **Understand the context.** For each changed area, find where its inputs come from (request bodies, query params, headers, cookies, webhooks, URL params, files, env, third-party APIs, the database) and where they go (SQL/ORM queries, HTML, shell, file paths, outbound HTTP, redirects, logs, responses). Find the auth and authorization middleware the route actually runs behind, and the project's existing helpers for validation, escaping and access checks.
3. **Look for vulnerabilities** in the categories below.
4. **Verify each candidate.** For every candidate finding, trace a concrete path: who the attacker is (anonymous user, logged-in user of another tenant, malicious webhook sender, ...), the exact input they control, the code path it takes, and what they gain. Drop it if any step is speculative, if an existing check already blocks it, or if the framework handles it safely by default (e.g. React escaping text, Prisma parameterising queries).
5. **Report** only what survived, ranked by severity.

## What to Look For

**Injection**
- SQL built by string concatenation or template literals; `$queryRawUnsafe`, `$executeRawUnsafe`, `sql.raw`, or similar raw escapes with user input.
- Shell commands built from input (`exec`, `execSync`, `spawn` with `shell: true`).
- Path traversal: user input in file paths, archive extraction, or storage keys (R2/S3) without normalisation.
- Template, header (CRLF) or log injection where it has a real effect.
- `eval`, `new Function`, dynamic `import()` or `require()` of user-controlled strings.

**Authentication and authorization**
- New routes, server actions, API handlers or webhooks that skip the auth check other routes have.
- Missing ownership or tenant checks: fetching or mutating a record by ID without checking it belongs to the caller (IDOR).
- Role checks done only on the client.
- Webhook endpoints that don't verify the signature, or verify it with a non-constant-time comparison.
- Session and token problems: tokens in URLs, missing expiry, JWTs verified without pinning the algorithm, weak password reset or magic-link flows, predictable IDs used as secrets.

**Secrets and sensitive data**
- Hard-coded API keys, tokens, passwords or private keys (also in tests, fixtures and config).
- Server secrets reaching the client: `NEXT_PUBLIC_`/`VITE_`/`PUBLIC_` env vars holding secrets, secrets serialised into props or responses.
- Responses that return more fields than needed (password hashes, tokens, other users' PII).
- Secrets or PII written to logs or error messages returned to the client.

**Web-specific**
- XSS: `dangerouslySetInnerHTML`, `innerHTML`, `v-html`, `{@html}`, unescaped template output, or user input in `href`/`src` allowing `javascript:` URLs.
- SSRF: server-side fetches to user-supplied URLs without an allowlist.
- Open redirects from user-controlled redirect targets.
- CSRF on state-changing endpoints that rely on cookies without SameSite or a token.
- CORS that reflects any origin with credentials, or `*` on authenticated endpoints.
- Weakened security headers or CSP, or cookies missing `HttpOnly`/`Secure` where it matters.

**Data handling and logic**
- Missing input validation at a trust boundary where it leads to a concrete exploit (mass assignment of `role`/`isAdmin`/`price`, negative quantities, unbounded sizes).
- Unsafe deserialisation or YAML loading of untrusted data.
- Prototype pollution through deep merges of user input.
- Race conditions with a security impact (double spend, redeeming a coupon twice).
- Weak cryptography: `Math.random()` for tokens, MD5/SHA1 for passwords, homemade crypto, static IVs.

**Config, dependencies and CI**
- New dependencies that are typosquats, unmaintained, or have known critical advisories.
- GitHub Actions: `pull_request_target` or `workflow_run` checking out and running PR code, untrusted `${{ github.event.* }}` interpolated into `run:` scripts, over-broad `permissions`, secrets exposed to forks.
- Debug modes, permissive defaults or disabled TLS verification left enabled in production config.
- Infrastructure (wrangler.toml, Dockerfiles, IaC) that makes storage, databases or admin routes public.

## Do Not Report

- Denial of service, rate limiting, or resource exhaustion, unless trivially exploitable with severe impact.
- Missing hardening that has no concrete exploit in this change ("consider adding validation").
- Issues only in test files, unless they leak a real secret.
- Outdated dependencies without a known exploitable advisory affecting how they are used.
- Theoretical issues that need an already-compromised server, admin access, or physical access.
- Code quality, style, or performance. Other reviews cover those.
- Pre-existing vulnerabilities in lines the change does not touch, unless the change makes them newly reachable.

## Severity

- **Critical:** directly exploitable by an unauthenticated attacker for account takeover, data breach, remote code execution, or payment fraud.
- **High:** exploitable by a normal authenticated user to reach other users' or tenants' data, escalate privileges, or leak secrets.
- **Medium:** real but needs unusual conditions, user interaction (most XSS), or has limited impact.

Leave out anything you would rate below Medium.

## Output

For each finding give:

- **Title and severity**
- **Location:** file and line
- **Exploit:** the concrete attacker, input and path from the verification step, in two or three sentences
- **Fix:** the specific change, using the project's existing helpers where they exist

Then give a verdict: **No security issues found**, or **Blocking** (any Critical or High finding) / **Non-blocking** (Medium only), with the count per severity.
