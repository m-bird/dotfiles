# アーキテクチャ

## 概要

**堅牢化した Stow オーバーレイ** パターンを用いて GNU Stow で管理する移植可能な dotfiles である。
公開用と非公開用の設定は、独立した別々のリポジトリで管理し、順に適用する。

## ディレクトリ構成

```
~/.dotfiles/                ← このリポジトリ（公開用の基本構成）
├── home/                   ← 単一の Stow パッケージ。$HOME の構成を反映する
│   ├── dot-gitconfig       → ~/.gitconfig
│   ├── dot-zshenv          → ~/.zshenv
│   └── dot-config/
│       ├── git/            → ~/.config/git/
│       ├── zsh/            → ~/.config/zsh/
│       │   └── lib/brew.zsh → ~/.config/zsh/lib/brew.zsh
│       ├── tmux/           → ~/.config/tmux/
│       └── nvim/           → ~/.config/nvim/
├── scripts/
│   ├── lib.sh              ← 共通のシェル関数（stow_version_ok）
│   ├── doctor.sh           ← 状態確認
│   └── install-packages.sh ← Homebrew Brewfile インストーラー
├── packages/
│   ├── Brewfile            ← 基本の Homebrew パッケージ
│   └── Brewfile.work       ← 業務用パッケージ（git の管理対象外）
├── docs/
│   ├── architecture.md     ← このファイル（現在の構成）
│   └── adr/                ← 設計判断の記録（この構成にした理由）
├── install.sh              ← メインのインストーラー
└── README.md
```

このファイルでは現在の設定を説明する。各選択の理由、採用しなかった代替案、各選択による負担は
[`adr/`](adr/README.md) に記録する。

## Stow の規則

Stow は次のように実行する。

```sh
stow -d "$REPO_DIR" -t "$HOME" --dotfiles --no-folding home
```

- **`--dotfiles`**: ファイル名の `dot-` 接頭辞を、配置先のシンボリックリンク名では `.` に変換する。
  例: `home/dot-zshenv` → `~/.zshenv`、`home/dot-config/zsh/` → `~/.config/zsh/`
- **`--no-folding`**: ディレクトリへのシンボリックリンクは作成せず、常に実ディレクトリを作成して
  個々のファイルをシンボリックリンクにする。複数のパッケージやツールが書き込める実ディレクトリとして、
  XDG ディレクトリ（`~/.config/zsh/` など）を維持するために必要である。
- **GNU Stow >= 2.4.0 が必要** — ファイルとディレクトリの両方で `--dotfiles` を初めてサポートしたリリースである。

## zsh の起動準備の順序

zsh は次の順序で起動ファイルを読み込む。

```
~/.zshenv                   (home/dot-zshenv)
  └─ XDG_CONFIG_HOME、ZDOTDIR=$HOME/.config/zsh を設定する
  └─ $ZDOTDIR/.zshenv を読み込む

$ZDOTDIR/.zshenv            (home/dot-config/zsh/dot-zshenv)
  └─ PNPM_HOME を設定する。lib/brew.zsh を読み込む。fpath を正規化する。ホストごとの環境を読み込む
  └─ PATH を構築しない。最後に FPATH の export 属性を削除する

$ZDOTDIR/.zprofile          (home/dot-config/zsh/dot-zprofile)
  └─ 検出した ZDOT_HOMEBREW_PREFIX に対して brew shellenv zsh を実行する。FPATH の export 属性を再び削除する
  └─ PATH の優先順位を正規化する

$ZDOTDIR/.zshrc             (home/dot-config/zsh/dot-zshrc)
  └─ 対話シェルの設定
```

二段階の `.zshenv` が必要なのは、zsh が `ZDOTDIR` を知る前に `~/.zshenv` を読み込むためである。
第一段階で `ZDOTDIR` を設定し、続いて明示的に `$ZDOTDIR/.zshenv` を読み込むことで、残りの
設定を XDG 配下に置けるようにする。

`.zshenv`、`.zprofile`、`.zshrc` は、個別に読み込んで再利用することを意図したモジュールではない。
これらは zsh の標準的な起動順序に依存する。

`lib/brew.zsh` は Homebrew のインストール先を決定する唯一の基準である。ここで
`ZDOT_HOMEBREW_PREFIX` を export せずに設定する。`.zshenv` は `brew shellenv` より先に実行されるため、
この段階では `HOMEBREW_PREFIX` や `HOMEBREW_CELLAR` に依存できない。Homebrew の zsh が利用可能な場合、
`brew upgrade` に追従できるように、fpath（zsh が関数定義ファイルを探すディレクトリの一覧）ではバージョン付きの `Cellar/zsh/<version>` パスではなく
`opt/zsh` を使用する。`brew shellenv zsh` は `FPATH` を export する。`.zprofile` は値を保ったまま
export 属性を削除する。

## PATH の方針

長期的な方針として、パッケージマネージャーが管理するコマンドでは Homebrew を優先する。
したがってログインシェルでの実効的な順序は、Homebrew の `bin`/`sbin`、`~/.local/bin`、
`~/bin`、`PNPM_HOME/bin`、残りの継承した `PATH` となる。非ログインシェルでは `.zprofile` を実行せず、
親のログインシェルからこの順序を継承する。cron ジョブや systemd サービスから直接起動したものなど、
ログインシェルを祖先に持たない非ログインシェルには、これらのユーザー固有の PATH 追加は渡らない。

保証するのは、上に挙げた要素の相対的な順序だけである。`.zshenv` は zsh を起動するたびに
`/etc/profile.d/*.sh` を読み込み、それらのスクリプトが独自の要素を先頭に追加するため、絶対的な `PATH` 文字列は
ログインシェルとその子プロセスで依然として異なる。

理由と採用しなかった代替案: [ADR 0001](adr/0001-zsh-startup-fpath-and-path-policy.md)。

## 公開用 / 非公開用のオーバーレイ

独立した二つのリポジトリを次の順に適用する。

1. **公開用** (`~/.dotfiles`): このリポジトリ。移植可能な基本構成で、秘密情報は含まない。
2. **非公開用** （別リポジトリ）: マシン固有および個人用の設定。公開用の後に適用する。

公開リポジトリから除外するファイル（`.gitignore`）:

| パス | 理由 |
| --- | --- |
| `home/dot-config/zsh/host/` | ホストごとの環境変数 |
| `home/dot-config/git/config.local` | git のユーザー識別情報 |
| `home/dot-config/git/config.work` | 業務用 git 設定 |
| `home/dot-config/git/config.personal` | 個人用 git 設定 |

## install.sh の流れ

```
check_stow           バージョンが 2.4.0 以上か確認する
create_dirs          stow の管理外のディレクトリを作成する（~/.local/state/zsh、~/.cache/zsh、config.local）
backup_conflicts     stow が上書きを拒否する実ファイルを退避する（初回インストール時のみ）
apply_stow           stow --restow home を実行する
```
