# actions
Automate your OpenVidu workflows in GitHub Actions

# How to update pinned actions from OpenVidu/actions repository

Run the workflow [Release and Update Pinned Actions](https://github.com/OpenVidu/actions/actions/workflows/update-pinned-actions.yml).

It will:
1. Create a new release of OpenVidu
2. Update all references to OpenVidu/actions in all repositories in the OpenVidu organization (in their default branch).
3. Create a PR in each repository with the changes.
