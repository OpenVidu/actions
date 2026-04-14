# Install safe-chain

This GitHub Action installs [AikidoSec safe-chain](https://github.com/AikidoSec/safe-chain) in CI mode.

## Usage

```yaml
steps:
  - name: Install safe-chain
    uses: OpenVidu/actions/install-safe-chain@main
```

## Requirements

- GitHub runner with bash shell
- `curl` available on the runner
