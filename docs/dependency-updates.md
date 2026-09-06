# Dependency updates - Renovate + an AI fixer

Keep **every** kind of dependency current across many repositories, and let an
agent repair the breaking changes that turn CI red.

> A **dependency update** is one of the two kinds of
> [AI Automation](./ai-automations.md) in this repository. The other kind,
> [report updates](./report-updates.md), keeps a *document* up to date with a
> scheduled agent run - same idea, different requirements and implementation.
> The contrast is the point: here the AI is not the one doing the work, it only
> repairs what breaks.

1. [Motivation and context](#1-motivation-and-context)
2. [Solution architecture](#2-solution-architecture)
3. [Quick start for the impatient](#3-quick-start-for-the-impatient)
4. [Digging into the details](#4-digging-into-the-details)

---

# 1. Motivation and context

## The problem

Dependency management tooling is built around package manifests — `package.json`,
`pom.xml`, `go.mod`. But a real project depends on far more than that:

- Docker images in `docker-compose.yml` or as a `FROM` base in a Dockerfile.
- Tools installed inside a Dockerfile (linters, CLIs, build helpers) whose
  version lives in an `ENV` line.
- Browser versions inside the dockerized browsers that Selenium or Playwright
  drive.
- The GitHub Actions used by your own workflows.

Two things make this harder than "bump the number":

**Some upgrades need a command.** Bumping `@angular/core` in `package.json`
without running `ng update` leaves the repository in a state that compiles by
accident, if at all.

**Some upgrades break the build.** A major version ships a breaking change, or a
bugfix surfaces a latent assumption in your tests. Someone has to sit down and
adapt the code. In practice that someone is nobody, the pull request rots, and
six months later a security patch is stuck behind a wall of stale updates.

## What we want

A pipeline that runs on a schedule and, without human involvement up to the
point of review:

1. Detects new versions of **all** dependency types, not just manifests.
2. Opens a pull request so the existing CI runs against it.
3. When CI fails, has an agent read the failure, adapt the application code,
   and push a fix that re-triggers CI.
4. Gives up cleanly and asks for a human when it can't.

## Our environment

The design decisions in this document follow from these constraints. If yours
differ, the [deep dive](#4-digging-into-the-details) explains which choice
depends on which constraint.

| Constraint | Consequence |
|---|---|
| GitHub **Free** plan | Organization secrets don't reach private repos; secrets go per-repo |
| A mix of **public and private** repos | The shared workflow repo must be public |
| **Many** repositories | Everything is centralized and deployed by script |
| Org policy: **SHA-pinned actions** | Every `uses:` is a 40-char commit SHA |
| **Existing CI** we don't want to edit | The fixer hooks in via `workflow_run`, not by editing `ci.yml` |
| **Claude Code** as the agent | Reads `CLAUDE.md`, runs shell commands, edits files |

## Why not an off-the-shelf product

No single tool does the whole loop today. The closest options and where they
stop:

- **[Dependabot with an assigned agent](https://github.blog/changelog/)**
  (Copilot, Claude or Codex): the agent analyzes the vulnerability, opens a
  draft PR and tries to resolve failing tests. But it triggers from **security
  alerts** only, not from routine updates.
- **[gh-aw](https://github.com/github/gh-aw)** (GitHub Agentic Workflows):
  agents defined in Markdown with YAML frontmatter that compile to standard
  Actions workflows, with imports for sharing across repos. Public Preview. A
  good option if you plan to run several agents; worth revisiting later.
- **[Infield](https://www.infield.ai/)**: a managed service that takes on
  breaking-change remediation, but only for Ruby, JavaScript/TypeScript and
  Python. Doesn't touch Docker or build tooling.

So we assemble it: Renovate for detection, our own reusable workflow for the
repair.

---

# 2. Solution architecture

## The moving parts

```
┌───────────────────────────────────────────────────────────────────┐
│  1. Renovate  ·  .github/workflows/renovate.yml  (weekly cron)    │
│     Detects new versions → edits manifests and lockfiles          │
│     → opens a PR from a `renovate/…` branch                       │
└─────────────────────────────┬─────────────────────────────────────┘
                              ▼
┌───────────────────────────────────────────────────────────────────┐
│  2. Your existing CI  ·  (on: pull_request)                       │
│     Untouched. Not one line.                                      │
└─────────────────────────────┬─────────────────────────────────────┘
                              ▼  workflow_run · conclusion=failure
┌───────────────────────────────────────────────────────────────────┐
│  3. AI Fix  ·  .github/workflows/ai-fix.yml  (new file)           │
│     15 identical lines in every repo. It only delegates:          │
│     uses: OpenVidu/actions/.github/workflows/renovate-ai-fix.yml  │
└─────────────────────────────┬─────────────────────────────────────┘
                              ▼
┌───────────────────────────────────────────────────────────────────┐
│  4. Centralized reusable workflow  ·  OpenVidu/actions            │
│     Resolves the PR → downloads logs → the agent reads            │
│     .github/workflows/ and the changelog → adapts application     │
│     code → commits with a GitHub App token                        │
└─────────────────────────────┬─────────────────────────────────────┘
                              ▼
              The push re-triggers CI (step 2) and the cycle
              repeats up to `max-attempts`.

              green?     → ready for human review
              exhausted? → draft + `needs-human` label
```

## What Renovate does, and what it doesn't

[Renovate](https://docs.renovatebot.com/) is open source (AGPL-3.0), owned by
Mend.io. It's available as a hosted app, but we run it **self-hosted as a
GitHub Action** in each repository, because the hosted app can't run arbitrary
commands.

Its job in this pipeline:

1. **Detect** a newer version by querying the right datasource — npm, Maven
   Central, Docker Hub, GitHub Releases, and about 90 more.
2. **Edit the manifest** — the version string in `package.json`, `pom.xml`,
   `Dockerfile`, `docker-compose.yml`, workflow files.
3. **Update the lockfile** if one exists, reinstalling so it stays consistent.
4. **Open a PR** with the changelog in the description.

By default it does **not** run migration commands or touch your source code. If
`@angular/core` jumps a major, plain Renovate changes the number but does not run
`ng update` and does not adapt your code to the breaking change.

We close part of that gap with a **migration catalog** (covered in
[Migration commands](#migration-commands-ng-update-and-friends)): a small,
centrally maintained list of `packageRules` that make Renovate run the official
codemod — `ng update` and similar — for the specific dependencies where one
exists, before the PR ever reaches CI. It only covers what has an official,
deterministic tool. Everything else — the breaking changes with no codemod,
which is most of them — is still not something Renovate touches.

That remaining gap is what the AI fixer exists for.

## The AI fixer

A second workflow watches for a failed CI run on a Renovate branch. When one
appears, it hands the agent three things: the **failure logs**, the repository
**checked out at the PR branch**, and the **diff of the update**.

Deliberately, it does **not** hand over the build and test commands. The agent
reads `.github/workflows/` and figures them out. Passing them as inputs would
duplicate what's already in the CI file and drift out of sync. See
[Why the agent discovers the commands](#why-the-agent-discovers-the-commands).

## CI is the oracle

The agent does not try to reproduce your CI environment. It reproduces what it
can — in a plain Node or Java repo without service containers, that's
everything — and where it can't, it makes the fix from the log and the changelog
and lets the pipeline rule on it. See
[Why the agent can't just replay the workflow](#why-the-agent-cant-just-replay-the-workflow).

## One central repo, two roles

`OpenVidu/actions` (public) holds both halves of the shared machinery:

| Path | Contains | Consumed as |
|---|---|---|
| `.github/workflows/renovate-run.yml` | How Renovate is invoked, including its allowlist | Reusable workflow at `@v1` |
| `.github/workflows/renovate-ai-fix.yml` | The whole fixer: prompt, log collection, retry counter | Reusable workflow at `@v1` |
| `dependency-updates/renovate/default.json` | All Renovate policy, rules and migration commands | Shared preset via `extends` |

They're deployed and versioned together, which matters more than it sounds: a
change to the prompt and a change to a migration rule usually belong to the same
piece of work.

Each managed repository gets three small, **identical** files. Everything that
evolves lives in `OpenVidu/actions`.

---

# 3. Quick start for the impatient

> **One repo or many?** This section walks through a single repository, by
> hand, so you can see every piece. If you're rolling this out across an
> organization, the scripts that do all of it in a loop are in
> [Mass deployment](#mass-deployment).

> **Why, not just how.** Every choice here — public repos, per-repo secrets,
> the `workflow_run` trigger, the App token — has a reason, and some have sharp
> edges. They're all explained in
> [Digging into the details](#4-digging-into-the-details). If something looks
> arbitrary, it's covered there.

## What you need

- An Anthropic API key.
- The [`gh` CLI](https://cli.github.com/), authenticated with admin rights.

## Step 1 — Create a GitHub App

Settings → Developer settings → GitHub Apps → New GitHub App.

Repository permissions:

- Contents: **Read and write**
- Pull requests: **Read and write**
- Actions: **Read only**
- Metadata: **Read only**

Generate a **private key** (`.pem`), note the **App ID**, and install the App on
your repositories.

This App is not optional, and it must be a **different identity from Renovate's**.
Both reasons are in [Why a GitHub App](#why-a-github-app).

## Step 2 — Add the secrets to the repository

```bash
gh secret set ANTHROPIC_API_KEY --repo OpenVidu/openvidu-meet --body 'sk-ant-...'
gh secret set BOT_APP_ID        --repo OpenVidu/openvidu-meet --body '123456'
gh secret set BOT_PRIVATE_KEY   --repo OpenVidu/openvidu-meet < ~/keys/ai-fixer.pem
gh secret set RENOVATE_TOKEN    --repo OpenVidu/openvidu-meet --body 'ghp_...'
```

The private key goes in through **stdin**. Passing it with `--body` mangles the
multi-line value.

Organization secrets would be nicer, but on the Free plan they don't reach
private repositories — see [Why per-repo secrets](#why-per-repo-secrets).

## Step 3 — Set up `OpenVidu/actions`

Everything shared lives here, and nothing in it needs to be redeployed when it
changes. These paths already exist in this repository, alongside the composite
actions it hosts:

```
OpenVidu/actions/
├── .github/workflows/
│   ├── renovate-run.yml           ← reusable: runs Renovate
│   └── renovate-ai-fix.yml        ← reusable: the AI fixer
├── dependency-updates/
│   ├── renovate/default.json      ← all Renovate policy and migration rules
│   ├── templates/                 ← the files deployed into each repo
│   └── scripts/                   ← deployment scripts
├── docs/                          ← this document and its siblings
└── run-report-update/             ← the other AI Automation: report updates
```

The two reusable workflows are the exception to that grouping. GitHub only
resolves a reusable workflow that sits **directly** in `.github/workflows/` —
not in a subdirectory of it, and not anywhere else in the repository — so they
cannot be filed under `dependency-updates/` with everything else.

> **Before the first run: resolve the action pins.** The two reusable workflows
> ship with `<SHA_*>` tokens where three third-party actions go, so a stale hash
> can never be copied from an example. They will fail until you resolve them:
>
> ```bash
> ./dependency-updates/scripts/pin-actions.sh    # needs gh, resolves in place and into build/
> git commit -am "chore: pin renovate workflow actions"
> ```
>
> `actions/checkout` is already pinned to the SHA this repository uses
> everywhere else. Details in [SHA pinning](#sha-pinning).

### The fixer: `.github/workflows/renovate-ai-fix.yml`

**→ [`.github/workflows/renovate-ai-fix.yml`](../.github/workflows/renovate-ai-fix.yml)**

What it does, in order: mints a GitHub App token, resolves the PR from the branch
(`workflow_run` does not hand it over), counts the bot's previous commits to know which
attempt this is, gives up into a draft + `needs-human` label when they run out, checks out
the PR branch, dumps the failed job's log to `/tmp/ci/`, and hands all of that to the agent
with the prompt that tells it to discover the CI commands itself and never touch tests,
manifests or lockfiles.

Two things about it:

**It ships with `<SHA_*>` placeholders**, deliberately invalid so a stale hash can never be
copied out of an example. `pin-actions.sh` resolves them, or you can do it by hand — keep
the version comment, which Renovate needs:

```bash
gh api repos/actions/checkout/commits/v4 --jq .sha
```

The result looks like `actions/checkout@<40 hex chars>   # v6.0.2`. Details and a
script in [SHA pinning](#sha-pinning).

**Enable Renovate on `OpenVidu/actions` too**, so those pins don't rot. It gets the same
three files as any other repo, and its `renovate.json` extends its own preset:

```json
{ "extends": ["local>OpenVidu/actions//dependency-updates/renovate/default.json"] }
```

The self-reference looks odd but is valid, and it means the policy repo is held
to the same policy as everything else. Note this repository already ships a
`.github/dependabot.yml`; running both bots against the same manifests produces
duplicate PRs, so retire one of them before enabling Renovate here.

### The Renovate policy: `dependency-updates/renovate/default.json`

**→ [`dependency-updates/renovate/default.json`](../dependency-updates/renovate/default.json)**

It extends `config:recommended` and `helpers:pinGitHubActionDigests`, sets the schedule,
labels and `prConcurrentLimit`, pulls security updates out of groups, declares the
`customManager` that reads the `# renovate:` comments described in
[Step 5](#step-5--annotate-versions-and-discover-migrations), and carries the `packageRules`
— among them the **migration catalog**: the rules that make Renovate run a framework's own
codemod while preparing the PR, so the branch arrives at CI already migrated. Today the only
entry is Angular; add one per framework that ships an official migration tool. Each rule only
fires where the package exists, so it is inert everywhere else. See
[Migration commands](#migration-commands-ng-update-and-friends).

### The Renovate runner: `.github/workflows/renovate-run.yml`

Renovate is invoked through a reusable workflow too, so its environment — most
importantly the command allowlist — lives here and never has to be redeployed.

**→ [`.github/workflows/renovate-run.yml`](../.github/workflows/renovate-run.yml)**

Short, and almost all of it is the environment Renovate runs in — most importantly
`RENOVATE_ALLOWED_COMMANDS` and `RENOVATE_ALLOW_POST_UPGRADE_COMMAND_TEMPLATING`.

`github.repository` inside a reusable workflow resolves to the **calling** repo,
so `RENOVATE_REPOSITORIES` and the checkout both point at the right place with
no inputs.

Without those two `RENOVATE_ALLOWED_*` variables the `postUpgradeTasks` in the
preset are silently skipped. They have to be here, in a workflow, because
`allowedCommands` is a **global** Renovate option that cannot be set from a
repository config or a preset — which is precisely why the workflow is reusable.
See [Why the Renovate workflow is reusable too](#why-the-renovate-workflow-is-reusable-too).

### Publish the version tag

Consumer repos reference the reusable workflows as `@v1`, a **moving** major
tag, so that a change here reaches every repository on its next run with nothing
redeployed. That tag is separate from this repository's `v1.0.x` release tags,
which pin its composite actions, and it has to be moved on every release that
touches `renovate-run.yml`, `renovate-ai-fix.yml` or the preset:

```bash
git tag -f v1 && git push -f origin v1
```

If you would rather not maintain a moving tag, pin the two `uses:` lines in
`dependency-updates/templates/*.yml` to a release tag instead — at the price of redeploying those
files across the organisation on every change.

## Step 4 — Add three files to the target repo

All three live in [`dependency-updates/templates/`](../dependency-updates/templates/) and
are deployed from there — never edited per repository. They are byte-identical everywhere,
and two of them are pure wrappers that delegate to `OpenVidu/actions`. Once deployed, none
of them needs to change again.

| File in the target repo | Template | What it is |
|---|---|---|
| `renovate.json` | [`templates/renovate.json`](../dependency-updates/templates/renovate.json) | Three lines: extends the shared preset |
| `.github/workflows/renovate.yml` | [`templates/renovate.yml`](../dependency-updates/templates/renovate.yml) | The weekly cron that wakes Renovate, delegating to `renovate-run.yml@v1` |
| `.github/workflows/ai-fix.yml` | [`templates/ai-fix.yml`](../dependency-updates/templates/ai-fix.yml) | The `workflow_run` trigger and its filter, delegating to `renovate-ai-fix.yml@v1` |

Deploy them with [`scripts/bootstrap.sh`](../dependency-updates/scripts/bootstrap.sh), which
resolves the SHA tokens into `build/` first and deploys from there — see
[Mass deployment](#mass-deployment).

Four things about them are worth knowing before you deploy:

> Here `renovate.json` is correct and **not** deprecated. The deprecation
> applies only to the preset filename inside a preset repo.

**The cron in `renovate.yml` is only a wake-up call.** The real cadence policy is
`schedule` in the shared preset, which decides when Renovate may actually open or update
PRs. If your Actions minutes allow it, a more frequent cron gives the central policy finer
control; on private repos under the Free plan, weekly is the safe default.

**Set the `workflows:` list in `ai-fix.yml` to match your repos.** It names the CI workflows
whose failure wakes the fixer, it's mandatory — omit it and GitHub rejects the file — and
names that don't exist in a given repo simply never fire, so one common list works
everywhere. **Never list `"AI Fix"` in it**: it would trigger itself in a loop. To see the
real names you have:

```bash
gh api repos/OpenVidu/openvidu-meet/actions/workflows --jq '.workflows[].name'
```

**`ai-fix.yml` must land on the default branch.** `workflow_run` won't register it
otherwise. See [How workflow_run actually behaves](#how-workflow_run-actually-behaves).

## Step 5 — Annotate versions and discover migrations

This one-time pass does two things: it annotates the hardcoded versions Renovate
can't see, and it reports which **migration commands** this repo needs so you can
add them to the catalog in `dependency-updates/renovate/default.json`.

Renovate handles manifests, `FROM` lines and `image:` keys natively. Tool
versions pinned in `ENV` lines need a `# renovate:` comment telling it where to
look. Doing that by hand across an old repository is tedious and lossy, so hand
it to the agent.

Run this **once per repo**, from the repository root, with Claude Code:

````text
Your task is to annotate this repository so Renovate can manage the versions it
currently cannot see. You are NOT updating any version: you only add comments
telling Renovate where to look.

## 1. What to look for

Search the repository for hardcoded third-party software versions that Renovate
does not manage natively. The usual places:

- Dockerfiles: `ENV *_VERSION=`, `ARG *_VERSION=`, and downloads with the
  version embedded in the URL (`curl -L https://.../v1.2.3/...`).
- Tool installs in scripts: `.sh`, `Makefile`, `justfile`, `Taskfile.yml`.
- Tool versions in CI workflows that are not a `uses:` (for example a
  `TERRAFORM_VERSION` in an `env:` block).
- Your own config files that pin versions of external binaries.

## 2. What NOT to touch

Renovate already manages these natively. Annotating them adds noise and can
break detection:

- `FROM image:tag` in Dockerfiles.
- `image:` in docker-compose and Kubernetes manifests.
- `uses:` in GitHub Actions workflows.
- package.json, pom.xml, build.gradle, go.mod, requirements.txt, Gemfile,
  Cargo.toml and any other standard manifest.
- Versions that are NOT third-party software: your own application version,
  database schema versions, internal release numbers.

If you are unsure whether something is a real external dependency, do NOT
annotate it and record it in the final report.

## 3. Comment format

The comment goes on the line IMMEDIATELY ABOVE the version:

    # renovate: datasource=<DS> depName=<NAME> [versioning=<V>] [extractVersion=<REGEX>]
    ENV TOOL_VERSION=1.2.3

Non-negotiable formatting rules:
- Exactly one comment line per version, with no blank line in between.
- Do not modify any version value. Not one.
- Do not reorder or reformat anything else in the file.
- Use the comment character of the file's language (`#` for Dockerfile, shell,
  Makefile and YAML).

## 4. Choosing the datasource

| Where the tool comes from | datasource | depName |
|---|---|---|
| GitHub release (binary assets) | `github-releases` | `owner/repo` |
| GitHub tag with no releases | `github-tags` | `owner/repo` |
| npm package | `npm` | package name |
| PyPI package | `pypi` | package name |
| Maven artifact | `maven` | `groupId:artifactId` |
| Container image | `docker` | `repo/image` |
| Node.js runtime | `node-version` | `node` |
| Java/JDK | `java-version` | `java` |
| Go toolchain | `golang-version` | `golang` |
| Product lifecycle | `endoflife-date` | product slug |
| System package (apt/apk) | `repology` | `<repo>/<package>` |

Verify every `depName` before writing it: confirm the repository or package
actually exists and that its published versions have the same shape as the
current value in the file.

Cases that need an extra field:
- If tags are prefixed (`v1.2.3`) but the file stores `1.2.3`, add
  `extractVersion=^v(?<version>.*)$`.
- If the versioning scheme is not semver, add the right `versioning=`
  (`loose`, `docker`, `node`, `maven`, `regex:...`).

## 5. Compatibility with the organization's customManager

The customManager in `dependency-updates/renovate/default.json` matches exactly this shape:

    # renovate: datasource=... depName=... [versioning=...]
    ENV <SOMETHING>_VERSION=<value>

For each version you annotate, decide and record in the report:
- **Fits**: the pattern already matches. Nothing else to do.
- **Can be normalized**: you can reshape the code to the pattern without
  changing behaviour (for example, extracting a version embedded in a URL into
  an `ENV TOOL_VERSION=` and referencing it). Do it, and explain the change.
- **Needs a new customManager**: it does not fit and normalizing would be
  invasive. Do NOT force it. Propose the complete `customManagers` block in the
  report so it can be added to the central `dependency-updates/renovate/default.json`.

## 6. Which migration commands does this repo need?

Separately from the annotations, work out whether any dependency here ships an
official migration tool that must run when it is upgraded. Renovate runs these
through `postUpgradeTasks`, configured centrally.

Known so far: Angular major upgrades need
`ng update <pkg> --from=<old> --to=<new> --migrate-only --allow-dirty --force`,
preceded by `npm ci --ignore-scripts` because `ng update` needs `node_modules`
present.

Look for others in this repository. Typical candidates: framework CLIs with an
`update`, `migrate` or `upgrade` subcommand; ORMs with schema migrations tied to
the library version; codegen tools whose output is version-dependent.

For each one you find, report:
- The package name that triggers it (`matchPackageNames`).
- Whether it applies to majors only or also minors (`matchUpdateTypes`).
- The exact command, using Renovate's `{{{depName}}}`, `{{{currentVersion}}}`
  and `{{{newVersion}}}` templates.
- The regex to add to the `RENOVATE_ALLOWED_COMMANDS` allowlist, anchored as
  tightly as the command permits.

Do NOT run these commands and do NOT add them to any config file yourself. They
belong in `OpenVidu/actions` — the rule in `dependency-updates/renovate/default.json`, the allowlist regex
in `renovate-run.yml` — and both changes go through review. Just report them.

If you find none, say so explicitly.

## 7. Verification

Before you finish, confirm Renovate detects what you annotated:

    npx --yes --package renovate -- renovate-config-validator
    LOG_LEVEL=debug npx --yes renovate --platform=local \
      --dry-run=extract --repository-cache=reset 2>&1 | tee /tmp/renovate-extract.log

`--platform=local` runs a pass against the local filesystem, and
`--dry-run=extract` stops after the extract phase, which is exactly what we want
to check. Look for every dependency you annotated in that output.

If one is missing, the comment or the regex is wrong: fix it and iterate. Do not
accept an annotation that does not show up in that output.

## 8. Final report

End with a table of everything you touched:

| File:line | Version | datasource | depName | Status |

Status: `annotated`, `normalized`, `needs customManager` or `skipped`.
For each `skipped`, give a one-line reason.

Then two blocks, ready to paste into the central `OpenVidu/actions` repo:
1. Any `customManagers` entry to add to `dependency-updates/renovate/default.json`.
2. Any `packageRules` entry with `postUpgradeTasks` from section 6, plus the
   matching `RENOVATE_ALLOWED_COMMANDS` regexes for `renovate-run.yml`.
````

Review the diff before merging. The agent almost always gets the `datasource`
right, but check `depName` by eye for obscure tools: a misspelled name doesn't
error, it just silently never produces a PR.

## Step 6 — Smoke test

Don't wait a week for the cron. Force a failure and watch the loop:

```bash
# 1. Trigger Renovate now
gh workflow run renovate.yml --repo OpenVidu/openvidu-meet

# 2. Once a PR exists and CI has gone red, watch the fixer
gh run list --repo OpenVidu/openvidu-meet --workflow ai-fix.yml

# 3. Or drive the fixer directly at a PR
gh workflow run ai-fix.yml --repo OpenVidu/openvidu-meet -f pr=123
```

A throwaway repo with a deliberately broken bump is the best first target.

---

# 4. Digging into the details

## How `workflow_run` actually behaves

`workflow_run` has its own rules, and they are not intuitive. This is exactly
what happens.

### What triggers it

`ai-fix.yml` runs when a run of a workflow whose `name:` is in the `workflows:`
list **finishes**. It fires for *any* conclusion, so the filtering is done in
`if:`, requiring all three of:

| Condition | Why |
|---|---|
| `conclusion == 'failure'` | Ignores `success`, `cancelled`, `timed_out`, `skipped` |
| `event == 'pull_request'` | Ignores `push` to `main` and scheduled runs |
| `head_branch` starts with `renovate/` | Bot PRs only, never a human's |

`cancelled` and `timed_out` are excluded on purpose: a timeout is rarely a
breaking change, and firing the agent there just burns tokens.

### What does not trigger it

- A Renovate push, directly. Only through CI.
- A workflow whose name isn't in the list.
- `AI Fix` itself. **Never put `"AI Fix"` in its own `workflows:` list.**

### The default-branch rule

Two consequences, both important:

1. The workflow **only registers if the file exists on the default branch**.
   While it lives only on a branch, it never fires.
2. When it fires, it always runs **the version on the default branch**, ignoring
   whatever is on the PR branch.

This is what makes the design safe: a PR from a compromised dependency cannot
rewrite the fixer to exfiltrate `ANTHROPIC_API_KEY`. The cost is that you can't
iterate on `ai-fix.yml` from a PR — see [Development and iteration](#development-and-iteration).

### What context you get, and what's missing

The event carries `github.event.workflow_run` with `id`, `conclusion`, `event`,
`head_branch` and `head_sha`. It does **not** carry the PR number:
`workflow_run.pull_requests` is empty in many cases and is not reliable. The
reusable workflow resolves it from `head_branch` with `gh pr list`.

It also doesn't check out the PR branch by default: an `actions/checkout` with no
`ref` would clone the default branch. The `ref` must be explicit.

### Log access

The GitHub API does not expose logs for a run that's still in progress, but the
run here is already finished, so `gh run view --log-failed` works in one call.
This is one of the concrete advantages of `workflow_run` over hanging a job off
the CI workflow with `needs:` + `if: failure()`, where you'd have to fetch logs
job by job through `actions/jobs/{id}/logs`.

### Visibility

The fixer runs in a **separate run**, not as a check on the PR. It won't appear
in the pull request's checks tab. That's why the prompt requires the agent to
always leave a comment: it's the only channel to a reviewer.

## Why a GitHub App

### The loop won't close without it

Pushes made with the default `GITHUB_TOKEN`
[don't trigger workflows](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).
It's GitHub's recursion guard. If the agent commits with that token, CI never
re-runs, `workflow_run` never fires, and the PR stays red forever.
[`actions/create-github-app-token`](https://github.com/actions/create-github-app-token)
mints a token that does trigger workflows.

### It must not share Renovate's identity

Renovate uses `branch.isModified()` to detect that someone else edited one of its
branches. Per the
[Renovate docs on updating and rebasing](https://docs.renovatebot.com/updating-rebasing),
once you push a commit to a Renovate branch — for example to fix code so tests
pass — Renovate stops updating that branch, and it's on you to finish and merge,
or close the PR to hand control back.

That's **good**: it protects the agent's work from a force-push. But two things
follow:

- If a newer version of that dependency ships, Renovate will no longer update
  that PR. It's frozen.
- Detection is based on commit authorship. If the fixer shared Renovate's App,
  Renovate wouldn't notice the edit and would flatten the fix.

Also: never `--amend` a Renovate commit. Always add new commits.

## Why the Renovate workflow is reusable too

`allowedCommands` is a **global** Renovate option: it can't be set from
`renovate.json` or from a shared preset, only from the environment of the process
that runs Renovate. Left in each repo's workflow, that one variable would force a
redeploy across every repository each time the migration catalog grows — and the
whole point of this design is that per-repo files never change.

Three ways out, and only one works.

### Fork `renovatebot/github-action`

Bake the environment into a fork and point every repo at it. Evaluated and
rejected:

- **It doesn't even solve the problem.** Under the SHA pinning policy your fork
  is still an action, so it's referenced by a 40-char SHA. Changing the allowlist
  changes the SHA, and you're redeploying every repo again.
- You'd own upstream tracking forever. The action tracks Renovate releases
  closely; a fork that lags is a security liability, not an asset.
- You inherit the whole review surface of a third-party action for the sake of
  two environment variables.

### A composite action wrapper

Thinner than a fork — a composite action in `OpenVidu/actions` that sets the env and
calls the upstream action. It fails for the same reason: composite actions are
actions, so SHA pinning applies and every bump means a redeploy. It also inherits
[the composite pinning trap](#the-trap-that-isnt-in-the-changelog), since its own
internal `uses:` must be pinned too.

### A reusable workflow

**Reusable workflows are exempt from the SHA pinning policy** and may be
referenced by tag. So `@v1` is a moving pointer: change the allowlist in
`OpenVidu/actions`, move the tag, and every repo picks it up on its next run with
nothing deployed anywhere.

It also centralizes everything else that would otherwise be stuck in each repo's
copy: `timeout-minutes`, log level, concurrency, and any future Renovate
environment variable.

The one thing that can't move is the trigger — `on: schedule` has to live in the
caller, because a reusable workflow can't declare its own triggers. That's why
the cron stays in the wrapper and the real cadence policy lives in the preset's
`schedule`, where it can be changed centrally.

## Why per-repo secrets

On the GitHub **Free** plan, organization secrets and variables
[are not accessible from private repositories](https://docs.github.com/actions/security-guides/using-secrets-in-github-actions).
The failure mode is nasty: no error, the secrets just arrive empty. Team or
Enterprise lifts it.

If **all** your repos are public, org secrets do work on Free and you can skip
this. Otherwise, define them per repository. With
[`gh secret set`](https://cli.github.com/manual/gh_secret_set) that's one line
per repo and fully scriptable — see [Mass deployment](#mass-deployment).

## Why the shared repo must be public

Reusable workflow access is asymmetric:

| Calling repo | May use workflows hosted in |
|---|---|
| private | private (with opt-in), internal, **public** |
| public | **public only** |

With a mix of public and private repos and a private `OpenVidu/actions`, the public ones
could never use it. No setting enables that. With `OpenVidu/actions` public, both kinds
work with no extra configuration and you skip the
[access opt-in](https://docs.github.com/en/actions/how-tos/sharing-automations/sharing-actions-and-workflows-from-your-private-repository)
entirely.

Nothing sensitive is exposed: the workflow holds no secrets, it receives them
from the caller at run time. A third party invoking it is harmless — they'd use
their own runners, their own secrets, their own repo.

### Checklist before publishing

- [ ] No sensitive value as an input `default:` (internal URLs, private
      registries, hostnames).
- [ ] Nothing sensitive in the prompt text.
- [ ] All actions SHA-pinned with their version comment.
- [ ] `main` protected and the `v1` tag protected with a tag ruleset.
- [ ] Zero `${{ }}` interpolation inside `run:` blocks.

### No `${{ }}` inside `run:`

Expressions expand **before** the shell starts, so a value containing `;` or
backticks executes as a command. Always route through `env:`:

```yaml
      # ❌ injectable
      - run: echo "${{ inputs.bot-login }}"

      # ✅
      - env: { BOT_LOGIN: "${{ inputs.bot-login }}" }
        run: echo "$BOT_LOGIN"
```

In a public repo this stops being good practice and becomes mandatory — anyone
can read the code looking for the gap.

## SHA pinning

This design assumes **Require actions to be pinned to a full-length commit SHA**
is enabled ([org-level](https://docs.github.com/en/organizations/managing-organization-settings/disabling-or-limiting-github-actions-for-your-organization),
also available per repo and per enterprise).

### What the policy covers

Every action must be pinned to a full 40-character SHA, including your own
organization's actions and GitHub-authored ones. `actions/checkout@v4` stops
working.

**Reusable workflows may still be referenced by tag.** That's an explicit carve-out
in the [secure use reference](https://docs.github.com/en/actions/reference/security/secure-use),
and it's good news here: it preserves the model where you move the `v1` tag in
`OpenVidu/actions` and every repo picks it up with no redeployment.

If your internal policy is stricter and demands a SHA there too, you lose the
moving tag: every change to `OpenVidu/actions` then requires redeploying `ai-fix.yml`
everywhere. One more `bootstrap.sh` run, but no instant propagation for an
urgent fix.

### The trap that isn't in the changelog

**A composite action fails if its own internal dependencies aren't pinned.**
GitHub's [announcement](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/)
doesn't mention it, but several projects broke on it. It only affects
*composite* actions that call other actions; JavaScript and Docker actions are
unaffected. If a third-party action fails this way, your options are to fork and
pin it, or find an alternative. There's no configurable exception — test it in
the pilot repo before rolling out.

### The version comment is load-bearing

```yaml
- uses: actions/checkout@<40-hex>            # v4.2.2
```

Renovate uses that comment to know which tag the SHA belongs to. An action
pinned to a bare SHA with no version comment is
[disabled by default](https://docs.renovatebot.com/modules/manager/github-actions/),
because Renovate can't tell which branch or tag it came from.

### Renovate keeps the pins fresh

`dependency-updates/renovate/default.json` includes `helpers:pinGitHubActionDigests`. On its first run,
Renovate opens a PR converting every tag reference into a SHA pin with its
version comment, then updates the SHA whenever the tag moves. Without it, pins
age and you end up running actions with known vulnerabilities.

Note that this preset would also pin the `OpenVidu/actions` reference, because the
`github-actions` manager extracts reusable-workflow `uses:` too. That's why
the preset disables that package explicitly.

### Resolving the SHAs: `dependency-updates/scripts/pin-actions.sh`

Templates carry `<SHA_*>` tokens instead of hashes, so you never copy a stale
hash from an example.

**→ [`dependency-updates/scripts/pin-actions.sh`](../dependency-updates/scripts/pin-actions.sh)**

It resolves each token to the SHA of a named tag, verifies the SHA really belongs to the
upstream repo rather than a fork, rewrites the two reusable workflows **in place** and the
templates into `build/`, and then refuses to finish if any token is still unresolved or any
action is still referenced by tag.

Those last two checks are the safety net: if someone adds an action to a
template and forgets the token, deployment stops before writing to any repo.

For auditing repos that already exist, [`pinact`](https://github.com/suzuki-shunsuke/pinact)
and [`zgosalvez/github-actions-ensure-sha-pinned-actions`](https://github.com/zgosalvez/github-actions-ensure-sha-pinned-actions)
do the same job on existing workflows.

## Renovate already knows what it's updating

There's no need to tell Renovate which technology a repo uses.
[`packageRules`](https://docs.renovatebot.com/configuration-options/#packagerules)
*are* the discovery mechanism: Renovate scans the repository, decides which
managers apply, and evaluates every rule against the specific dependency it's
about to update.

| Matcher | Matches on |
|---|---|
| `matchManagers` | The detected manager: `npm`, `maven`, `gradle`, `gomod`, `dockerfile`... |
| `matchPackageNames` | The dependency name (`@angular/core`, `org.springframework.boot:*`) |
| `matchDatasources` | The origin: `docker`, `github-releases`, `maven`... |
| `matchFileNames` | The path of the file declaring it |

A rule targeting `@angular/core` is **inert** in a Go repo: nothing matches, so
nothing runs. That's why every stack's rules can live in one shared
`dependency-updates/renovate/default.json`, and why each repo's `renovate.json` is identical.

### When a named preset does make sense

Extra presets (`local>OpenVidu/actions//dependency-updates/renovate/critical.json`) are still
useful, but for
**deliberate decisions Renovate cannot infer**, not for technology. For example a
`critical` preset that disables automerge and sets `prConcurrentLimit: 1` on
production repos. That's policy, not stack — nobody can deduce it by looking at
the files.

### Versioning the shared config

A preset can be pinned to a Git tag:

```json
{ "extends": ["local>OpenVidu/actions//dependency-updates/renovate/default.json#v1"] }
```

Without a tag, changes to `default.json` reach every repo on the next run. Fine
to start with; move to tags if the config grows. Note this is a *different*
versioning axis from the `@v1` on the reusable workflow, even though both now
live in `OpenVidu/actions`: the workflow ref is resolved by Actions, the preset ref by
Renovate.

### Optional: drop the per-repo `renovate.json` too

Renovate has [Inherited config](https://docs.renovatebot.com/config-overview/):
with `inheritConfig` enabled it looks for an org-level config before processing
each repository, defaulting to `{{parentOrg}}/renovate-config` (configurable to
`OpenVidu/actions`) and
`org-inherited-config.json`, both configurable. The docs pitch it for exactly
this case — avoiding repository config in each repo.

But they also recommend shared presets over Inherited config where possible, and
there's a practical reason: with a `renovate.json` in the repo, anyone who opens
it sees that Renovate is active and where its config comes from. With inherited
config it's invisible, and the next person won't know why PRs keep appearing.
Three identical lines are a cheap price for that.

## Migration commands (`ng update` and friends)

### Nothing about technology lives in a repo

The workflow you copy into each repository names no technology, no command and
no allowlist. It's six lines and it's the same everywhere. Migration decisions
are split across three layers, and only the bottom one is per-repo:

| Layer | Where | Decides |
|---|---|---|
| Wrapper | Each repo · 6 lines | When Renovate wakes up. Nothing else |
| `renovate-run.yml` | `OpenVidu/actions` · one file | What **could** run, in any repo |
| `dependency-updates/renovate/default.json` | `OpenVidu/actions` · one file | What **actually** runs, and only where it applies |

The allowlist is not per-technology or per-repo: it's a single **union** list. A
Go repo carries the `ng update` regex in its allowlist and nothing whatsoever
happens, because no `packageRule` matches — there is no `@angular/core` to
upgrade. Renovate works that out on its own.

So adding a new technology is two edits **in `OpenVidu/actions`**, once in that
technology's lifetime, and zero repos touched.

### Why keep an allowlist at all

`RENOVATE_ALLOWED_COMMANDS` is an **allowlist, not an execution list**. It runs
nothing; it declares what *would* be permitted if a `packageRule` asked for it.
The actual commands live in
[`postUpgradeTasks`](https://docs.renovatebot.com/configuration-options/#postupgradetasks).

You could set it to `'[".*"]'` and let the preset decide alone. Don't:
`allowPostUpgradeCommandTemplating` interpolates `{{{depName}}}` into a shell,
so the allowlist is the boundary that stops a malicious package name — or a
compromised preset — from running arbitrary code on the runner with your
Renovate token in scope.

It's the one piece that has to be kept in step with the catalog, and that's
deliberate: it's what makes the templating tolerable. Keep the anchors tight.

### The catalog

Each entry is a `packageRule` in `dependency-updates/renovate/default.json`:

```json
{
  "description": "Angular: run the official migrations on upgrade",
  "matchPackageNames": ["@angular/core"],
  "matchUpdateTypes": ["major"],
  "postUpgradeTasks": {
    "commands": [
      "npm ci --ignore-scripts",
      "npx ng update {{{depName}}} --from={{{currentVersion}}} --to={{{newVersion}}} --migrate-only --allow-dirty --force"
    ],
    "fileFilters": ["**/**"],
    "executionMode": "update"
  }
}
```

Three details worth knowing:

- **The `npm ci` validates nothing.** It's there because `ng update` needs
  `node_modules` present to run. It is not a check; drop `ng update` and that
  line is pointless. Validation is always the PR's CI.
- **`matchUpdateTypes: ["major"]`** avoids running the codemod on every patch.
  Migrations only exist between majors.
- Commands run in a subshell **without** the environment variables of the shell
  that launched Renovate. If one needs credentials, use Renovate's `secrets`
  feature.

Angular is the only entry we know we need today. The
[annotation pass](#step-5--annotate-versions-and-discover-migrations) reports
candidates per repo, so the catalog grows from evidence rather than guesswork.

Adding an entry means two edits, both inside `OpenVidu/actions`: the `packageRule` in
`dependency-updates/renovate/default.json` and the matching regex in `RENOVATE_ALLOWED_COMMANDS` in
`renovate-run.yml`. The first propagates instantly through the preset; the second
propagates as soon as you move the `v1` tag. Nothing is redeployed to consumer
repos. Forgetting the allowlist half is still the easiest mistake to make, and
it fails silently — the task is simply skipped.

### How they divide the work

| | Catalog | AI fixer |
|---|---|---|
| Covers | Official framework migrations | Any breaking change |
| Runs | Before CI | Only when CI fails |
| Determinism | Total — it's the framework's own codemod | Probabilistic |
| Cost | Zero | One agent run |

They don't compete, and you want both. The catalog handles cheaply and
deterministically whatever has an official tool; the fixer catches everything
else, which is the majority of real breaking changes. When the catalog does its
job the PR arrives green and the agent never wakes up.

Relying on the fixer alone would mean a guaranteed red CI cycle on every Angular
major, just to end up running the command you already knew was needed — and
swapping a deterministic codemod for a probabilistic agent that might hand-patch
what the official tool does correctly.

### What was rejected

Running the fixer **always**, even on green PRs, to "modernize" code for the new
version. It's the only approach that catches deprecations which don't break the
build — real value. But it turns green PRs red, mixes speculative refactors into
the same diff (destroying revertability), gives the agent an instruction with no
natural stopping point, and would freeze *every* Renovate branch by committing
to it.

If you want that value, it belongs in a **separate** monthly scheduled agent
that opens its own modernization PR, fully decoupled from dependency PRs.

## Why the agent discovers the commands

Passing `test-command` and `install-command` as workflow inputs would duplicate
what's already in each repo's `ci.yml`, and the two would drift. Instead the
agent gets the failure logs and reads `.github/workflows/` itself.

The escape hatch for repo-specific quirks is `CLAUDE.md` in the repository root,
which Claude Code reads automatically. It isn't duplication, because it's
documentation the repo wants anyway:

```markdown
# CLAUDE.md

## CI
Integration tests need `docker compose -f compose.test.yml up -d` first.
They take ~8 min.

## Constraints
- The `legacy-api/` module is frozen: don't modify it during dependency updates.
- We use AssertJ's `assertThat`, never JUnit's asserts.
```

## Why the agent can't just replay the workflow

It isn't a missing interpreter — reading YAML and translating `run:` steps to
shell is the easy part. The problem is that a workflow is not a self-contained
description of an environment. It's a reference to things that live outside the
repo, in rough order of severity:

**Secrets.** `${{ secrets.DB_PASSWORD }}` is unrecoverable by design. If the
failing job needs a private registry, an integration database or a cloud OIDC
token, local replay dies there.

**`services:` and `container:`.** Containers the runner starts *before* the job,
with network aliases, health checks and port mappings. The agent could
`docker run` them by hand, but the topology won't match: the test expects
`postgres:5432`, not `localhost:5433`.

**`runs-on`.** If the failing job is `windows-latest` and the fixer runs on
`ubuntu-latest`, there's nothing to replay.

**`uses: someone/action@v3`.** An action is arbitrary JS or Docker code in
another repo. `setup-*` actions are trivial to emulate; a proprietary deploy
action isn't.

**The workflow may not even be in the checkout.** If your CI calls a reusable
workflow from another repo, the file defining the failing job isn't there.

There *is* an interpreter — [`act`](https://github.com/nektos/act) — but it hits
the same walls: Linux runners only, default images lacking the preinstalled
tooling of GitHub runners, matrix port conflicts because all jobs share a network
namespace, and you still have to supply secrets yourself.

The practical conclusion: **you already have a perfect workflow interpreter, and
it's GitHub Actions.** Don't rebuild it inside the agent. Let it reproduce what
it can — 100% in a plain Node or Java repo — and where it can't, let the pipeline
rule. The one thing that matters is that the agent knows which mode it's in and
says so in the PR comment. "I couldn't reproduce the environment; this fix is
unverified" completely changes how a human reviews it.

## The retry loop

The loop closes by itself: the agent commits with the App token, CI runs, CI
fails, `workflow_run` fires again. Your job isn't to build it, it's to **bound**
it.

State has to live in the PR, since every run is a fresh container. Counting the
bot's commits on the branch is the cleanest option — it derives from the actual
work and needs no extra API writes.

On retry, don't reuse the same prompt. The prompt in
[Step 3](#step-3--set-up-openviduactions) tells the agent to diff the new failure
against its previous attempt and distinguish two cases: if the error **changed**,
it made progress and should continue; if the error is **identical**, its
hypothesis was wrong and it should discard the approach rather than refine it.
That distinction is what stops it polishing the same wrong fix three times.

When attempts run out, the PR goes to **draft** and gets `needs-human`. Draft is
more useful than a label alone: it blocks any automerge and pulls the PR out of
the active review queue.

**How many attempts?** Start at 2. With 1 you lose the common "fixed half the
breaking change" case; from 3 up the returns fall off sharply and the PR fills
with bot commits a human has to read anyway.

## Mass deployment

### `dependency-updates/scripts/set-secrets.sh`

**→ [`dependency-updates/scripts/set-secrets.sh`](../dependency-updates/scripts/set-secrets.sh)**

Sets the four secrets on every repo of an owner, or on the ones you name.

Values come from environment variables rather than arguments so they don't land
in shell history. `gh secret set` is idempotent, so the same script rotates
credentials.

### `dependency-updates/scripts/deploy-file.sh`

**→ [`dependency-updates/scripts/deploy-file.sh`](../dependency-updates/scripts/deploy-file.sh)**

Creates or updates one file in a repo through the API, passing the existing blob SHA when
the file is already there.

### `dependency-updates/scripts/bootstrap.sh`

**→ [`dependency-updates/scripts/bootstrap.sh`](../dependency-updates/scripts/bootstrap.sh)**

The one you actually run: resolves the pins into `build/` (aborting before touching any repo
if anything is left unpinned), sets the secrets, then deploys the three files from `build/`
to every repo.

Files are written straight to the **default branch**, which is exactly where
`workflow_run` needs them to register. If branch protection blocks direct pushes,
use `gh pr create` instead; the end state is the same.

### Verification

```bash
for repo in $(gh repo list OpenVidu --limit 300 --no-archived --json name -q '.[].name'); do
  echo -n "$repo · secrets: "
  gh secret list --repo "OpenVidu/$repo" --json name -q '[.[].name]|length'
  echo -n "  workflows: "
  gh api "repos/OpenVidu/$repo/actions/workflows" --jq '[.workflows[].name] | join(", ")'
done
```

### Finding your workflow names

The `workflows:` list in `ai-fix.yml` is the one thing that depends on local
naming. To build it once for the whole org:

```bash
for repo in $(gh repo list OpenVidu --limit 300 --no-archived --json name -q '.[].name'); do
  gh api "repos/OpenVidu/$repo/actions/workflows" --jq '.workflows[].name'
done | sort -u
```

Take that output, drop `Renovate` and `AI Fix`, and that's your list. Longer
term, the healthy fix is to standardize the `name:` of CI workflows across the
org.

## Development and iteration

The default-branch rule means you can't iterate on `ai-fix.yml` from a PR. Two
things make that a non-issue.

**Almost nothing you'll change lives in `ai-fix.yml`.** The wrapper is 15 lines
of trigger and delegation: write once, never touch. Everything you'll actually
iterate on — the prompt, log collection, the counter, the agent's rules — lives
in `OpenVidu/actions`.

And the restriction applies to the **calling** file, not to the ref of the
**called** workflow, which resolves at run time. So in a pilot repo:

```yaml
uses: OpenVidu/actions/.github/workflows/renovate-ai-fix.yml@dev
```

Iterate on `OpenVidu/actions`'s `dev` branch as fast as you like, merging nothing in any
consumer. When it works, move the `v1` tag.

**`workflow_dispatch` on the wrapper.** Once `ai-fix.yml` is on the default
branch, manual dispatch *does* honour the ref you pass:

```bash
gh workflow run ai-fix.yml --ref my-test-branch -f pr=123
```

That runs the version on `my-test-branch`, and lets you aim the agent at a
specific PR without waiting for something to actually break.

What you're trading away is real, but it's the good side of the coin: **being
able to iterate from a PR is exactly the vulnerability.** GitHub doesn't let you
have both. Given that your PRs are opened by a bot running freshly published
third-party code, it's a price worth paying.

## Beyond `package.json`

### Docker images and dockerized browsers

No configuration needed — the `dockerfile` and `docker-compose` managers are
native. Selenium and Playwright browsers are Docker images, so they come along
for free:

```yaml
services:
  chrome:
    image: selenium/node-chromium:131.0        # Renovate updates this
```

### Tools installed in a Dockerfile

Mark the version with a comment and one rule covers them all:

```dockerfile
# renovate: datasource=github-releases depName=hadolint/hadolint
ENV HADOLINT_VERSION=2.12.0

# renovate: datasource=npm depName=yarn
ENV YARN_VERSION=4.5.0

# renovate: datasource=github-tags depName=nodejs/node versioning=node
ENV NODE_VERSION=22.11.0
```

The matching [custom manager](https://docs.renovatebot.com/modules/manager/regex/)
is in `dependency-updates/renovate/default.json` (Step 3). To annotate an existing repo, use the
prompt in
[Step 5](#step-5--annotate-versions-and-discover-migrations).

### Dependencies with no registry

[`customDatasources`](https://docs.renovatebot.com/modules/datasource/custom/)
queries generic HTTP(S) endpoints and transforms the response with JSONata:

```json
{
  "customDatasources": {
    "k3s": {
      "defaultRegistryUrlTemplate": "https://update.k3s.io/v1-release/channels",
      "transformTemplates": [
        "{\"releases\":[{\"version\": $$.(data[id = 'stable'].latest)}]}"
      ]
    }
  }
}
```

Without writing any code, the `endoflife-date` datasource covers JDK, Node,
Kubernetes and EKS lifecycles, and `repology` covers system packages in
Dockerfiles.

## Known traps

| Problem | Cause | Fix |
|---|---|---|
| Workflow fails on an unpinned action | SHA pinning policy is on | Resolve with `pin-actions.sh`; deploy from `build/` |
| A third-party action fails even though it's pinned | It's *composite* and its internal deps aren't | Fork and pin, or find an alternative — no exception exists |
| Renovate ignores a pinned action | Bare SHA with no version comment | Append `# vX.Y.Z` |
| Renovate pins the shared reusable too | The `github-actions` manager also extracts `jobs.*.uses` | `packageRule` disabling `OpenVidu/actions` |
| `ai-fix.yml` never fires | The file isn't on the default branch | Deploy to `main`, not a branch |
| `on.workflow_run does not reference any workflows` | Missing `workflows:` key | It's mandatory — enumerate the names |
| It fires but the job always skips | Your CI's `name:` isn't in the list | List the real name |
| Infinite run loop | `"AI Fix"` listed in its own `workflows:` | Remove it |
| CI doesn't re-run after the fix | `GITHUB_TOKEN` pushes don't trigger workflows | GitHub App token |
| The agent can't find the PR | `workflow_run.pull_requests` is empty | Resolve from `head_branch` with `gh pr list` |
| Checkout pulls the wrong code | No `ref`, so it clones the default branch | `ref: ${{ steps.pr.outputs.head }}` |
| Can't test changes from a PR | `workflow_run` uses the default-branch version | `@dev` on the reusable + `workflow_dispatch --ref` |
| Secrets arrive empty | Org secrets don't reach private repos on Free | Per-repo secrets |
| The `.pem` doesn't work | `--body` mangles multi-line values | `gh secret set X --repo O/R < key.pem` |
| A public repo can't find the reusable | Public repos may only call public workflows | Make `OpenVidu/actions` public |
| Renovate flattens the fix | Force-push on rebase | Give the fixer a distinct bot identity |
| The PR freezes with no new versions | Renovate stops updating branches edited by others | Expected: merge or close |
| The shared preset isn't applied | Preset referenced without the full path | `local>owner/repo//renovate/default.json`, extension included |
| `postUpgradeTasks` runs nothing, silently | The command isn't in `RENOVATE_ALLOWED_COMMANDS` | Add the regex in `renovate-run.yml` and move the `v1` tag |
| `Cannot find preset's package` | Path preset written with `:` instead of `//` | Use `owner/repo//path/to/file.json` |
| The migration command can't see its credentials | It runs in a subshell without Renovate's env | Renovate's `secrets` feature |
| `gh pr edit --add-label` fails | The label doesn't exist | `gh label create X --force` first |
| Two agents on the same branch | Overlapping runs | `concurrency` with `cancel-in-progress` |

## Rolling out in phases

**Phase 1 — observe (2–4 weeks).** Everything on, including the Angular
migration rule. Minor and patch only, `max-attempts: 1`, never automerge.
Measure how many PRs land green, and collect the migration candidates the
annotation pass reports.

**Phase 2 — grow the catalog.** Add the `postUpgradeTasks` rules that the phase 1
evidence justifies. Writing entries speculatively is wasted work: if no Angular
major lands in three months, that rule was still worth having, but a Spring Boot
rule for a repo that never bumps it was not.

**Phase 3 — widen.** Move to `max-attempts: 2` and enable majors where the hit
rate is good.

**Phase 4 — selective automerge.** devDependency patches with green CI only, and
only with high test coverage. Never majors.

### A documented anti-pattern

Large grouped PRs that sit red for months block the security patches grouped
inside them. That's why the shared preset pulls security updates out of groups
with `"vulnerabilityAlerts": { "groupName": null }`.

## Costs

| Item | Cost |
|---|---|
| Renovate (GitHub Action) | GitHub Actions minutes |
| AI agent per PR | ~USD 0.05–0.20 depending on provider and context size |
| Retries | Multiply by `max-attempts` in the worst case |

**Watch the minutes on the Free plan.** Public repos don't consume minutes on
standard runners. Private repos have a limited monthly allowance (2,000 minutes
on Free) and the agent can take a while per PR. With a weekly `schedule` and a
low `prConcurrentLimit` it's manageable, but watch it for the first few weeks
under Settings → Billing.

Hard ceilings already built in: `timeout-minutes: 25`, `--max-turns 40` and
`max-attempts`. An agent stuck in a tool loop is the main source of unexpected
spend.
