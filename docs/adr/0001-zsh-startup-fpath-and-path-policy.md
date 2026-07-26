# 1. zsh startup: fpath normalization and PATH precedence

- Status: accepted
- Date: 2026-07-26

## Context and Problem Statement

A fresh login shell printed these startup errors, while a new tmux pane did not:

```
.zshrc: compinit: function definition file not found
/proc/self/fd/N: command not found: compdef
(eval): add-zsh-hook: function definition file not found
```

Investigation found two independent causes and one latent inconsistency.

**Cause 1 — `.zshenv` depended on variables that are set later.** `.zshenv` rebuilt `fpath`
from `$HOMEBREW_PREFIX` and `$HOMEBREW_CELLAR`, but those are set by `brew shellenv`, which runs
in `.zprofile`. zsh reads `.zshenv` before `.zprofile`, so on a fresh login both variables were
still empty and `fpath` collapsed to a single non-existent directory. `compinit` then failed,
leaving `compdef` undefined for the completion scripts sourced later in `.zshrc`, and
`add-zsh-hook` unavailable to the prompt and directory hooks.

A tmux pane did not fail because it is a non-login shell that inherits `HOMEBREW_CELLAR` from the
tmux server's environment, so the same `fpath` expression happened to succeed.

**Cause 2 — `FPATH` propagates as an exported variable.** `brew shellenv` emits
`export FPATH`. Once a long-lived process (for example a tmux server started from a login shell)
holds that value, every shell it spawns inherits it. The inherited value contains a
version-pinned `Cellar/zsh/<version>` directory, which `brew upgrade` removes — so after an
upgrade the inherited `fpath` points at a directory that no longer exists. Rebuilding `fpath`
from `HOMEBREW_CELLAR` was the previous attempt to work around this, and it is what introduced
Cause 1.

**Latent inconsistency — PATH precedence differed by shell type.** User PATH additions
(`~/.local/bin`, `~/bin`, `$PNPM_HOME/bin`) were added in `.zshenv`, which runs for every zsh,
whereas Homebrew's PATH entries were prepended by `brew shellenv` in `.zprofile`, which runs only
for login shells. As a result a command present in both Homebrew and `$PNPM_HOME/bin` resolved to
Homebrew in a login shell and to `$PNPM_HOME/bin` in a non-login shell.

## Considered Options

1. **Enumerate Homebrew prefix candidates in `.zshenv` as well.** Rejected: "where is Homebrew
   installed" would then be encoded in both `.zshenv` and `.zprofile`, and every new prefix would
   have to be added twice.
2. **Move `brew shellenv` to the top of `.zshenv`.** Rejected: it spawns a subprocess on every
   zsh start, including non-interactive script shells, and it mutates `PATH` before the PATH
   block that follows it.
3. **Move `fpath` normalization to `.zshrc`, just before `compinit`.** Rejected: `.zshrc` runs
   only for interactive shells, so non-interactive shells would keep a broken `fpath`.
4. **Stop exporting `FPATH` and do not rebuild `fpath` at all.** Rejected: removing the export
   attribute prevents further propagation but does not repair a value that a long-lived parent is
   still injecting, so panes stay broken until that parent restarts.
5. **Keep the PATH policy in `.zshenv` and place Homebrew's `bin`/`sbin` first there, using the
   detected prefix.** This would satisfy zsh's own guidance to configure the command search path
   in `.zshenv`, and adds no subprocess. Rejected on measurement: when Homebrew's `bin`/`sbin`
   already lead `PATH`, `brew shellenv` produces no output at all, so `HOMEBREW_PREFIX`,
   `HOMEBREW_CELLAR`, `HOMEBREW_REPOSITORY` and `INFOPATH` would never be set.
6. **Separate the concerns across three files** (chosen) — see below.

## Decision Outcome

Option 6. Responsibilities are split as follows:

