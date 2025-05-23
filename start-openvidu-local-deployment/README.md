# Setup OpenVidu Local Deployment

This GitHub Action sets up an OpenVidu local deployment using Docker Compose for testing and development environments.

## Description

The action performs the following operations:

1. Checks out the OpenVidu local deployment repository
2. Configures the local deployment for LAN usage
3. Starts the OpenVidu services using Docker Compose
4. Waits for the deployment to be ready and accessible

## Inputs

| Parameter | Description                                                           | Required | Default       |
| --------- | --------------------------------------------------------------------- | -------- | ------------- |
| `branch`  | Branch to checkout from OpenVidu/openvidu-local-deployment repository | No       | `development` |
| `timeout` | Maximum time to wait for deployment (in milliseconds)                 | No       | `60000`       |

## Usage

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Setup OpenVidu Local Deployment
    uses: OpenVidu/github-actions/setup-local-deployment@v1
    with:
      branch: 'main' # Optional: specify a different branch
      timeout: '120000' # Optional: extend timeout to 2 minutes

  - name: Run tests against local OpenVidu
    run: |
      # Your test commands here
      # OpenVidu will be available at http://localhost:7880
```

## Requirements

- GitHub runner with Docker and Docker Compose installed
- The runner must have access to the configured port (7880)
- Node.js environment for the wait-on dependency (will be installed automatically if needed)

## Technical Details

- The deployment uses the configuration from the specified branch of the [OpenVidu/openvidu-local-deployment](https://github.com/OpenVidu/openvidu-local-deployment) repository
- The script automatically configures network settings using `configure_lan_private_ip_linux.sh`
- The action waits until the OpenVidu service is responding at `http://localhost:7880`
- If the service doesn't start within the timeout period, the action will fail

