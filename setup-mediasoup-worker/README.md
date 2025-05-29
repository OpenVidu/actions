# Setup mediasoup-worker

This GitHub Action sets up the mediasoup-worker binary either by compiling it from source or downloading a precompiled version.

## Description

This action automates the process of setting up the mediasoup-worker binary by:

1. Checking out the OpenVidu/openvidu-pro-mediasoup repository (if compiling from source)
2. Setting up Python environment (required for compilation)
3. Compiling the mediasoup-worker from source OR downloading a precompiled binary
4. Making the binary executable and returning its path

## Inputs

| Parameter                    | Description                                                                                                                                                                               | Required | Default   |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | --------- |
| `ref-openvidu-pro-mediasoup` | Branch, tag or commit SHA to checkout in repository OpenVidu/openvidu-pro-mediasoup. If "default" mediasoup-worker binary will not be compiled: artifact from latest release will be used | No       | `default` |
| `github-token`               | GitHub token to access private repositories. Only required if ref-openvidu-pro-mediasoup != "default"                                                                                     | No       | -         |

## Outputs

| Parameter              | Description                         |
| ---------------------- | ----------------------------------- |
| `MEDIASOUP_WORKER_BIN` | Path to the mediasoup-worker binary |

## Usage

### Using precompiled binary (default)

```yaml
steps:
  - name: Setup mediasoup-worker
    id: setup-mediasoup
    uses: OpenVidu/actions/setup-mediasoup-worker@main

  - name: Use mediasoup-worker
    run: |
      echo "mediasoup-worker binary is at: ${{ steps.setup-mediasoup.outputs.MEDIASOUP_WORKER_BIN }}"
      # Use the binary in your application
```

### Compiling from source

```yaml
steps:
  - name: Setup mediasoup-worker from source
    id: setup-mediasoup
    uses: OpenVidu/actions/setup-mediasoup-worker@main
    with:
      ref-openvidu-pro-mediasoup: "main" # Specify branch/tag/commit
      github-token: ${{ secrets.GITHUB_TOKEN }}

  - name: Use compiled mediasoup-worker
    run: |
      echo "Compiled mediasoup-worker binary is at: ${{ steps.setup-mediasoup.outputs.MEDIASOUP_WORKER_BIN }}"
      # Use the binary in your application
```

## Requirements

- GitHub runner with bash shell
- For compilation from source:
  - Build tools (make, compiler toolchain)
  - Access to the OpenVidu/openvidu-pro-mediasoup private repository
