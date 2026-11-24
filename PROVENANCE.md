# Provenance

This repository is the **BROADMIND build of the OpenBCI GUI**, published as a standalone
repository. It is not a GitHub fork: the git history here starts at a single snapshot commit,
so there is no upstream ancestry and no "forked from" badge. The provenance that would have
been visible in a fork history is written here instead, which is the point of this file.

## Where the code came from

| | |
|---|---|
| **Upstream** | [`OpenBCI/OpenBCI_GUI`](https://github.com/OpenBCI/OpenBCI_GUI) |
| **Base commit** | `d8543aaf` — "Merge pull request #1197 from OpenBCI/development", 2023-09-28 |
| **First BROADMIND commit** | `f9901c77` — "Apply the BROADMIND 2026-27 brand system to the GUI", 2026-11-16 |
| **Last commit carried over** | `34c4970b` — 2026-11-23, from `BROADMIND-BCI/broadmind-gui` (the earlier fork) |
| **Licence** | MIT — `LICENSE`, © 2018 OpenBCI, retained verbatim |

Every upstream author credit, the MIT licence text and the third-party notices that ship
inside the application are unchanged.

## What BROADMIND changed

Presentation, packaging and build tooling only:

- the BROADMIND 2026–27 brand system — black, white and one grey, Geometria where licensed and
  installed, Arial otherwise, functional colours (channel identity, error states) preserved;
- the first-run experience, the session view and the macOS packaging/bundle step;
- the Cyton-over-USB scope for release 0.3.0, and the Cyton emulator used to exercise the UI
  without hardware;
- the README, screenshots and demo media.

Acquisition, board support and the OpenBCI protocol code are untouched. Fixes for anything in
that layer belong upstream, not here.

## What is *not* claimable from this repository

The GUI's presence here does not make the hardware specification independently verified. The
noise floor, bandwidth and tolerance figures on broadmind.me are the company's own and are
described as provisional there; see the internal claims register.

## Syncing with upstream

GitHub can no longer offer a one-click "sync fork", so the upstream remote is a plain remote:

```sh
git remote add upstream https://github.com/OpenBCI/OpenBCI_GUI.git
git fetch upstream
git diff upstream/master --stat      # what changed upstream since d8543aaf
```

Merge or cherry-pick selectively onto `main`. Because the histories are unrelated, use
`git diff`/`git apply`, `git format-patch | git am`, or a `--allow-unrelated-histories` merge
made deliberately and reviewed — never as an accident.

## Release history

| Release | Where | Note |
|---|---|---|
| `v0.3.0-alpha.1` | this repository | 0.3.0 Alpha — Cyton over USB, Apple Silicon macOS |
| `v0.2.2-beta.1` | `BROADMIND-BCI/openbci-gui-fork` (archived fork) | earlier beta, kept for the record |

## No affiliation

BROADMIND is not affiliated with, endorsed by or sponsored by OpenBCI. The device is
compatible with the OpenBCI Cyton protocol over USB, which is why BrainFlow maps it to
`CYTON_BOARD`; that is a compatibility statement, not a partnership. The OpenBCI name and marks
belong to their owners.
