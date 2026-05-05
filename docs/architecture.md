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
│   └── architecture.md     ← this file
├── install.sh              ← main installer
└── README.md
```

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
  └─ PATH, per-host env (sources host/<hostname>.zshenv if present)

$ZDOTDIR/.zprofile          (home/dot-config/zsh/dot-zprofile)
  └─ Homebrew shellenv

$ZDOTDIR/.zshrc             (home/dot-config/zsh/dot-zshrc)
  └─ interactive shell config
```

The two-stage `.zshenv` is necessary: zsh reads `~/.zshenv` before knowing about `ZDOTDIR`.
The first stage sets `ZDOTDIR`, then explicitly sources `$ZDOTDIR/.zshenv` so the rest of
the config can live under XDG.

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
