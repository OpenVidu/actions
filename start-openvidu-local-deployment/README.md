# Start OpenVidu Local Deployment

This GitHub Action sets up an OpenVidu local deployment using Docker Compose for testing and development environments.

## Description

The action performs the following operations:

1. Checks out repository OpenVidu/openvidu-local-deployment
2. Allows using **community/pro** editions
   - If **pro** edition is used, allows using **pion/mediasoup** RTC engines
   - If **mediasoup** RTC engine is used, allows compiling **mediasoup-worker** from source or using pre-built default binary
3. Allows setting up custom tags for each service of the deployment through a JSON object
4. Allows running custom pre-startup commands
5. Starts the OpenVidu services using Docker Compose
6. Waits for the deployment to be ready and accessible

## Inputs

Here's a Markdown table documenting the inputs of this GitHub Action:

| Input Name | Description | Required | Default Value |
|------------|-------------|----------|---------------|
| `ref-openvidu-local-deployment` | Branch, tag or commit SHA to checkout in repository OpenVidu/openvidu-local-deployment | No | `development` |
| `timeout` | Maximum time to wait for deployment startup (in milliseconds) | No | `60000` |
| `openvidu-edition` | OpenVidu edition to use | Yes | `community` |
| `rtc-engine` | RTC engine to use. Only if openvidu-edition == "pro" | No | `mediasoup` |
| `ref-openvidu-pro-mediasoup` | Branch, tag or commit SHA to checkout in repository OpenVidu/openvidu-pro-mediasoup. Only required if openvidu-edition == "pro" && rtc-engine == "mediasoup" && ref-openvidu-pro-mediasoup != "default". If "default" mediasoup-worker binary will not be compiled: artifact from latest release of OpenVidu/openvidu-pro-mediasoup will be used | No | `default` |
| `tags-openvidu-local-deployment` | JSON object with tags for overwriting values in the docker-compose.yaml services of the openvidu-local-deployment. Example: `{"caddy-proxy": "main", "redis": "7.4.2-alpine", "minio": "2025.2.7-debian-12-r0", "mongo": "8.0.4", "dashboard": "main", "ingress": "main", "egress": "v1.9.0", "default-app": "main-demo", "openvidu-v2compatibility": "main", "operator": "main"}` | No | - |
| `github-token` | GitHub token to access private repositories. Only required if openvidu-edition == "pro" && rtc-engine == "mediasoup" && ref-openvidu-pro-mediasoup != "default" | No | - |
| `pre_startup_commands` | Commands to execute before starting the deployment. The path is the same as the docker-compose.yaml file | No | `""` |

## Usage

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Setup OpenVidu Local Deployment
    uses: OpenVidu/actions/start-openvidu-local-deployment@main
    with:
      ref-openvidu-local-deployment: "main" # Optional: specify a different branch for OpenVidu/openvidu-local-deployment
      timeout: "120000" # Optional: extend timeout to 2 minutes
      openvidu-edition: "pro"
      rtc-engine: "mediasoup" # Optional: specify a different RTC engine
      ref-openvidu-pro-mediasoup: "default" # Optional: specify a different branch for OpenVidu/openvidu-pro-mediasoup
      tags-openvidu-local-deployment: '{"caddy-proxy": "latest", "redis": "latest", "minio": "latest"}' # Optional: specify custom tags for services
      github-token: ${{ secrets.GITHUB_TOKEN }} # Provide a GitHub token if accessing private repositories
      pre_startup_commands: | # Optional: Add any pre-startup commands here
        echo "Running pre-startup commands..."

  - name: Run tests against local OpenVidu
    run: |
      # Your test commands here
      # OpenVidu will be available at http://localhost:7880
```

## Requirements

- GitHub runner with Docker and Docker Compose installed
