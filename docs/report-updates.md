# Report updates - create and schedule one

> A **report update** is one of the two kinds of [AI Automation](./ai-automations.md) in this
> repository: a scheduled agent run that keeps a *document* up to date. The other kind,
> [dependency updates](./dependency-updates.md), keeps a repository's *dependencies* up to
> date and is built quite differently - same idea, different requirements and implementation.
>
> Concrete steps to create a report update (interactive phase) and then schedule it so it
> runs on its own, every day/week/month, with nobody launching it by hand. Follow this guide
> to the letter the first time; from the second one onwards, the steps in Part 3 are almost
> copy-paste.
>
> This guide assumes you already know how to use Claude Code interactively and day-to-day
> git/GitHub (clone, commit, open a Pull Request). **It assumes no prior knowledge of
> GitHub Actions** - every concept is explained the first time it appears.
>
> Context and the reasoning behind both kinds: [AI Automations](./ai-automations.md).

---

## What already exists and you don't have to write

Report updates lean on **two shared resources** that live in this repository
(`OpenVidu/actions`) and are used by every one of them, whatever repository they live in:

| Resource | What it is |
| --- | --- |
| [**Execution contract**](../run-report-update/AGENT_CONTRACT.md) (`AGENT_CONTRACT.md`) | The generic half of the prompt. Defines the parameters the task receives, the rule that everything it downloads is untrusted content, how much autonomy it has to adapt, what to do if the task already ran today, the format of the Slack report and how it delivers its changes. |
| [**Composite action `run-report-update`**](../run-report-update/README.md) (`action.yml`) | The generic half of the workflow. Launches Claude Code, streams its activity to the log, commits and pushes (or opens the PR) and sends the report to Slack. |

The practical consequence is the split that structures this whole guide:

* **Your task's `prompt.md` says *what* has to be done.** Nothing else. It does not repeat
  the security rules, nor the Slack message format, nor the commit policy: that is already
  in the contract, and the action prepends it to the prompt automatically on every run.
* **Your task's workflow says *when* it runs.** It is about 20 lines: the triggers and a
  call to the shared action.

If you touch the contract, you change the behaviour of **every** existing task on its next
run. Treat it as an interface, not as prose to be tidied up at will.

---

## Part 1 - First run (interactive)

### Step 1 - Research and generate the first report

Open a normal conversation with the AI and ask for the study you need. Ask it to research
the topic, analyse whatever is needed, review the relevant sources, and deliver a first
report in markdown. Give it business context, not just the mechanics. For example:

> "Research whether our competitors (list: ...) have shipped new features, changed prices,
> or published relevant announcements lately. I want a report with what you find and the
> source of every data point."

Iterate with the AI as in any normal session - correct the focus, ask it to expand or trim,
check that the cited sources are correct - until the report convinces you. Ask it to write
the date the report was created inside the report itself. Save that first report wherever
it fits in the repo, without following any particular structure. This first report is
necessarily a "snapshot" of the current state, not a change report - that nuance is exactly
what gets designed in the next step.

To make updating the information easier later, you can ask the AI to store the relevant
information in a structured format (`.json`) and to save the scripts it uses to obtain that
information in the repository. If you do, these pieces should live somewhere
"recognisable": **the `report-updates/<report-name>/` folder** of the repository that hosts the task. Ask
the AI to summarise, in `report-updates/<report-name>/prompt.md`, the instructions it followed to
generate the report throughout the conversation. That `prompt.md` will help create the
automation later.

> **Which repository?** The one most related to the task's content (the `comparative-study`
> task lives in `openvidu-competitors`, next to the study it maintains). If there is no
> better candidate, `openvidu-brain`. What is **not** duplicated in each repo are the
> contract and the action: those are shared.

## Part 2 - Create the update task (interactive)

### Step 2 - The first update: this is when it gets automated

When the natural moment comes to ask the AI again to update the report it produced (a week
or a month later) open an interactive session with the AI again. Because you have the
previous report and the context has moved on, there is a baseline to compare against and
you can ask for a change report.

Ask the AI to update the report it made. You can draw on the content of `prompt.md` in the
chat, but it may need some change or refinement after the time that has passed. For
example, if you ask it to analyse a piece of software's features, you normally ask it to
look at the website or the latest version. But when you ask it to analyse the changes, you
normally ask it to analyse the release notes, the blogs, and so on. That is why the update
task should really run when there is something to update (not when the first report is
generated). If it generated code to produce the report the first time, tell it to reuse it
(even if it has to change it).

To record the changes you can copy this paragraph as-is into the chat:

