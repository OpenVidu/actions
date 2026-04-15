# Install safe-chain

This GitHub Action installs [AikidoSec safe-chain](https://github.com/AikidoSec/safe-chain) in CI mode.

## Usage

```yaml
steps:
  - name: Install safe-chain
    uses: OpenVidu/actions/install-safe-chain@main
```

With a custom minimum package age:

```yaml
steps:
  - name: Install safe-chain
    uses: OpenVidu/actions/install-safe-chain@main
    with:
      minimum-package-age-hours: '24'
```

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `minimum-package-age-hours` | No | `0` | Minimum package age (in hours) enforced by safe-chain via the `SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS` environment variable. |

## Minimum Package Age

> [!WARNING]
> By default, this action sets `SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS=0`, meaning safe-chain will **only block packages currently flagged as malware** and will **not** reject packages based on how recently they were published.
>
> This trade-off is intentional: a non-zero minimum age can break CI pipelines that legitimately need to consume freshly published packages (for example, right after an internal release). The downside is that very recent supply-chain attacks may not yet be flagged, reducing the protection window.
>
> If your project can tolerate a delay before consuming newly published packages, we strongly recommend raising this value (e.g. `24` or `48` hours) via the `minimum-package-age-hours` input.

## Requirements

- GitHub runner with bash shell
- `curl` available on the runner

## Docs

Try to keep this document updated every time `safe-chain` is used across repositories: https://github.com/OpenVidu/openvidu-github-actions/blob/master/docs/safe-chain-usage.md
