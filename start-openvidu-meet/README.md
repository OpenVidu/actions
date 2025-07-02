# Start OpenVidu Meet

This GitHub Action sets up and runs the OpenVidu Meet for testing and development environments.

## Description

This action automates the process of setting up and running the OpenVidu Meet by:

1. Checking out the OpenVidu Meet repository
2. Preparing the environment using the prepare script
3. Starting the app in production mode
4. Waiting for the app to be ready and accessible

## Inputs

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `timeout` | Maximum time to wait for OpenVidu Meet to start (in milliseconds) | No | `60000` |

## Usage

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Start OpenVidu Meet Backend
    uses: OpenVidu/actions/start-openvidu-meet@main
    with:
      timeout: '120000'  # Optional: extend timeout to 2 minutes

  - name: Run tests against OpenVidu Meet
    run: |
      # Your test commands here
      # OpenVidu Meet will be available at http://localhost:6080/
```

## Requirements

- GitHub runner with Node.js environment

## Technical Details

- The backend is started using `npm run start:ci` in background mode
- The action waits until the backend is responding at the healthcheck endpoint (`http://localhost:6080/health`)
- If the backend doesn't start within the timeout period, the action will fail
