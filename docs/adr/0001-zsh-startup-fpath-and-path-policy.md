# 1. zsh の起動: fpath の正規化と PATH の優先順位

- ステータス: accepted
- 日付: 2026-07-26

## 背景と問題

新しいログインシェルでは次の起動エラーが表示されたが、新しい tmux ペインでは表示されなかった。

```
.zshrc: compinit: function definition file not found
/proc/self/fd/N: command not found: compdef
(eval): add-zsh-hook: function definition file not found
```

調査により、独立した二つの原因と一つの潜在的な不整合が見つかった。

**原因 1 — `.zshenv` が後で設定される変数に依存していた。** `.zshenv` は `$HOMEBREW_PREFIX` と
`$HOMEBREW_CELLAR` から `fpath`（zsh が関数定義ファイルを探すディレクトリの一覧）を再構築していたが、これらは `.zprofile` で実行される `brew shellenv` が
設定する。zsh は `.zprofile` より前に `.zshenv` を読み込むため、新しいログイン時には両方の変数がまだ空であり、
`fpath` は存在しない単一のディレクトリだけになった。その結果 `compinit` が失敗し、`.zshrc` の後半で読み込む
補完スクリプトの `compdef` は未定義のままとなり、プロンプトとディレクトリフックでは `add-zsh-hook` を利用できなかった。

tmux ペインで失敗しなかったのは、tmux サーバーの環境から `HOMEBREW_CELLAR` を継承する非ログインシェルであり、
同じ `fpath` 式が偶然成功したためである。

**原因 2 — `FPATH` が export された変数として伝播する。** `brew shellenv` は `export FPATH` を出力する。
長時間動作するプロセス（たとえばログインシェルから起動した tmux サーバー）がこの値を保持すると、そのプロセスが起動する
すべてのシェルが値を継承する。継承する値にはバージョンを固定した `Cellar/zsh/<version>` ディレクトリが含まれ、
これは `brew upgrade` によって削除される。そのため更新後、継承した `fpath` はもはや存在しないディレクトリを指す。
`HOMEBREW_CELLAR` から `fpath` を再構築するのは、以前にこれを回避しようとした方法であり、原因 1 を引き起こした。

**潜在的な不整合 — PATH の優先順位がシェルの種類ごとに異なっていた。** ユーザー用の PATH 追加
（`~/.local/bin`、`~/bin`、`$PNPM_HOME/bin`）はすべての zsh で実行される `.zshenv` で追加していた。一方、
Homebrew の PATH 要素はログインシェルでのみ実行される `.zprofile` の `brew shellenv` が先頭に追加していた。
その結果、Homebrew と `$PNPM_HOME/bin` の両方に存在するコマンドは、ログインシェルでは Homebrew に解決され、
非ログインシェルでは `$PNPM_HOME/bin` に解決された。

## 検討した選択肢

1. **`.zshenv` にも Homebrew の prefix 候補を列挙する。** 不採用: 「Homebrew がどこにインストールされているか」が
   `.zshenv` と `.zprofile` の両方に記述されることになり、新しい prefix を追加するたびに二か所へ追加する必要がある。
2. **`brew shellenv` を `.zshenv` の先頭へ移動する。** 不採用: 非対話的なスクリプトシェルも含め、zsh を起動するたびに
   サブプロセスを起動し、後続する PATH のブロックより前に `PATH` を変更する。
3. **`fpath` の正規化を `compinit` の直前にある `.zshrc` へ移動する。** 不採用: `.zshrc` は対話的なシェルでしか実行されないため、
   非対話的なシェルでは壊れた `fpath` が残る。
4. **`FPATH` の export を停止し、`fpath` を一切再構築しない。** 不採用: export 属性を削除すれば以後の伝播は防げるが、
   長時間動作する親プロセスが引き続き注入する値は修復できないため、親プロセスを再起動するまでペインは壊れたままとなる。
5. **PATH の方針を `.zshenv` に置き、検出した prefix を使ってそこでは Homebrew の `bin`/`sbin` を先頭に置く。**
   これにより `.zshenv` でコマンド探索パスを設定するという zsh 自身の指針を満たし、サブプロセスも増えない。計測の結果、不採用とした。
   Homebrew の `bin`/`sbin` がすでに `PATH` の先頭にある場合、`brew shellenv` は何も出力しないため、`HOMEBREW_PREFIX`、
   `HOMEBREW_CELLAR`、`HOMEBREW_REPOSITORY`、`INFOPATH` が設定されなくなる。
6. **関心を三つのファイルに分離する**（採用）— 以下を参照。

## 設計判断の結果

選択肢 6 を採用する。責務は次のように分ける。