| File | Responsibility |
| --- | --- |
| `lib/brew.zsh` | The single authority for where Homebrew is installed. Sets `ZDOT_HOMEBREW_PREFIX`, unexported. |
| `.zshenv` | Shell-internal state for every zsh: normalize `fpath`, and remove `FPATH`'s export attribute. Does not build `PATH`. |
| `.zprofile` | Login environment: run `brew shellenv zsh`, remove `FPATH`'s export attribute again, then normalize PATH precedence. |
| `.zshrc` | Interactive-only configuration. Unchanged. |

`fpath` is rebuilt unconditionally rather than only when Homebrew's zsh formula is present. Known
directories are placed first, and whatever the invoked zsh or its parent supplied is kept only if
it still exists on disk:

```zsh
fpath=(
  "${ZDOT_HOMEBREW_PREFIX:+$ZDOT_HOMEBREW_PREFIX/share/zsh/site-functions}"(N)
  "${ZDOT_HOMEBREW_PREFIX:+$ZDOT_HOMEBREW_PREFIX/opt/zsh/share/zsh/functions}"(N)
  /usr/local/share/zsh/site-functions(N)
  ${^fpath}(N-/)
)
```

Two details are deliberate. The Homebrew zsh functions directory is referenced through `opt/zsh`
rather than a version-pinned `Cellar/zsh/<version>` path, because `brew upgrade` retargets
`opt/zsh` but removes the old `Cellar` directory. And the shared `share/zsh/site-functions`
directory — where any Homebrew formula installs its completions — is tested independently of
`opt/zsh`, so a machine that has Homebrew but uses the system zsh still gets those completions.

PATH precedence is normalized once, in `.zprofile`, after `brew shellenv` has run:

```
Homebrew bin/sbin -> ~/.local/bin -> ~/bin -> $PNPM_HOME/bin -> the remaining inherited PATH
```

## Consequences

Positive:

- A fresh login shell starts without errors, and `compinit`, `compdef` and `add-zsh-hook` are
  available.
- `fpath` survives `brew upgrade` without manual intervention.
- `FPATH` never leaves a zsh as an exported variable, in any of the four startup modes, so the
  self-perpetuating propagation through long-lived parents is stopped at the source.
- A given command name resolves to the same file in login and non-login shells.

Negative or bounded:

- A non-login shell with no login-shell ancestor — one started directly by a cron job or a
  systemd service — does not receive the user PATH additions. This matches how those execution
  environments are specified: POSIX defines a default environment for cron jobs independent of
  the invoking environment, and systemd deliberately exposes only a small vetted set of variables
  to services. Where a specific job needs these directories, set `PATH` for that job explicitly
  (a `PATH=` line in the crontab, `Environment=`/`EnvironmentFile=` on the unit, or
  `~/.config/environment.d/*.conf` for user services).
- The absolute `PATH` string still differs between a login shell and its children, because
  `.zshenv` sources `/etc/profile.d/*.sh` on every zsh start and those scripts prepend their own
  entries. Only the relative order of the entries this policy manages is guaranteed.
- If the inherited `fpath` is entirely stale *and* Homebrew cannot be detected, the core zsh
  function directory cannot be recovered and `compinit` will fail. Recovering from that would
  require obtaining a pristine `fpath` from a separate `zsh -f`, which is too much machinery for
  `.zshenv`. This combination is treated as outside the supported range.
- `PNPM_HOME` and its PATH entry now live in `.zshenv` and `.zprofile` respectively. Running
  `pnpm setup` re-appends pnpm's own block to `.zshrc`; that block should be removed again when
  it appears. `scripts/doctor.sh` does not check for it.

## Verification

- Four startup modes (login/non-login × interactive/non-interactive), with and without a stale
  exported `FPATH`: no `FPATH` in the child environment, and no stale entry left in `fpath`.
- Fixture configurations: Homebrew present without its zsh formula; Homebrew present without
  `share/zsh/site-functions`; no Homebrew at all; a mix of stale and valid inherited entries.
- Command resolution and relative PATH order checked in a login shell and in its non-login
  children.
- `scripts/doctor.sh` reports all checks OK.
