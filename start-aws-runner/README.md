# Start AWS EC2 Runner

This GitHub Action starts an EC2 GitHub Actions runner on AWS for scalable compute resources.

## Description

This action automates the process of starting an AWS EC2 runner by:

1. Configuring AWS credentials for authentication
2. Starting an EC2 instance with the specified configuration
3. Registering the instance as a GitHub Actions runner
4. Tagging the instance with workflow and repository information
5. Returning the runner label and instance ID for further use

## Inputs

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `aws-instance-type` | EC2 instance type | No | `c5.large` |
| `aws-access-key-id` | AWS Access Key ID | Yes | - |
| `aws-secret-access-key` | AWS Secret Access Key | Yes | - |
| `aws-region` | AWS Region | Yes | - |
| `github-token` | GitHub token for runner registration | Yes | - |
| `ec2-image-id` | AMI ID for the EC2 instance | Yes | - |
| `subnet-id` | AWS Subnet ID | Yes | - |
| `security-group-id` | AWS Security Group ID | Yes | - |
| `workflow-name` | Workflow name for tagging | No | `${{ github.workflow }}` |
| `repository-name` | Repository name for tagging | No | `${{ github.repository }}` |

## Outputs

| Parameter | Description |
|-----------|-------------|
| `label` | Label of the started EC2 runner |
| `ec2-instance-id` | EC2 instance ID of the started runner |

## Usage

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Start AWS EC2 Runner
    id: start-runner
    uses: OpenVidu/github-actions/start-aws-runner@v1
    with:
      aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
      aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      aws-region: ${{ vars.AWS_REGION }}
      github-token: ${{ secrets.GITHUB_TOKEN }}
      ec2-image-id: ${{ vars.AWS_GITHUB_ACTIONS_AMI }}
      subnet-id: ${{ vars.AWS_SUBNET_ID }}
      security-group-id: ${{ vars.AWS_SECURITY_GROUP_ID }}
      aws-instance-type: 'c5.xlarge'  # Optional: specify larger instance

  - name: Use the started runner
    runs-on: ${{ steps.start-runner.outputs.label }}
    steps:
      # Your job steps here...
```

## Requirements

- AWS account with appropriate permissions to create and manage EC2 instances
- GitHub token with permissions to register runners
- Properly configured AWS VPC with subnet and security group
- AMI with GitHub Actions runner pre-installed

## Technical Details

- EC2 instances are automatically tagged with workflow and repository information for easy identification
- The action uses the `machulav/ec2-github-runner` action internally for EC2 management
- AWS credentials are configured using the official `aws-actions/configure-aws-credentials` action
- The runner label and instance ID are returned as outputs for use in subsequent workflow steps