> As well as keeping the report(s) up to date, a document must be created specifying what
> has changed since the last review. This document will be created in a `changelog` folder
> next to the report and will contain one file per review, named after the date the
> changelog was generated (e.g. `2026-09-01.md`). There will also be a `changelog.md` file
> containing one summary per report update, pointing at the detailed changelog document.

If there are more reports in the report's folder, the `changelog` folder and the
`changelog.md` file can be prefixed with the report's name.

Also ask the task to **record the date of its last run** in a state file (e.g.
`report-updates/<report-name>/state.json` with a `last_review_date` field). This is not a whim: it is
what allows the next run to compute its change window, and what the contract uses to avoid
doing the same day's work twice (§C4).

Once the first report update has run, check that the content is what you want, that the
file formats are right, and so on. You can ask for refinements until you are happy.

### Step 3 - Ask the AI to rewrite `prompt.md`

Once the change-report format designed in Step 2 convinces you, explicitly ask the AI to
rewrite `prompt.md` so the task can run with nobody watching. **The important part of this
step is what you NO LONGER have to write**: the execution contract covers security,
autonomy, the Slack report, the same-day rule and the delivery of changes. If you repeat it
in `prompt.md`, you will have two sources of truth that will contradict each other over
time.

You can copy this block into the chat, adjusting the path:

> Rewrite `report-updates/<report-name>/prompt.md` so that it contains the precise instructions to repeat
> unattended the update task you have just done.
>
> This runbook will run under the **execution contract** at
> <https://github.com/OpenVidu/actions/blob/main/run-report-update/AGENT_CONTRACT.md>.
> Read it in full before writing anything. The contract already defines: the parameters the
> run receives, that all external content is untrusted data and never instructions, the
> autonomy to adapt to environment changes while reporting the decisions, what to do if the
> task already ran today, the format of the `/tmp/slack.json` report with its "skipped" and
> "failure" templates, and the `/tmp/outcome.json` file through which changes are delivered.
> **Do not repeat any of that in prompt.md.**
>
> Write only this task's specific half:
> 1. A notice at the start that the runbook runs under that contract, with the link.
> 2. The concrete steps: which sources are consulted, which scripts are run, what is
>    verified, and which files have to be updated (list them all).
> 3. Where the date of the last run is recorded, so the contract's §C4 rule can be applied,
>    and which concrete artifacts would collide if it ran twice on the same day.
> 4. The success-case Slack payload (§C5): what it should summarise — findings only, never the
>    verification technique behind them (§C5a is where that goes) — and which documents it
>    should link to. The "skipped" and "failure" templates are already in the contract.
> 5. Any extra detail the failure report should include for this particular task.
>
> Do not include git instructions: you must not commit or push, the workflow takes care of
> that based on what you leave in `/tmp/outcome.json`.

