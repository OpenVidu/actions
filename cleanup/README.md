# OpenVidu Environment Cleanup

This GitHub Action performs comprehensive cleanup of OpenVidu test environments to ensure a clean state between test runs.

## Description

This action automates the process of cleaning up resources used by OpenVidu test environments by:

1. Displaying the system status before cleanup
2. Terminating common service processes (npm, node, Java, OpenVidu, LiveKit)
3. Cleaning up Docker resources (containers, volumes)
4. Removing temporary files related to OpenVidu
5. Cleaning build directories (node_modules, dist, etc.)
6. Freeing disk space by clearing caches
7. Displaying the final system status after cleanup

## Inputs

This action has no configurable inputs.

## Usage

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  # Run your OpenVidu tests here...

  - name: Cleanup OpenVidu Environment
    uses: OpenVidu/actions/cleanup@main
    # Always run cleanup, even if previous steps fail
    if: always()
```

## Requirements

- GitHub runner with bash shell
- Root/sudo access (for certain cleanup operations)
- Basic Linux tools (ps, grep, find)
- Docker (if Docker resources need to be cleaned)

## Technical Details

- The action performs cleanup operations with the `continue-on-error` flag to ensure all cleanup steps are attempted even if some fail
- Common service processes are identified and terminated using SIGTERM first, then SIGKILL if necessary
- Docker containers are stopped and removed, with Docker Compose environments brought down if detected
- Temporary files and build directories are safely removed
- System status (disk space, memory usage, running processes, Docker containers) is displayed before and after cleanup to verify the effectiveness of the operation