# actions
Automate your OpenVidu workflows in GitHub Actions

# How to update pined actions

1. Install the `pinact` tool:

```bash
go install github.com/suzuki-shunsuke/pinact/v3/cmd/pinact@<version>
```

2. Execute in the repository with pined actions

```
pinact run -u
```

3. For this particular repository, you need to create a new Release with a new version, and execute `pinact run -u` in the repositories which make use of this particular action.

> Take into account the command updates all actions. If you want to only update one actions you need to revert the other updates...
