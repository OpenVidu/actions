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
5. **Image caching**: Attempts to load cached Docker images before pulling new ones (when mode is not `--only-pull-images`)
6. Starts the OpenVidu services using Docker Compose (unless mode is `--only-pull-images`)
7. Caches Docker images for future runs (when mode is not `--only-pull-images`)
8. Waits for the deployment to be ready and accessible (unless mode is `--only-pull-images`)

## Image Caching

The action includes intelligent Docker image caching using **GitHub Actions cache** to speed up subsequent runs across different jobs:

- **Cache storage**: Images are cached using GitHub Actions cache API (up to 10GB per repository)
- **Cache key**: Based on OpenVidu edition and image list hash for precise invalidation
- **Cross-job support**: Cache persists across different jobs in the same workflow and even different workflow runs
- **Automatic restore**: Before pulling images, the action attempts to restore and load cached versions
- **Automatic save**: After successful pulls, images are automatically cached for future use
- **Only-pull-images mode**: Use `mode: "--only-pull-images"` to only pull and cache images without starting the deployment

### How it works:

1. **First run**: Action pulls images → saves to cache
2. **Subsequent runs**: Action restores cache → loads images → pulls only if needed
3. **Cross-job**: Cache is available to all jobs in the workflow, even in different runners

## Inputs

| Input Name                       | Description                                                                                                                                                                                                                                                                                                                                                                        | Required | Default Value |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------- |
| `ref-openvidu-local-deployment`  | Branch, tag or commit SHA to checkout in repository OpenVidu/openvidu-local-deployment                                                                                                                                                                                                                                                                                             | No       | `development` |
| `timeout`                        | Maximum time to wait for deployment startup (in milliseconds)                                                                                                                                                                                                                                                                                                                      | No       | `100000`      |
| `openvidu-edition`               | OpenVidu edition to use. Must be one of `community` or `pro`                                                                                                                                                                                                                                                                                                                       | Yes      | `community`   |
| `rtc-engine`                     | RTC engine to use. Only if openvidu-edition == "pro". Must be one of `pion` or `mediasoup`                                                                                                                                                                                                                                                                                         | No       | `mediasoup`   |
| `mediasoup-worker-bin`           | Path to the mediasoup-worker binary. Only takes effect if openvidu-edition == "pro" && rtc-engine == "mediasoup". If provided, ref-openvidu-pro-mediasoup will be ignored. This is useful to avoid setting up the mediasoup-worker binary twice if action setup-mediasoup-worker has already been called before                                                                    | No       | `""`          |
| `ref-openvidu-pro-mediasoup`     | Branch, tag or commit SHA to checkout in repository OpenVidu/openvidu-pro-mediasoup. Only required if openvidu-edition == "pro" && rtc-engine == "mediasoup" && mediasoup-worker-bin is not provided. If "default" mediasoup-worker binary will not be compiled: artifact from latest release of OpenVidu/openvidu-pro-mediasoup will be used                                      | No       | `default`     |
| `tags-openvidu-local-deployment` | JSON object with tags for overwriting values in the docker-compose.yaml services of the openvidu-local-deployment. Example: `{"caddy-proxy": "main", "redis": "7.4.2-alpine", "minio": "2025.2.7-debian-12-r0", "mongo": "8.0.4", "dashboard": "main", "ingress": "main", "egress": "v1.9.0", "default-app": "main-demo", "openvidu-v2compatibility": "main", "operator": "main"}` | No       | -             |
| `github-token`                   | GitHub token to access private repositories. Only required if openvidu-edition == "pro" && rtc-engine == "mediasoup" && ref-openvidu-pro-mediasoup != "default" && mediasoup-worker-bin is not provided                                                                                                                                                                            | No       | -             |
| `pre_startup_commands`           | Commands to execute before starting the deployment. The path is the same as the docker-compose.yaml file                                                                                                                                                                                                                                                                           | No       | `""`          |
| `mode`                          | Execution mode. Use `"--only-pull-images"` to only pull and cache Docker images without starting the deployment                                                                                                                                                                                                                           | No       | `""`          |

## Usage

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Setup OpenVidu Local Deployment
    uses: OpenVidu/actions/start-openvidu-local-deployment@main
    with:
      ref-openvidu-local-deployment: "main" # Optional: specify a different branch
      timeout: "120000" # Optional: extend timeout to 2 minutes
      openvidu-edition: "pro"
      rtc-engine: "mediasoup"
      ref-openvidu-pro-mediasoup: "default"
      tags-openvidu-local-deployment: '{"caddy-proxy": "latest", "redis": "latest", "minio": "latest"}' # Optional: specify custom tags for services
      github-token: ${{ secrets.GITHUB_TOKEN }}
      pre_startup_commands: | # Optional: Add any pre-startup commands here
        echo "Running pre-startup commands..."
        # Custom setup commands here

  - name: Run tests against local OpenVidu
    run: |
      # Your test commands here
      # OpenVidu will be available at http://localhost:7880

### Only Pull Images Mode

Use the `--only-pull-images` mode in an early job to pre-cache Docker images, then use them in subsequent jobs:

```yaml
jobs:
  cache-images:
    name: Cache Docker Images
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Pre-cache OpenVidu Docker Images
        uses: OpenVidu/actions/start-openvidu-local-deployment@main
        with:
          openvidu-edition: "community"
          mode: "--only-pull-images"

  test-job-1:
    name: Test Job 1
    needs: cache-images
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Images will be automatically loaded from cache
      - name: Start OpenVidu Local Deployment
        uses: OpenVidu/actions/start-openvidu-local-deployment@main
        with:
          openvidu-edition: "community"
          timeout: "120000"

  test-job-2:
    name: Test Job 2
    needs: cache-images
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Images will be automatically loaded from cache
      - name: Start OpenVidu Local Deployment
        uses: OpenVidu/actions/start-openvidu-local-deployment@main
        with:
          openvidu-edition: "community"
          timeout: "120000"
```

## Requirements

- Linux GitHub runner with Docker and Docker Compose installed
- For pro edition with mediasoup: Access to OpenVidu/openvidu-pro-mediasoup repository (if compiling from source)

## Technical Details

- The `mediasoup-worker-bin` input allows reusing a previously set up mediasoup-worker binary, avoiding duplicate setup when action `setup-mediasoup-worker` has been previously called.
- When `mediasoup-worker-bin` is provided, the `ref-openvidu-pro-mediasoup` parameter is ignored and repository OpenVidu/openvidu-pro-mediasoup is not cloned.
- **Image caching**: Docker images are cached using GitHub Actions cache API (up to 10GB per repository) to speed up subsequent runs across different jobs and workflow runs.
- **Cache key strategy**: The cache key is based on the OpenVidu edition and a hash of the image list, ensuring precise cache invalidation when images change.
- **Only-pull-images mode**: When `mode` is set to `"--only-pull-images"`, the action will only pull and cache images without starting the deployment, allowing for faster subsequent jobs.
- **Cache loading**: On normal runs, the action attempts to restore and load cached images before pulling from the registry, significantly reducing startup time for repeated runs.
- **Cross-job efficiency**: The cache is shared across all jobs in the workflow and persists across workflow runs, making it ideal for matrix jobs or multiple test jobs.
