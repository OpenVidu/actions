# Start OpenVidu Components Testapp

This GitHub Action sets up and runs the openvidu-components-angular Testapp for testing and development environments.

## Description

This action automates the process of setting up and running the openvidu-components-angular Testapp by:

1. Installing the necessary dependencies
2. Building the openvidu-components-angular library
3. Building the openvidu-components-angular Testapp
4. Serving the Testapp on a local development server
5. Waiting for the Testapp to be ready and accessible

## Inputs

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `timeout` | Maximum time to wait for app to start (in milliseconds) | No | `60000` |

## Usage

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Checkout OpenVidu Components Angular
    uses: actions/checkout@v4
    with:
      repository: OpenVidu/openvidu-components-angular
      path: openvidu-components-angular

  - name: Start OpenVidu Components Testapp
    uses: OpenVidu/actions/start-openvidu-components-testapp@main
    with:
      timeout: '120000'  # Optional: extend timeout to 2 minutes

  - name: Run tests against the Testapp
    run: |
      # Your test commands here
      # Testapp will be available at http://localhost:4200
```

## Requirements

- GitHub runner with Node.js environment
- The openvidu-components-angular repository must be checked out at path `openvidu-components-angular`

## Technical Details

- The Testapp is built and served using Angular's development server
- The action waits until the application is responding at http://localhost:4200
- If the application doesn't start within the timeout period, the action will fail
- The `wait-on` tool is used to check for application availability and will be installed automatically if needed