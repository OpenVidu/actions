# Build OpenVidu Components Angular

This GitHub Action builds and packages the OpenVidu Components Angular library as a GitHub artifact.

## Description

This action automates the process of building the OpenVidu Components Angular library by:

1. Checking out the OpenVidu Components Angular repository
2. Building the library using npm and Node.js from the runner environment
3. Packaging the library as a `.tgz` file
4. Uploading it as a GitHub Actions artifact for use by other steps

## Inputs

| Parameter       | Description                                                        | Required | Default                       |
| --------------- | ------------------------------------------------------------------ | -------- | ----------------------------- |
| `repository`    | Repository to checkout for OpenVidu Components Angular             | No       | `OpenVidu/openvidu`           |
| `checkout_ref`  | Branch, tag, or commit to checkout                                 | No       | `master`                      |
| `artifact_name` | Name of the artifact to upload (will be made unique automatically) | No       | `openvidu-components-angular` |

## Outputs

| Output             | Description                                        |
| ------------------ | -------------------------------------------------- |
| `artifact_name`    | Name of the uploaded artifact (with unique suffix) |
| `package_filename` | Filename of the built package                      |

## Usage

### Basic Usage

```yaml
steps:
    - name: Build OpenVidu Components Angular
      id: build
      uses: OpenVidu/actions/build-openvidu-components-angular@main
      with:
          checkout_ref: 'v3.0.0'

    - name: Download the built package
      uses: actions/download-artifact@v4
      with:
          name: ${{ steps.build.outputs.artifact_name }} # Use the output, not the input!
          path: './my-components'
```

### Build with Custom Artifact Name

```yaml
steps:
    - name: Build OpenVidu Components Angular
      id: build
      uses: OpenVidu/actions/build-openvidu-components-angular@main
      with:
          checkout_ref: 'master'
          artifact_name: 'my-custom-components'

    - name: Use the artifact in later steps
      uses: actions/download-artifact@v4
      with:
          name: ${{ steps.build.outputs.artifact_name }} # Will be something like 'my-custom-components-12345-1'
          path: './components'
```

## Requirements

-   Node.js environment must be available in the runner (typically pre-installed in GitHub runners)
-   npm must be available for package management

## Notes

-   The action uses the runner's Node.js environment for building
-   The built package follows npm's standard naming convention
-   The action is designed to be reusable across different workflows
-   The built package is automatically uploaded as a GitHub Actions artifact
-   Artifacts are temporary and will be automatically deleted after the workflow retention period
-   No cleanup is performed - the source code remains in the `components-source` directory

### Artifact Naming and Parallel Execution

-   **Unique naming**: Artifact names are automatically made unique using `{name}-{run_id}-{run_attempt}` to prevent conflicts
-   **Parallel safety**: Multiple workflows can run this action simultaneously without conflicts
-   **Output usage**: Always use the `artifact_name` output instead of the input when referencing the artifact in subsequent steps
-   **Example**: Input `my-components` becomes `my-components-12345-1` in the artifact store
