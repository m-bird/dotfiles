# dotfiles

Portable dotfiles managed with GNU Stow. See [docs/architecture.md](docs/architecture.md) for design details.

## Requirements

- GNU Stow >= 2.4.0
- zsh
- git

## Install

Install Stow first:

| OS | Command |
| --- | --- |
| macOS / Linux (Homebrew) | `brew install stow` |
| FreeBSD | `pkg install stow` |

Then deploy the public baseline:

```sh
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
sh install.sh
```

## Package management

Core CLI tools for macOS / Linux:

```sh
sh scripts/install-packages.sh
```

Include work-specific tools too:

```sh
sh scripts/install-packages.sh --with-work
```

FreeBSD package automation is not implemented in this repository yet.

## Update

```sh
stow -d ~/.dotfiles -t "$HOME" --dotfiles --no-folding --restow home
```

## Health check

```sh
sh ~/.dotfiles/scripts/doctor.sh
```

## Managed files

All dotfiles live under `home/`, mirroring the `$HOME` layout:

- `home/dot-gitconfig` → `~/.gitconfig`
- `home/dot-zshenv` → `~/.zshenv`
- `home/dot-config/git/` → `~/.config/git/`
- `home/dot-config/zsh/` → `~/.config/zsh/`
- `home/dot-config/tmux/` → `~/.config/tmux/`
- `home/dot-config/nvim/` → `~/.config/nvim/`
