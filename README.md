# OpenVidu Actions

Automate your OpenVidu workflows in GitHub Actions

This repository hosts two things:

* **Composite actions**: used across OpenVidu's CI — [listed below](#actions)
* **AI Automations**: Shared machinery for unattended agent work, in two kinds — **report updates**, which keep markdown documents up to date, and **dependency updates**, which keep software dependencies current ([know more](./docs/ai-automations.md)).

## Actions

| Action | What it does |
| --- | --- |
| [`build-openvidu-components-angular`](./build-openvidu-components-angular/README.md) | Builds and packages the OpenVidu Components Angular library as a GitHub artifact |
| [`cleanup`](./cleanup/README.md) | Generic cleanup action for OpenVidu test environments |
| [`install-safe-chain`](./install-safe-chain/README.md) | Installs AikidoSec safe-chain in CI mode |
| [`run-report-update`](./run-report-update/README.md) | Runs a Claude Code runbook unattended, then commits it or opens a PR and reports to Slack |
| [`setup-mediasoup-worker`](./setup-mediasoup-worker/README.md) | Compile mediasoup-worker from sources or download precompiled binary |
| [`start-aws-runner`](./start-aws-runner/README.md) | Start an EC2 GitHub Actions runner on AWS |
| [`start-openvidu-call`](./start-openvidu-call/README.md) | Start OpenVidu Call backend for testing |
| [`start-openvidu-components-testapp`](./start-openvidu-components-testapp/README.md) | Start openvidu-components-angular Testapp |
| [`start-openvidu-local-deployment`](./start-openvidu-local-deployment/README.md) | Start OpenVidu Local Deployment with Docker Compose |
| [`start-openvidu-meet`](./start-openvidu-meet/README.md) | Checkout, build, and optionally start OpenVidu Meet and wait for it to be ready |
| [`start-openvidu-meet-testapp`](./start-openvidu-meet-testapp/README.md) | Start the OpenVidu Meet testapp and wait for it to be ready |
| [`stop-aws-runner`](./stop-aws-runner/README.md) | Stop an EC2 GitHub Actions runner on AWS |

`run-report-update` is the odd one out: it is the engine behind the report-update
[AI Automations](./docs/ai-automations.md) rather than a step you add to a CI job.

## How to update pinned actions from OpenVidu/actions repository

Run the workflow [Release and Update Pinned Actions](https://github.com/OpenVidu/openvidu-deployment/actions/workflows/update-pinned-actions.yml).

It will:

1. Create a new release of OpenVidu/actions repository with a new user-defined tag.
2. Update all references to OpenVidu/actions in all repositories in the OpenVidu organization (in their default branch).
3. Create a PR in each repository with the changes. A list with all links to the PRs will be shown in the workflow run summary.
