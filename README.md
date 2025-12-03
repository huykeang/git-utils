# 🧹 git-utils

A small collection of custom Git utilities for branch maintenance and cleanup.
Currently includes:

- `git branches-report` — generate a report of remote branches filtered by author, name pattern, and date. Useful for reviewing stale or outdated branches before cleanup.
- `git cleanup-branches` — interactively delete remote branches that match specific filters (author, pattern, date) with confirmation for each branch.
- `git clone-gitlab-group-repos` — clone all repositories from a GitLab group (supports subgroups, pagination, and private/self-hosted GitLab instances).

## 🚀 Installation

Run the one-liner below to install these Git utilities on your machine:

```bash
curl -sSL https://raw.githubusercontent.com/huykeang/git-utils/main/install.sh | bash
```

This will:
- Clone the repo to `~/.git-utils`
- Add it to your PATH automatically
- Make the scripts available as Git subcommands like `git cleanup-branches` or `git branches-report` or `git clone-gitlab-group-repos`

## 🧩 Usage

Once installed, you can run:
```bash
git cleanup-branches
```
or
```bash
git branches-report
```
or
```bash
git clone-gitlab-group-repos https://stage-gitlab.company.com/eco/unified/backend
```
Each command will guide you interactively through prompts for author, branch pattern, and date filters.

## Demo
https://github.com/user-attachments/assets/d5dc1e90-3aa1-4e2d-b684-d990a85bb4d1


