# Setup OpenVidu Call Backend

This GitHub Action sets up an OpenVidu Call backend instance for testing and development environments.

## Description

This action automates the process of setting up an OpenVidu Call backend by:

1. Checking out the OpenVidu Call repository
2. Installing the backend dependencies
3. Starting the backend in development mode
4. Waiting for the backend to be ready and accessible

## Inputs

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `branch` | Branch to checkout from OpenVidu/openvidu-call repository | No | `master` |
| `timeout` | Maximum time to wait for backend startup (in milliseconds) | No | `60000` |

## Usage

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Setup OpenVidu Call Backend
    uses: OpenVidu/actions/start-openvidu-call@main
    with:
      branch: 'develop'  # Optional: specify a different branch
      timeout: '120000'  # Optional: extend timeout to 2 minutes

  - name: Run tests against backend
    run: |
      # Your test commands here
      # OpenVidu Call backend will be available at http://localhost:6080
```

## Requirements

- GitHub runner with Node.js environment

## Technical Details

- The backend is started using `npm run dev:start` in background mode
- The action waits until the backend is responding at the healthcheck endpoint
- If the backend doesn't start within the timeout period, the action will fail
- The `wait-on` tool is used to check for backend availability and will be installed automatically if needed
