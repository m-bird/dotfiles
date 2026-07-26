# dotfiles

GNU Stow で管理する移植可能な dotfiles。設計の詳細は [docs/architecture.md](docs/architecture.md) を参照すること。

## 必要なもの

- GNU Stow >= 2.4.0
- zsh
- git

## インストール

まず Stow をインストールする。

| OS | コマンド |
| --- | --- |
| macOS / Linux (Homebrew) | `brew install stow` |
| FreeBSD | `pkg install stow` |

次に公開用の基本構成を配置する。

```sh
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
sh install.sh
```

## パッケージ管理

macOS / Linux 向けの基本的な CLI ツール:

```sh
sh scripts/install-packages.sh
```

業務用ツールも含める場合:

```sh
sh scripts/install-packages.sh --with-work
```

FreeBSD のパッケージ自動化は、このリポジトリではまだ実装されていない。

## 更新

```sh
stow -d ~/.dotfiles -t "$HOME" --dotfiles --no-folding --restow home
```

## 状態確認

```sh
sh ~/.dotfiles/scripts/doctor.sh
```

## 管理対象ファイル

すべての dotfiles は `$HOME` の構成を反映した `home/` 配下にある。

- `home/dot-gitconfig` → `~/.gitconfig`
- `home/dot-zshenv` → `~/.zshenv`
- `home/dot-config/git/` → `~/.config/git/`
- `home/dot-config/zsh/` → `~/.config/zsh/`
- `home/dot-config/tmux/` → `~/.config/tmux/`
- `home/dot-config/nvim/` → `~/.config/nvim/`
