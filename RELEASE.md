# Release Process

Releases are automated through GitHub Actions. This document describes the manual steps and the secrets the workflow needs.

## Prerequisites

### 1. A signing key registered with GitHub

The release tag must be signed so it shows a **Verified** badge on GitHub. SSH signing is used.

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519
git config --global tag.gpgsign true
```

The matching **public** key (`~/.ssh/id_ed25519.pub`) must be registered as a *Signing Key* on GitHub:
**https://github.com/settings/ssh/new** — choose "Signing Key" as the key type.

### 2. The `TAP_TOKEN` secret

The release workflow updates the Homebrew formula in `sametcelikbicak/homebrew-tap` after every release. That is a cross-repository push, so it needs a token with write access to that repository only.

Create a **fine-grained personal access token** at https://github.com/settings/personal-access-tokens/new:

| Field | Value |
|-------|-------|
| Token name | `vidfix-tap-updater` |
| Expiration | 90 days |
| Resource owner | `sametcelikbicak` |
| Repository access | Only select repositories → `homebrew-tap` |
| Repository permissions | Contents → Read and write |

Add it to the repository at
**https://github.com/sametcelikbicak/vidfix/settings/secrets/actions/new**
as a repository secret named `TAP_TOKEN`.

Without this secret the release still succeeds; only the automatic formula update is skipped and the checksum has to be updated by hand (see *Manual fallback* below).

## Bump the version

Every version number lives in four places:

| File | Field |
|------|-------|
| `bin/vidfix` | `VERSION="1.0.0"` |
| `install.sh` | `VERSION="1.0.0"` |
| `README.md`, `README_TR.md` | install URL `.../v1.0.0/install.sh` |
| `../homebrew-tap/Formula/vidfix.rb` | `version` and `url` (kept in sync automatically by CI, but update the url for the first release) |

## Create and push a signed tag

```bash
git tag -s v1.0.0 -m "chore: release v1.0.0"
git push origin v1.0.0
```

> Always use `git tag -s` (signed tag) instead of `git tag`. Unsigned tags will not show a "Verified" badge on GitHub. See [GitHub's signing guide](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-tags).

Verify before pushing:

```bash
git tag -v v1.0.0
```

## CI handles the rest

GitHub Actions on the tag push:

- packs `bin/vidfix`, `install.sh`, the READMEs and the LICENSE into `vidfix-<version>.tar.gz`
- writes the matching `.sha256` file
- publishes both as a GitHub release
- updates `Formula/vidfix.rb` in `sametcelikbicak/homebrew-tap` with the new version and checksum, then pushes that commit

## Manual fallback

If the tap update did not run (missing or expired `TAP_TOKEN`):

```bash
cd ../homebrew-tap
SHA="$(shasum -a 256 ~/Downloads/vidfix-1.0.0.tar.gz | awk '{print $1}')"
sed -i '' "s|sha256 \".*\"|sha256 \"$SHA\"|" Formula/vidfix.rb
git commit -am "vidfix 1.0.0"
git push
```

## Verifying an installation

```bash
brew tap sametcelikbicak/tap https://github.com/sametcelikbicak/homebrew-tap
brew trust sametcelikbicak/tap
brew install vidfix
vidfix check ~/Movies/sample.mp4
```