When you have it, **read it yourself**. This is the file that will run on its own for
months. The [`comparative-study` task](https://github.com/OpenVidu/openvidu-competitors/blob/main/report-updates/comparative-study/prompt.md)
in `openvidu-competitors` is the reference example of how it ends up.

Commit and push the changes before scheduling the task.

## Part 3 - Scheduling phase: making it run on its own

### Step 4 - Check or create the required secrets

The workflow needs two **secrets**: sensitive values that GitHub stores encrypted and that
the workflow can use without them ever appearing in the code or the logs. They are called
`CLAUDE_CODE_OAUTH_TOKEN` and `SLACK_WEBHOOK_URL`.

> **On the Free plan, organisation secrets do not reach private repositories.** OpenVidu is
> on GitHub Free, so if the repository hosting this report update is **private**, both
> secrets have to be defined **on the repository itself**. There is no setting that changes
> this, and the failure mode is nasty: the secrets arrive **empty**, with no error at all,
> and the run fails as if the token were invalid.
>
> If the repository is **public**, organisation secrets do work on Free. In that case check
> first whether the team already defined them - organisation → **Settings** → **Secrets and
> variables** → **Actions** - and skip to Step 5 if they are there.
>
> Either way, ask the team before generating a new token on your own: it avoids duplicates
> and orphaned tokens.

**4.1 - Generate the Claude Code token (`CLAUDE_CODE_OAUTH_TOKEN`)**

This token lets the workflow use the team's Claude subscription instead of a pay-per-token
API key. It belongs to the account that generates it and expires after a year.

1. In your terminal, with Claude Code already logged in with the account/subscription that
   will be lent to the automation, run:

   ```bash
   claude setup-token
   ```

2. Follow the on-screen instructions (log in if needed). It prints a long token at the end.
3. Copy it - do not paste it into any chat or document, only into the GitHub field in step
   4.3.
4. Note somewhere in the team (e.g. a pinned Slack note) **who generated it and when it
   expires** (365 days), so it can be renewed in time.

> If this secret is missing or empty, the symptom is very characteristic: the run step fails
> in **about one second** and the transcript log shows `Not logged in · Please run /login`.

**4.2 - Configure the Slack webhook (`SLACK_WEBHOOK_URL`)**

An *incoming webhook* is simply a secret URL: anyone who sends it an HTTP request with a
message makes that message appear in a specific Slack channel. It is a credential, so **it
does not get pasted into documents** - it lives only as a secret in GitHub.

A webhook already exists for the `#openvidu-ia-tasks` channel, which is the one current
tasks use: ask whoever administers the workspace for the URL, or copy it from the secret
already configured in another repository with AI Automations. You only need to create a new one
if you want to notify a **different** channel:

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **Blank app**.
2. Name it "ia-tasks" and choose the CodeURJC workspace.
3. In the app's left-hand menu, go to **Incoming Webhooks** and turn the switch on.
4. Press **Add New Webhook to Workspace**, choose the channel and confirm.
5. Copy the generated URL (it starts with `https://hooks.slack.com/services/...`).

**4.3 - Add the secrets to the repository in GitHub**

1. On the repository page in GitHub, click the **Settings** tab (you need to be a repo
   admin; if you do not see this tab, ask someone who is to do this step).
2. In the left-hand menu: **Secrets and variables** → **Actions**.
3. Press **New repository secret**.
4. Name: `CLAUDE_CODE_OAUTH_TOKEN` - Value: the token from step 4.1. Press **Add secret**.
5. Repeat with the name `SLACK_WEBHOOK_URL` and the value from step 4.2.

If the repository is going to host several AI Automations, these two secrets are created
**once** and every one of them in the repo reuses them.

### Step 5 - Choose when it runs (the cron)

GitHub Actions schedules runs with a **cron** expression: five numbers/asterisks separated
by spaces meaning `minute hour day-of-month month day-of-week`. An asterisk (`*`) means "any
value". Examples, all at 04:07 in the morning:

**Once a week** (the day of the week goes in the fifth field: `0`=Sunday, `1`=Monday,
`2`=Tuesday... `6`=Saturday):

| Day | Cron expression |
| --- | --- |
| Monday | `7 4 * * 1` |
| Tuesday | `7 4 * * 2` |
| Wednesday | `7 4 * * 3` |
| Thursday | `7 4 * * 4` |
| Friday | `7 4 * * 5` |
| Saturday | `7 4 * * 6` |
| Sunday | `7 4 * * 0` |

**Once a month** (the day of the month goes in the third field):

| Day of month | Cron expression |
| --- | --- |
| Day 1 | `7 4 1 * *` |
| Day 3 | `7 4 3 * *` |
| Day 5 | `7 4 5 * *` |
| Day 15 | `7 4 15 * *` |

You do not need to memorise the syntax: use a tool like [crontab.guru](https://crontab.guru/)
to build and check the expression in plain language.

Two important warnings:

* **Times are always UTC**, not the team's local time. Convert the desired time to UTC
  before writing the cron (in Spain, during summer time UTC = local − 2 h; during winter
  time UTC = local − 1 h).
* **Avoid minute 0** (`0 * * * *`, `0 5 * * *`...): GitHub warns that scheduled workflows
  can be delayed, and those delays are more frequent right at the top of each hour. Use an
  odd minute like `17` or `43`.

Also choose a **realistic cadence**: if the task runs more often than its sources change,
most runs will find nothing.

### Step 6 - Create the workflow file

Create the file `.github/workflows/report-update-<report-name>.yml` (the `report-update-` prefix helps
distinguish these workflows from the rest of the repo's CI in the Actions tab) with this
content, adapting `<report-name>` and the chosen cron:

```yaml
name: report-update-<report-name>
on:
  schedule:
    - cron: '17 5 * * 1'      # when it runs on its own (see Step 5)
  workflow_dispatch:           # allows launching it by hand, with these two options (see Step 8)
    inputs:
      force:
        description: 'Run even if the task already ran today'
        type: boolean
        default: false
      create_pr:
        description: 'Open a Pull Request instead of pushing straight to main'
        type: boolean
        default: false

jobs:
  run-task:
    runs-on: ubuntu-latest      # a temporary Linux machine, destroyed when it finishes
    timeout-minutes: 60         # if it takes longer than this, it cancels itself
    permissions:
      contents: write            # so the job can commit and push
      pull-requests: write       # so it can open the PR if asked

    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      # All the generic machinery is inside here (see the action's README).
      # The SHA must be kept current: see the note below.
      # `inputs` is empty on cron runs, hence the `|| false`.
      - uses: OpenVidu/actions/run-report-update@<40-char SHA> # OpenVidu/actions vX.Y.Z
        with:
          report-name: <report-name>
          prompt-file: report-updates/<report-name>/prompt.md
          force: ${{ inputs.force || false }}
          create-pr: ${{ inputs.create_pr || false }}
          claude-code-oauth-token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          slack-webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
```

Notes about this file, in case anything is unclear:

* `on:` defines **when** the workflow fires: here, on a schedule (`schedule`) and also by
  hand (`workflow_dispatch`, see Step 8).
* `jobs: run-task:` is the only block of work; `runs-on: ubuntu-latest` says what kind of
  machine it runs on (a fresh, empty Linux machine each time, managed by GitHub).
* `steps:` is the list of actions that run in order. `uses:` invokes a ready-made reusable
  piece: here, "download the repo" and the `run-report-update` action.
* `secrets.CLAUDE_CODE_OAUTH_TOKEN` and `secrets.SLACK_WEBHOOK_URL` are the values you saved
  in Step 4 - GitHub substitutes them at run time and masks them automatically if they
  appear in the logs.
* **Every action reference is pinned to a full 40-character SHA**, never to a tag (`@v4`) or
  a branch (`@main`). The OpenVidu organisation **requires** it: otherwise the run fails
  before it starts with *"is not allowed in ... because all actions must be pinned to a
  full-length commit SHA"*. The reason is supply-chain security: a tag or a branch can be
  moved to another commit, a SHA cannot. The comment next to it (`# v6.0.2`,
  `# OpenVidu/actions vX.Y.Z`) tells you which version it is without having to look the SHA
  up.
* **To bring the shared action's SHA up to date**, in a clone of `OpenVidu/actions`:

  ```bash
  git fetch origin main && git rev-parse origin/main
  ```

  Or take the SHA of the release tag you want. Mind the side effect of pinning: **the task
  stays frozen on that version of the contract and the action**; changes made in
  `OpenVidu/actions` do not reach it until someone updates the SHA in its workflow. That is
  the price of reproducibility - and the organisation's *Release and Update Pinned Actions*
  workflow is what bumps it everywhere at once.

### Step 7 - Save and merge the workflow

Same as in Part 2: commit, push, Pull Request, review and merge.

```bash
git add ".github/workflows/report-update-<report-name>.yml"
git commit -m "Schedule report update: <report-name>"
git push
```

### Step 8 - Test the task without waiting for the cron

You do not need to wait for the scheduled time to check that it works:

1. In GitHub, go to the repository's **Actions** tab (at the top, next to
   Code/Issues/Pull requests).
2. In the list on the left you will see all the repo's workflows; look for
   `report-update-<report-name>` (this is why the prefix helps).
3. Click it. A **Run workflow** button appears at the top right (it exists because the file
   has `workflow_dispatch`). Pressing it shows the two options:

   | Option | When to use it |
   | --- | --- |
   | **force** | The task already ran today and you want it redone anyway. Without this option, a second run on the same day does nothing and reports via Slack that it was skipped - this is deliberate: artifacts are named after the date and a second run would overwrite them instead of extending them. |
   | **create_pr** | You want to review the result before it lands on `main`. Instead of pushing, it creates a branch `report-update/<report-name>/<date>-<id>` and opens a PR. |

4. Press **Run workflow**. In a few seconds a new run appears in the list, with a yellow
   icon (in progress).

> The first time it is worth trying both variants: a normal run and one with **create_pr**,
> to see the result in a PR before letting it loose against `main`.

### Step 9 - Check that it worked

* In the Actions tab, the run is marked with a green ✅ if all went well, or a red ❌ if
  something failed.
* Click the specific run and then the job (`run-task`). Inside the **Run the task** step
  there is a collapsible group **"Claude transcript"** with what the agent did: its own
  text, one line per tool it used and any tool errors. This is where you see *why* it did
  what it did.
* On the run's summary page (right at the top) you get **the agent's closing answer**, with
  the number of turns, the duration and the cost. This is deliberately the *complete* version
  of the report: the same findings Slack got, plus the decisions and verification detail the
  contract keeps out of Slack (§C5a) precisely so this page is where they land instead.
* Check the Slack channel: the report should have arrived, focused on findings, with the run
  link (and a commit/PR link, and the run's cost) appended automatically at the end.
* Check in the repository that the commit (or the PR) with the updated report was created.

### Step 10 - If it fails or gets blocked

The agent itself should have left a summary of the blocker in Slack and opened an issue in
the repo with the detail (contract §C7). Even so, the first place to look is always the
transcript from Step 9.

Two characteristic failures:

* **The run lasts ~1 second and the transcript says `Not logged in`** → the
  `CLAUDE_CODE_OAUTH_TOKEN` secret is missing, empty or expired (Step 4.1).
* **It fails resolving the action, "repository not found"** → check the reference to
  `OpenVidu/actions` (owner, path and SHA). The repository is public, so no access opt-in is
  involved.

If the agent dies before writing its report, the action still sends a Slack message saying
there was no report, with the reason and a link to the log. And if that happens, **nothing
is committed**: the commit only happens if the agent explicitly asks for it, so a broken run
never leaves the repository half-done.

Usual steps: read the transcript and the issue, fix by hand whatever the agent could not
(expired credential, large structural change), and launch the task again with **Run
workflow** (Step 8, ticking **force** if it already ran today).

### Step 11 - Pause, re-enable or delete a task

* **Pause temporarily** (without deleting anything): Actions tab → select the workflow →
  "**...**" button (top right) → **Disable workflow**. To re-enable it, the same button
  offers **Enable workflow**.
* **Delete the task completely**: delete `.github/workflows/report-update-<report-name>.yml` and the
  `report-updates/<report-name>/` folder in a Pull Request, like any other change.

---

## Summary checklist

* [ ] Exploratory first run done (Step 1): first report obtained and saved in the right
      repository.
* [ ] First update done (Step 2): `report-updates/<report-name>/` folder created with its scripts, the
      change report already designed and a state file with the date of the last run.
* [ ] `prompt.md` rewritten **without repeating the contract** (Step 3) and reviewed by a
      person.
* [ ] `report-updates/<report-name>/` folder committed and merged into the main branch.
* [ ] `CLAUDE_CODE_OAUTH_TOKEN` and `SLACK_WEBHOOK_URL` secrets created on the repository
      itself (mandatory if it is private - see Step 4).
* [ ] Cron chosen (time in UTC, minute other than 0, realistic cadence).
* [ ] `.github/workflows/report-update-<report-name>.yml` created with the shared action and actions
      pinned to SHAs, committed and merged.
* [ ] Tested manually with **Run workflow**; ✅ verified in Actions, transcript reviewed,
      report updated in the repo, and message received in Slack.

## Frequently asked questions

**Does this guide cover dependency updates?** No. Dependency updates are the other kind of
[AI Automation](./ai-automations.md): they are handled by a different pipeline - Renovate
plus an AI fixer that only intervenes when CI turns red - and are documented in
[Dependency updates](./dependency-updates.md). This guide is for the kind that keeps a
document up to date.

**Do I have to create the secrets in every new repository?** For **private** repositories,
yes, every time. OpenVidu is on the GitHub Free plan, and on that plan organisation secrets
are not accessible from private repositories - they arrive empty, with no error, so
centralising them there is not an option. Only **public** repositories can inherit them from
the organisation. Moving the organisation to Team or Enterprise would lift the restriction.
The dependency-update pipeline hits exactly the same wall, for the same reason - see
[Why per-repo secrets](./dependency-updates.md#why-per-repo-secrets).

**Can I have several tasks in the same repository?** Yes: each one is a different
`report-updates/<report-name>/` folder and a different `.github/workflows/report-update-<report-name>.yml` file; the
secrets and the shared action are reused.

**What if two tasks in different repos need to share common logic?** That already happened,
and it is why the contract and the action live in `OpenVidu/actions`: all the common
machinery is there and gets referenced, not copied. If *another* common piece appears (a
collection script useful to several tasks), the same criterion applies: it lives in
`OpenVidu/actions` and is referenced from wherever it is needed.

**And if I want to change the common behaviour of every task?** Edit the
[contract](../run-report-update/AGENT_CONTRACT.md) or the [action](../run-report-update/README.md). But since
each workflow pins a SHA (Step 6), the change **does not arrive on its own**: the SHA has to
be updated in every task that should adopt it. It is more work, and at the same time it is
the safety net - no task changes behaviour overnight without someone deciding it.

**How much does this cost?** Nothing in new licences: the task consumes the already-paid
limits of the Claude subscription (through the token from Step 4.1) and GitHub Actions
minutes, normally within the repository plan's free quota.
