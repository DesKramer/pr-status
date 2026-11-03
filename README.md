# PR Status

<img width="404" height="625" alt="Screenshot 2026-11-03 at 09 56 46" src="https://github.com/user-attachments/assets/f2c64c9f-2134-45f7-981c-30eb2a973fd8" />


A small macOS menu bar app for open pull requests authored by you in `CosineAI/cosine-monorepo`.

It shows:

- Branch name and PR number
- Passing, failed, and running CI checks
- Approval or changes-requested status
- Draft status

Click a PR to open it on GitHub in Google Chrome. The app refreshes every two minutes and has a manual refresh button.

## Requirements

- macOS 14 or newer
- Xcode command line tools
- [GitHub CLI](https://cli.github.com/) installed and authenticated with access to the repository

Check authentication with:

```sh
gh auth status
```

## Build and run

```sh
make run
```

To install the app in `~/Applications`:

```sh
make install
```

The app uses the existing `gh` login. It does not store a GitHub token.

To start it when you log in, add `PR Status` under System Settings, General, Login Items after installing it.

## Development

```sh
make build
make test
```
