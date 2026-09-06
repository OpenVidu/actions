# AI Automations: what we need, and how each need is solved

This document explains **why** this repository hosts **AI Automations**, describes the two
kinds we run, and points you at the right guide for the one you care about.

Both are AI Automations: recurring work, running unattended, delivered through git. They are
named after what they keep up to date, and they differ in what they require and in how they
are built:

- **[Report updates](./report-updates.md)** - keep a *document* up to date.
- **[Dependency updates](./dependency-updates.md)** - keep a repository's *dependencies* up to date.

---

## 1. Context

OpenVidu is built by a small team whose work spans three areas:

- **Technical work** - developing the product and its documentation, and analysing the
  competitive and technological landscape to steer it.
- **Business operations** - offline licence generation, support and troubleshooting,
  publishing demos.
- **Marketing operations** - answering questions, writing posts, SEO.

The team already runs its automation on GitHub Actions, in three shapes: **on demand**
(cut a release, run an expensive load test), **on every change** (tests, artifacts), and
**scheduled** (nightly artifacts, dog-fooding deployments).

Everyone on the team also uses an AI coding agent - currently Claude Code - interactively,
for all three areas above.

## 2. The need

Some of that AI work is not a one-off. It is **recurring**, it has no reason to require a
person sitting in front of it, and its output is consumed asynchronously, whenever someone
needs it. Concrete examples:

- What have competing products shipped lately?
- What has changed technologically in our space (WebRTC, streaming, codecs)?
- How are our SEO and marketing efforts performing?
- Are our own dependencies current, and can they be moved without breaking anything?
- Is the website still healthy against a moved goalpost (a new search algorithm, LLM-driven
  discovery)?

When a person does one of these interactively, the same phases show up every time: the AI
explores the problem and its sources, writes code to collect the data, runs it, and then
analyses the result and writes it up. **The expensive, judgement-heavy phase is the first
one, and it only has to happen once.** Repeating the task later is mostly the last phase
again, against new data.

That observation is what makes unattended execution worth building: the supervised
interactive session designs the automation, and every run after that is the machine
repeating it.

## 3. What any solution here has to satisfy

These constraints apply to both kinds of AI Automation, and explain most of the design
decisions in the two guides:

| Requirement | Consequence |
| --- | --- |
| The generated code must be auditable and improvable by anyone on the team | It lives in a git repository, not in someone's chat history |
| The output must be reviewable as a change, not just as a document | Markdown in git, so every update is a diff |
| Runs are unattended | The agent must adapt to a drifted environment, and say what it decided |
| A run must never be able to quietly corrupt a repository | Git operations are the workflow's job, not the agent's; delivery is a commit or a PR |
| The team works remotely and asynchronously | Results are pushed to people (Slack, or a PR), not waiting on a page nobody visits |
| Everything already runs on GitHub Actions | That is where these run too - no new scheduler, no new platform |
| Shared machinery must not be copy-pasted per repository | It lives here, in `OpenVidu/actions`, and is referenced |

## 4. Two kinds of AI Automation, two different solutions

Both are AI Automations - an agent doing recurring work with nobody watching - but they are
built very differently, and the reason is worth understanding before picking one.

| | **Report updates** | **Dependency updates** |
| --- | --- | --- |
| Goal | Keep a document up to date | Keep dependencies current |
| What starts it | A cron | A cron (Renovate), then a **failing CI run** |
| Who does the bulk of the work | The agent does the whole job | Renovate does detection and the version bump |
| When the AI is involved | Every run | **Only when CI turns red** |
| What decides "this is correct" | A human reviewing the report | The repository's existing CI |
| How the result is delivered | Commit to `main`, or a PR, plus a Slack report | A pull request, plus a comment on it |
| Shared machinery | [`run-report-update`](../run-report-update/README.md) composite action + [execution contract](../run-report-update/AGENT_CONTRACT.md) | Renovate preset + two reusable workflows + the AI fixer |
| Per-repository cost | A `prompt.md` runbook per automation | Three identical files, never edited again |
| Guide | [Report updates](./report-updates.md) | [Dependency updates](./dependency-updates.md) |

### Why not one mechanism for both

Because the two problems have different shapes.

A **report update** has no oracle. Nothing can tell you whether this week's competitive
analysis is right except a person reading it, and what it should do is different every time -
which sources, which comparison, which format. So the "what" has to be written down once per
automation, as a runbook, and the AI does the whole job on every run.

A **dependency update** has an oracle you already own: **CI**. And detection - "is there a
newer version of this?" - is a solved problem that a deterministic tool does better and more
cheaply than an agent. So the AI is not needed for the whole job, only for the **residue**: the
breaking change that turns CI red and that no tool can adapt your code to. Running an agent
over the whole dependency job would reimplement Renovate badly and spend tokens on work that
does not need judgement.

The rule of thumb: **give the deterministic part to a deterministic tool, and spend the
agent on the part that genuinely needs judgement.**

## 5. How each one works, in one paragraph

### Report updates

A scheduled workflow runs Claude Code unattended inside a GitHub Actions job. The prompt it
receives is the [execution contract](../run-report-update/AGENT_CONTRACT.md) - generic, identical for
every report update, covering untrusted input, autonomy, the same-day rule, the report format
and how changes are handed over - plus that automation's own `prompt.md` runbook, which only
says *what* to do. The agent never touches git: it leaves the working tree as it wants it
recorded and states its verdict in a file, and the workflow commits, pushes or opens the PR,
then sends the run's report to Slack. Adding a report update means writing one runbook and
one ~20-line workflow.

**→ [Report updates](./report-updates.md)**

### Dependency updates

Renovate runs weekly in each repository, detects new versions of everything - manifests,
Docker images, base images, tool versions pinned in `ENV` lines, GitHub Actions - bumps them
and opens a pull request. The repository's existing CI runs against that PR, untouched. If
it passes, a human reviews and merges; nothing else happens. If it fails, a `workflow_run`
trigger wakes the AI fixer, which reads the failure logs and the update diff, works out how
CI runs by reading the workflow files, adapts the **application code** to the breaking
change, and pushes a fix that re-triggers CI. It retries a bounded number of times, then
marks the PR as draft with a `needs-human` label. It never edits tests, manifests or
lockfiles.

**→ [Dependency updates](./dependency-updates.md)**

## 6. What lives in this repository

| Path | What it is |
| --- | --- |
| [`run-report-update/`](../run-report-update/) | Composite action + execution contract for report updates |
| [`.github/workflows/renovate-run.yml`](../.github/workflows/renovate-run.yml) | Reusable workflow: how Renovate is invoked, including its command allowlist |
| [`.github/workflows/renovate-ai-fix.yml`](../.github/workflows/renovate-ai-fix.yml) | Reusable workflow: the AI fixer - prompt, log collection, retry counter |
| [`dependency-updates/`](../dependency-updates/) | Everything else for dependency updates: the Renovate policy and migration catalog, the three identical files deployed into each managed repository, and the SHA-pinning / secret-rollout / mass-deployment scripts |
| [`docs/`](./) | This document and the two guides |

Everything that evolves lives here. The files deployed into each managed repository are
deliberately inert wrappers, so that changing how any of this behaves never means touching
dozens of repositories.
