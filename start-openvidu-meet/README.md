# Start OpenVidu Meet

This GitHub Action sets up and optionally runs the OpenVidu Meet for testing and development environments.

## Description

This action automates the process of setting up and optionally running the OpenVidu Meet by:

1. Checking out the OpenVidu Meet repository
2. Optionally building and including the latest OpenVidu Components Angular library (configurable)
3. Preparing the environment using the prepare script
4. Optionally starting the app in production mode (configurable)
5. Optionally waiting for the app to be ready and accessible (if started)

## Inputs

| Parameter                  | Description                                                                                      | Required | Default  |
| -------------------------- | ------------------------------------------------------------------------------------------------ | -------- | -------- |
| `timeout`                  | Maximum time to wait for OpenVidu Meet to start (in milliseconds)                                | No       | `60000`  |
| `skip_backend_start`       | Skip starting the backend server (only build and prepare)                                        | No       | `false`  |
| `build_components_angular` | Build and include latest OpenVidu Components Angular library in frontend                         | No       | `true`   |
| `components_checkout_ref`  | Branch, tag, or commit to checkout for OpenVidu Components Angular                               | No       | `master` |
| `components_artifact_name` | Name of existing artifact with OpenVidu Components Angular package (if provided, skips building) | No       | -        |

## Usage

### Start OpenVidu Meet with Backend (Default behavior)

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Start OpenVidu Meet Backend
    uses: OpenVidu/actions/start-openvidu-meet@main
    with:
      timeout: '120000' # Optional: extend timeout to 2 minutes

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

### Start OpenVidu Meet without Custom Components Angular Library

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Start OpenVidu Meet with Latest Components
    uses: OpenVidu/actions/start-openvidu-meet@main
    with:
      build_components_angular: 'false'

  - name: Run tests against OpenVidu Meet
    run: |
      # Your test commands here
      # OpenVidu Meet will be running with the custom Components Angular library
```

### Build from Different Components Angular Branch

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Start OpenVidu Meet with Fork Components
    uses: OpenVidu/actions/start-openvidu-meet@main
    with:
      build_components_angular: 'true'
      components_checkout_ref: 'feature-branch'
```

### Use Pre-built Components Angular Artifact

```yaml
jobs:
  build-components:
    runs-on: ubuntu-latest
    steps:
      - name: Build Components Angular
        id: build
        uses: OpenVidu/actions/build-openvidu-components-angular@main
        with:
          checkout_ref: 'v3.0.0'
          artifact_name: 'shared-components'
    outputs:
      artifact_name: ${{ steps.build.outputs.artifact_name }}

  start-meet:
    needs: build-components
    runs-on: ubuntu-latest
    steps:
      - name: Start OpenVidu Meet with Pre-built Components
        uses: OpenVidu/actions/start-openvidu-meet@main
        with:
          build_components_angular: 'true'
          components_artifact_name: ${{ needs.build-components.outputs.artifact_name }}
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

- When `build_components_angular` is `true`:
  - **With `components_artifact_name` empty (default)**:
    - The latest OpenVidu Components Angular library is built from the specified reference
    - The built library replaces the existing one in the frontend before preparation
    - The library is built as a temporary artifact that is automatically cleaned up after installation
    - This adds significant time to the action execution due to the build process
  - **With `components_artifact_name` provided**:
    - Uses an existing artifact instead of building a new one
    - Downloads the specified artifact and installs it in the frontend
    - Does not clean up the artifact (assumes it's managed elsewhere)
    - Significantly faster as it skips the build process
    - Useful for workflows with multiple jobs that share the same components
