# Start OpenVidu Meet Testapp

This GitHub Action starts the OpenVidu Meet testapp for testing and development environments.

## Description

This action automates the process of starting the OpenVidu Meet testapp by:

1. Starting the testapp using npm run start in background mode
2. Waiting for the testapp to be ready and accessible at http://localhost:5080
3. Logging testapp output for debugging purposes
4. Providing timeout functionality with detailed error reporting

## Inputs

| Parameter                 | Description                                                           | Required | Default |
| ------------------------- | --------------------------------------------------------------------- | -------- | ------- |
| `timeout`                 | Maximum time to wait for testapp to start (in milliseconds)           | No       | `60000` |
| `skip_checkout`           | Skip repository checkout (use when repository is already checked out) | No       | `false` |
| `skip_install`            | Skip installing dependencies (assumes they are already installed)     | No       | `false` |
| `skip_build_typings`      | Skip building TypeScript typings                                      | No       | `false` |
| `skip_build_webcomponent` | Skip building the WebComponent                                        | No       | `false` |
| `skip_build_testapp`      | Skip building the testapp                                             | No       | `false` |

## Usage

```yaml
steps:
    - name: Start OpenVidu Meet Backend
      uses: OpenVidu/github-actions/start-openvidu-meet@v1
      with:
          timeout: '120000'

    - name: Start OpenVidu Meet Testapp
      uses: OpenVidu/github-actions/start-openvidu-meet-testapp@v1
      with:
          skip_checkout: 'true' # Repository already checked out in start-openvidu-meet action
          skip_install: 'true' # Dependencies already installed in start-openvidu-meet action
          skip_build_typings: 'true' # TypeScript typings already built in start-openvidu-meet action
          skip_build_webcomponent: 'true' # WebComponent already built in start-openvidu-meet action
          timeout: '90000' # Optional: extend timeout to 1.5 minutes

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

### When to use `skip_checkout`

- **Use `skip_checkout: 'true'`** when the repository has already been checked out in a previous step
- **Use default behavior** (`skip_checkout: 'false'`) when this is the first action that needs the repository
- This is particularly useful in workflows that combine multiple OpenVidu actions that all need the same repository

### When to use `skip_install`

- **Use `skip_install: 'true'`** when dependencies have already been installed in a previous step
- Avoids redundant `npm install` runs in workflows that share the same repository checkout

### When to use `skip_build_typings`

- **Use `skip_build_typings: 'true'`** when TypeScript typings have already been built in a previous step
- Useful when combining with other actions that already built the typings

### When to use `skip_build_webcomponent`

- **Use `skip_build_webcomponent: 'true'`** when the WebComponent has already been built in a previous step
- Saves build time in workflows where the WebComponent artifact is already available

### When to use `skip_build_testapp`

- **Use `skip_build_testapp: 'true'`** when the testapp has already been built in a previous step
- Useful for re-starting the testapp without rebuilding it from scratch
