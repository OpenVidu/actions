# Start OpenVidu Meet

This GitHub Action sets up and optionally runs the OpenVidu Meet for testing and development environments.

## Description

This action automates the process of setting up and optionally running the OpenVidu Meet by:

1. Checking out the OpenVidu Meet repository
2. Preparing the environment using the prepare script
3. Optionally starting the app in production mode (configurable)
4. Optionally waiting for the app to be ready and accessible (if started)

## Inputs

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `timeout` | Maximum time to wait for OpenVidu Meet to start (in milliseconds) | No | `60000` |
| `skip_backend_start` | Skip starting the backend server (only build and prepare) | No | `false` |

## Usage

### Start OpenVidu Meet with Backend (Default behavior)

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

### Prepare OpenVidu Meet without Starting Backend

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Prepare OpenVidu Meet (without starting backend)
    uses: OpenVidu/actions/start-openvidu-meet@main
    with:
      skip_backend_start: 'true'

  - name: Manually start backend or run other tasks
    run: |
      # The OpenVidu Meet is prepared but backend is not started
      # You can now run custom commands or start the backend manually
      cd backend
      npm run start:dev  # or any other custom command
```

## Requirements

- GitHub runner with Node.js environment

## Technical Details

- When `skip_backend_start` is `false` (default):
  - The backend is started using `npm run start:ci` in background mode
  - The action waits until the backend is responding at the healthcheck endpoint (`http://localhost:6080/health`)
  - If the backend doesn't start within the timeout period, the action will fail

- When `skip_backend_start` is `true`:
  - Only the preparation step (`./prepare.sh`) is executed
  - The backend is not started automatically
  - The waiting step is skipped entirely
  - This is useful when you want to build and prepare the environment but start the backend manually or with different parameters