| ファイル | 責務 |
| --- | --- |
| `lib/brew.zsh` | Homebrew のインストール先を決定する唯一の基準。`ZDOT_HOMEBREW_PREFIX` を export せずに設定する。 |
| `.zshenv` | すべての zsh のシェル内部状態: `fpath` を正規化し、`FPATH` の export 属性を削除する。`PATH` は構築しない。 |
| `.zprofile` | ログイン環境: `brew shellenv zsh` を実行し、`FPATH` の export 属性を再度削除してから、PATH の優先順位を正規化する。 |
| `.zshrc` | 対話的なシェル専用の設定。変更しない。 |

`fpath` は Homebrew の zsh パッケージ定義（formula）が存在する場合だけではなく、無条件に再構築する。既知のディレクトリを先頭に置き、
起動した zsh またはその親が渡した要素は、ディスク上にまだ存在する場合にだけ残す。

```zsh
fpath=(
  "${ZDOT_HOMEBREW_PREFIX:+$ZDOT_HOMEBREW_PREFIX/share/zsh/site-functions}"(N)
  "${ZDOT_HOMEBREW_PREFIX:+$ZDOT_HOMEBREW_PREFIX/opt/zsh/share/zsh/functions}"(N)
  /usr/local/share/zsh/site-functions(N)
  ${^fpath}(N-/)
)
```

二つの詳細は意図的なものである。Homebrew の zsh 関数ディレクトリは、バージョンを固定した
`Cellar/zsh/<version>` パスではなく `opt/zsh` を通して参照する。これは `brew upgrade` が `opt/zsh` を
付け替える一方で、古い `Cellar` ディレクトリを削除するためである。また、各 Homebrew パッケージ定義が補完をインストールする
共有の `share/zsh/site-functions` ディレクトリは `opt/zsh` とは独立して検査する。そのため Homebrew が存在しても
システムの zsh を使用するマシンでも、それらの補完を利用できる。

PATH の優先順位は、`brew shellenv` の実行後に `.zprofile` で一度だけ正規化する。

```
Homebrew bin/sbin -> ~/.local/bin -> ~/bin -> $PNPM_HOME/bin -> 継承された残りの PATH
```

## 結果

利点:

- 新しいログインシェルがエラーなしで起動し、`compinit`、`compdef`、`add-zsh-hook` を利用できる。
- `fpath` は手作業なしで `brew upgrade` に耐える。
- 四つの起動モードのいずれでも、`FPATH` が export された変数として zsh の外へ渡らないため、長時間動作する
  親プロセスを介した自己永続的な伝播を発生源で止められる。
- 同じコマンド名は、ログインシェルと非ログインシェルで同じファイルに解決される。

欠点または制限:

- ログインシェルを祖先に持たない非ログインシェル、すなわち cron ジョブまたは systemd サービスから直接起動したシェルには、
  ユーザー用の PATH 追加は渡らない。これはこれらの実行環境の仕様に沿う。POSIX は起動元の環境から独立した cron ジョブ用の
  デフォルト環境を定義し、systemd は意図的に検証済みの少数の変数だけをサービスに公開する。特定のジョブでこれらの
  ディレクトリが必要な場合は、そのジョブの `PATH` を明示的に設定する（crontab の `PATH=` 行、unit の
  `Environment=`/`EnvironmentFile=`、またはユーザーサービス向けの `~/.config/environment.d/*.conf`）。
- `.zshenv` は zsh を起動するたびに `/etc/profile.d/*.sh` を読み込み、それらのスクリプトが独自の要素を先頭に追加するため、
  絶対的な `PATH` 文字列はログインシェルとその子プロセスで依然として異なる。この方針が管理する要素の相対的な順序だけを保証する。
- 継承した `fpath` が完全に古くなっており、かつ Homebrew を検出できない場合、zsh の基本関数ディレクトリは復元できず、
  `compinit` は失敗する。この状態から復元するには、別の `zsh -f` から初期状態の `fpath` を取得する必要があり、
  `.zshenv` には手間がかかりすぎる。この組み合わせはサポート対象外とする。
- `PNPM_HOME` とその PATH 要素は、現在それぞれ `.zshenv` と `.zprofile` にある。`pnpm setup` を実行すると、
  pnpm 自身のブロックが `.zshrc` に再追加される。このブロックが現れた場合は再び削除する必要がある。`scripts/doctor.sh` は
  これを検査しない。

## 検証

- 四つの起動モード（ログイン/非ログイン × 対話的/非対話的）を、古い export 済み `FPATH` の有無それぞれで確認した。
  子プロセスの環境には `FPATH` がなく、`fpath` に古い要素が残らない。
- フィクスチャ構成: zsh パッケージ定義がない Homebrew、`share/zsh/site-functions` がない Homebrew、Homebrew がない構成、
  古い継承要素と有効な継承要素が混在する構成。
- ログインシェルとその非ログインの子プロセスで、コマンドの解決と PATH の相対順序を確認した。
- `scripts/doctor.sh` がすべてのチェックで OK を報告する。
