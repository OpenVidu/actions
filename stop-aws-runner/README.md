# Stop AWS EC2 Runner

This GitHub Action stops an EC2 GitHub Actions runner on AWS to clean up resources after workflow completion.

## Description

This action automates the process of stopping an AWS EC2 runner by:

1. Configuring AWS credentials for authentication
2. Unregistering the GitHub Actions runner
3. Stopping and terminating the EC2 instance
4. Cleaning up AWS resources

## Inputs

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `aws-access-key-id` | AWS Access Key ID | Yes | - |
| `aws-secret-access-key` | AWS Secret Access Key | Yes | - |
| `aws-region` | AWS Region | Yes | - |
| `github-token` | GitHub token for runner registration | Yes | - |
| `label` | Label of the EC2 runner to stop | Yes | - |
| `ec2-instance-id` | EC2 instance ID of the runner to stop | Yes | - |

## Usage

```yaml
jobs:
  start-runner:
    runs-on: ubuntu-latest
    outputs:
      label: ${{ steps.start-runner.outputs.label }}
      ec2-instance-id: ${{ steps.start-runner.outputs.ec2-instance-id }}
    steps:
      - name: Start AWS EC2 Runner
        id: start-runner
        uses: OpenVidu/github-actions/start-aws-runner@main
        with:
          # ... start runner inputs

  test-job:
    needs: start-runner
    runs-on: ${{ needs.start-runner.outputs.label }}
    steps:
      # Your test steps here...

  stop-runner:
    needs: [start-runner, test-job]
    runs-on: ubuntu-latest
    if: always()  # Always run cleanup
    steps:
      - name: Stop AWS EC2 Runner
        uses: OpenVidu/github-actions/stop-aws-runner@main
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.AWS_REGION }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          label: ${{ needs.start-runner.outputs.label }}
          ec2-instance-id: ${{ needs.start-runner.outputs.ec2-instance-id }}
```

## Requirements

- AWS account with appropriate permissions to manage EC2 instances
- GitHub token with permissions to unregister runners
- Valid runner label and EC2 instance ID from the start-aws-runner action

## Technical Details

- This action should always be run with `if: always()` to ensure cleanup happens even if previous jobs fail
- The action uses the `machulav/ec2-github-runner` action internally with `mode: stop`
- AWS credentials are configured using the official `aws-actions/configure-aws-credentials` action
- The runner is unregistered from GitHub before the EC2 instance is terminated