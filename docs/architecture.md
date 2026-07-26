# Architecture

## Overview

Portable dotfiles managed with GNU Stow using the **Hardened Stow Overlay** pattern.
Public and private configurations are kept in separate, independent repositories applied in order.

## Directory layout

```
~/.dotfiles/                ← this repository (public baseline)
├── home/                   ← single Stow package; mirrors $HOME layout
│   ├── dot-gitconfig       → ~/.gitconfig
│   ├── dot-zshenv          → ~/.zshenv
│   └── dot-config/
│       ├── git/            → ~/.config/git/
│       ├── zsh/            → ~/.config/zsh/
│       │   └── lib/brew.zsh → ~/.config/zsh/lib/brew.zsh
│       ├── tmux/           → ~/.config/tmux/
│       └── nvim/           → ~/.config/nvim/
├── scripts/
│   ├── lib.sh              ← shared shell functions (stow_version_ok)
│   ├── doctor.sh           ← health check
│   └── install-packages.sh ← Homebrew Brewfile installer
├── packages/
│   ├── Brewfile            ← core Homebrew packages
│   └── Brewfile.work       ← work-specific packages (git-excluded)
├── docs/
│   ├── architecture.md     ← this file (current shape)
│   └── adr/                ← decision records (why it is shaped this way)
├── install.sh              ← main installer
└── README.md
```

This file describes the configuration as it is now. The reasoning behind each choice, the
alternatives that were rejected, and what those choices cost live in [`adr/`](adr/README.md).

## Stow conventions

Stow is invoked as:

```sh
stow -d "$REPO_DIR" -t "$HOME" --dotfiles --no-folding home
```

- **`--dotfiles`**: translates `dot-` filename prefix to `.` in the deployed symlink name.
  Example: `home/dot-zshenv` → `~/.zshenv`, `home/dot-config/zsh/` → `~/.config/zsh/`
- **`--no-folding`**: never creates directory symlinks; always creates real directories and
  symlinks individual files. Required so that XDG directories (`~/.config/zsh/` etc.) remain
  real directories that multiple packages and tools can write into.
- **Requires GNU Stow >= 2.4.0** — first release that supports `--dotfiles` for both files and directories.

## zsh bootstrap sequence

zsh resolves startup files in this order:

```
~/.zshenv                   (home/dot-zshenv)
  └─ sets XDG_CONFIG_HOME, ZDOTDIR=$HOME/.config/zsh
  └─ sources $ZDOTDIR/.zshenv

$ZDOTDIR/.zshenv            (home/dot-config/zsh/dot-zshenv)
  └─ sets PNPM_HOME; sources lib/brew.zsh; normalizes fpath; sources per-host env
  └─ does not build PATH; removes FPATH's export attribute at the end

$ZDOTDIR/.zprofile          (home/dot-config/zsh/dot-zprofile)
  └─ runs brew shellenv zsh for the detected ZDOT_HOMEBREW_PREFIX; removes FPATH's export attribute again
  └─ normalizes PATH precedence

$ZDOTDIR/.zshrc             (home/dot-config/zsh/dot-zshrc)
  └─ interactive shell config
```

The two-stage `.zshenv` is necessary: zsh reads `~/.zshenv` before knowing about `ZDOTDIR`.
The first stage sets `ZDOTDIR`, then explicitly sources `$ZDOTDIR/.zshenv` so the rest of
the config can live under XDG.

`.zshenv`, `.zprofile`, and `.zshrc` are not reusable modules intended to be sourced
independently; they rely on zsh's standard startup order.

`lib/brew.zsh` is the single authority for determining the Homebrew installation location. It
sets `ZDOT_HOMEBREW_PREFIX` without exporting it. Because `.zshenv` runs before `brew shellenv`,
it cannot depend on `HOMEBREW_PREFIX` or `HOMEBREW_CELLAR` at that stage. When Homebrew zsh is
available, fpath uses `opt/zsh` rather than a versioned `Cellar/zsh/<version>` path so it follows
`brew upgrade`. `brew shellenv zsh` exports `FPATH`; `.zprofile` retains its value while
removing its export attribute.

## PATH policy

The long-term policy is that Homebrew takes precedence for package-manager-managed commands.
Consequently, in a login shell the effective order is Homebrew `bin`/`sbin`, `~/.local/bin`,
`~/bin`, `PNPM_HOME/bin`, then the remaining inherited `PATH`. Non-login shells do not run
`.zprofile`; they rely on inheriting this order from their parent login shell. A non-login shell
without a login shell ancestor, such as one started directly by a cron job or systemd service,
does not receive these user-specific PATH additions.

Only the relative order of the entries listed above is guaranteed. The absolute `PATH` string
still differs between a login shell and its children, because `.zshenv` sources
`/etc/profile.d/*.sh` on every zsh startup and those scripts prepend their own entries.

Rationale and rejected alternatives: [ADR 0001](adr/0001-zsh-startup-fpath-and-path-policy.md).

## Public / private overlay

Two independent repositories, applied in order:

1. **public** (`~/.dotfiles`): this repo — portable baseline, no secrets
2. **private** (separate repo): machine-local and personal configs; applied after public

Files excluded from the public repo (`.gitignore`):

| Path | Reason |
| --- | --- |
| `home/dot-config/zsh/host/` | per-host env vars |
| `home/dot-config/git/config.local` | git user identity |
| `home/dot-config/git/config.work` | work git config |
| `home/dot-config/git/config.personal` | personal git config |

## install.sh flow

```
check_stow           version >= 2.4.0
create_dirs          non-stow-managed dirs (~/.local/state/zsh, ~/.cache/zsh, config.local)
backup_conflicts     back up real files that stow would refuse to overwrite (first install only)
apply_stow           stow --restow home
```
