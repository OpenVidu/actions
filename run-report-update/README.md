# `run-report-update` — the generic half of every report update

This action implements **report updates**, one of the two kinds of
[AI Automation](../docs/ai-automations.md) in this repository. (The other kind, dependency updates,
is built on Renovate and does not use this action.) It runs a **runbook** (a `prompt.md` under
`report-updates/<report-name>/`, in whichever repository owns the automation) through Claude Code with nobody
watching, and takes care of everything that is the same for every report update, in every
repository:

1. Resolves the run parameters (`today`, `force`, `delivery`, `url_ref`) and, in PR mode, creates the
   task branch **before** the agent runs, so the agent can build links against the right ref.
2. Builds the prompt as **[`AGENT_CONTRACT.md`](AGENT_CONTRACT.md) + the runbook + the parameters**,
   so the contract is delivered to the agent rather than trusted to be read.
3. Runs Claude Code and streams a **readable transcript** into the job log — its own text, one line
   per tool call, tool errors — then puts its closing answer in the job summary.
4. Commits what the run left behind, according to `/tmp/outcome.json`, and pushes it or opens a PR.
5. Sends the run's `/tmp/slack.json` report to Slack, synthesising a fallback report if the agent
   died before writing one, and appending the commit/PR link that the agent could not know.

The split is deliberate: **the runbook says what to do, the contract says how a run behaves.** A new
task writes only the first.

## Adding a new report update

**1. Write the runbook** at `report-updates/<report-name>/prompt.md`. It only covers what this report update does; the
contract already covers untrusted input, autonomy, the "already ran today" rule, the report and the
git handover. Start it with the pointer so a human running it by hand knows to read the contract:

```markdown
# Task: <what it does>

> **This runbook runs under the [report-update execution contract](https://github.com/OpenVidu/actions/blob/main/run-report-update/AGENT_CONTRACT.md).**
> The workflow prepends it automatically; if you are running this by hand, read it first.

## 1. …
```

The contract asks each runbook to supply a few task-specific pieces: where the date of the last run
is recorded (§C4), the *success* Slack payload (§C5), and any extra blocks the failure report should
carry. [`comparative-study/prompt.md`](https://github.com/OpenVidu/openvidu-competitors/blob/main/report-updates/comparative-study/prompt.md),
in `openvidu-competitors`, is the worked example.

**2. Add the workflow** at `.github/workflows/report-update-<report-name>.yml`:

```yaml
name: report-update-<report-name>
on:
  schedule:
    - cron: '<when>'
  workflow_dispatch:
    inputs:
      force:
        description: 'Run even if the task already ran today'
        type: boolean
        default: false
      create_pr:
        description: 'Open a pull request instead of pushing straight to main'
        type: boolean
        default: false

jobs:
  run-task:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      # Pinned to a full-length SHA (see Notes)
      - uses: OpenVidu/actions/run-report-update@<40-char SHA> # OpenVidu/actions vX.Y.Z
        with:
          report-name: <report-name>
          prompt-file: report-updates/<report-name>/prompt.md
          force: ${{ inputs.force || false }}          # `inputs` is empty on a scheduled run
          create-pr: ${{ inputs.create_pr || false }}
          claude-code-oauth-token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          slack-webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
```

**3. Make sure the secrets exist** in the repository (*Settings → Secrets and variables → Actions*):

| Secret | How to get it |
| --- | --- |
| `CLAUDE_CODE_OAUTH_TOKEN` | `claude setup-token` in an interactive session (needs a Claude subscription). Without it the run dies in about a second with `Not logged in`. |
| `SLACK_WEBHOOK_URL` | An [incoming webhook](https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks) for the destination channel. Optional: leave the input out and the Slack step is skipped. |

## Inputs

| Input | Default | Purpose |
| --- | --- | --- |
| `report-name` | *required* | Identifier used in the branch name, the commit subject fallback and the reports. |
| `prompt-file` | *required* | Path to the runbook, from the repository root. |
| `claude-code-oauth-token` | *required* | Auth for Claude Code. |
| `slack-webhook-url` | `''` | Where to send the report. Empty ⇒ no Slack step. |
| `force` | `false` | Run even if the task already ran today (§C4). |
| `create-pr` | `false` | Deliver as a pull request instead of pushing to `base-branch`. |
| `base-branch` | current ref | Branch to push to, or to open the PR against. |
| `allowed-tools` | `Bash,Read,Write,Edit,Glob,Grep,WebFetch,WebSearch` | Tools the agent may use without asking. Listing a tool here pre-approves it, which is what makes `acceptEdits` workable headlessly. |
| `permission-mode` | `acceptEdits` | Claude Code permission mode. |
| `contract-file` | the shipped one | Override to use a different contract. |

## Outputs

`status` (from `/tmp/outcome.json`), `committed`, `commit-sha`, `pull-request-url`.

## Notes

- **Nothing is committed unless the agent asks for it.** The commit step reads `/tmp/outcome.json`;
  if the agent crashed, was cancelled or hit the job timeout, that file does not exist and the step
  is a no-op. That is what makes `if: always()` safe here.
- **PR mode and links.** The branch is created before the agent runs and passed to it as `url_ref`,
  so the links it writes point at the branch rather than at `main`, where the files do not exist yet.
  PRs opened with `GITHUB_TOKEN` do not trigger other workflows; if these PRs ever need CI, use a PAT
  or a GitHub App instead.
- **This action lives in `OpenVidu/actions` and is used from other repositories.** That is the
  point: the contract and the machinery that implements it are one versioned unit, shared instead
  of copied. `OpenVidu/actions` is **public**, so no access opt-in is needed - any repository in
  the organisation (public or private) can reference it directly.
- **Pinning is mandatory.** The OpenVidu organisation requires every action to be pinned to a
  full-length commit SHA, so `@main` is rejected before the job even starts ("all actions must be
  pinned to a full-length commit SHA"). Get the current one with `git fetch origin main &&
  git rev-parse origin/main` in a clone of `OpenVidu/actions`, or take the SHA of the release tag
  you want. The consequence is that **a task stays frozen on the version of the action and the
  contract it pins**: changes made here reach it only when someone bumps that SHA in its workflow.
  The organisation's *Release and Update Pinned Actions* workflow does that bump across every
  repository at once.
- **Changing the contract changes every task that pins the new SHA.** It is prepended verbatim to
  each runbook, so a reworded rule changes how those tasks behave — without anyone touching them.
  Treat `AGENT_CONTRACT.md` as an interface, not as prose to tidy up, and when you change it, decide
  deliberately which tasks get their SHA bumped.
