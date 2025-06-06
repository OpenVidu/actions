# Start OpenVidu Meet Testapp

This GitHub Action starts the OpenVidu Meet testapp for testing and development environments.

## Description

This action automates the process of starting the OpenVidu Meet testapp by:

1. Starting the testapp using npm run start in background mode
2. Waiting for the testapp to be ready and accessible at http://localhost:5080
3. Logging testapp output for debugging purposes
4. Providing timeout functionality with detailed error reporting

## Inputs

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `timeout` | Maximum time to wait for testapp to start (in milliseconds) | No | `60000` |

## Usage

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Start OpenVidu Meet Backend
    uses: OpenVidu/github-actions/start-openvidu-meet@v1
    with:
      timeout: '120000'

  - name: Start OpenVidu Meet Testapp
    uses: OpenVidu/github-actions/start-openvidu-meet-testapp@v1
    with:
      timeout: '90000'  # Optional: extend timeout to 1.5 minutes

  - name: Run tests against the testapp
    run: |
      # Your test commands here
      # Testapp will be available at http://localhost:5080
```

## Requirements

- GitHub runner with Node.js environment
- OpenVidu Meet backend must be running (use `start-openvidu-meet` action first)
- The repository must include a `testapp` directory with a valid package.json
- The testapp must have a `start` script defined in package.json

## Technical Details

- The testapp is started using `npm run start` in background mode
- The action waits until the testapp is responding at http://localhost:5080
- If the testapp doesn't start within the timeout period, the action will fail and display logs
- Output logs are captured in `testapp.log` for debugging purposes
- The action uses curl to check for testapp availability without installing additional dependencies
