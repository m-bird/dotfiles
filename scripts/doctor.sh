#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STATUS=0

. "$REPO_DIR/scripts/lib.sh"

ok() {
  printf '[doctor] OK    %s\n' "$*"
}

warn() {
  printf '[doctor] WARN  %s\n' "$*" >&2
  STATUS=1
}

info() {
  printf '[doctor] INFO  %s\n' "$*"
}

check_symlink() {
  file=$1

  if [ -L "$file" ]; then
    ok "symlink: $file -> $(readlink "$file")"
  elif [ -e "$file" ]; then
    warn "regular file: $file"
  else
    warn "missing: $file"
  fi
}

check_stow() {
  if ! command -v stow >/dev/null 2>&1; then
    warn "stow not found"
    return
  fi

  if stow_version_ok; then
    ok "stow version: $(stow --version 2>&1 | head -n 1)"
  else
    warn "stow version too old: $(stow --version 2>&1 | head -n 1)"
  fi
}

check_broken_links() {
  for dir in \
    "$HOME/.config/zsh" \
    "$HOME/.config/git" \
    "$HOME/.config/tmux" \
    "$HOME/.config/nvim"
  do
    [ -d "$dir" ] || continue

    find "$dir" -maxdepth 5 -type l | while IFS= read -r link; do
      if [ ! -e "$link" ]; then
        warn "broken symlink: $link"
      fi
    done
  done
}

check_zsh() {
  if ! command -v zsh >/dev/null 2>&1; then
    warn "zsh not found"
    return
  fi

  if zsh -lic 'echo zsh-ok' 2>/dev/null | grep -q '^zsh-ok$'; then
    ok "zsh startup"
  else
    warn "zsh startup failed"
  fi
}

check_git() {
  if ! command -v git >/dev/null 2>&1; then
    warn "git not found"
    return
  fi

  if git config --global --includes --list --show-origin >/dev/null 2>&1 \
    && git config --includes --get user.name >/dev/null 2>&1; then
    ok "git global config"
  else
    warn "git global config failed"
  fi
}

check_tmux() {
  if ! command -v tmux >/dev/null 2>&1; then
    warn "tmux not found"
    return
  fi

  if tmux -L dotfiles-doctor -f "$HOME/.config/tmux/tmux.conf" start-server >/dev/null 2>&1; then
    tmux -L dotfiles-doctor kill-server >/dev/null 2>&1 || true
    ok "tmux config"
  else
    warn "tmux config failed"
  fi
}

check_nvim() {
  if ! command -v nvim >/dev/null 2>&1; then
    warn "nvim not found"
    return
  fi

  if nvim --headless +qa >/dev/null 2>&1; then
    ok "nvim config"
  else
    warn "nvim config failed"
  fi
}

check_secret_scan() {
  pattern='ghp_|password[[:space:]]*=|api[_-]?key[[:space:]]*=|access[-_.]?token|secret[[:space:]]*='

  if command -v rg >/dev/null 2>&1; then
    if rg -l -i "$pattern" "$REPO_DIR/stow" "$REPO_DIR/install.sh" "$REPO_DIR/README.md" "$REPO_DIR/packages" "$REPO_DIR/scripts/install-packages.sh" >/dev/null 2>&1; then
      warn "possible secret pattern found in public files"
    else
      ok "secret scan"
    fi
    return
  fi

  if grep -RInE "$pattern" "$REPO_DIR/stow" "$REPO_DIR/install.sh" "$REPO_DIR/README.md" "$REPO_DIR/packages" "$REPO_DIR/scripts/install-packages.sh" >/dev/null 2>&1; then
    warn "possible secret pattern found in public files"
  else
    ok "secret scan"
  fi
}

main() {
  info "OS: $(uname -s) $(uname -m)"
  info "HOME: $HOME"

  check_stow

  for file in \
    "$HOME/.zshenv" \
    "$HOME/.gitconfig" \
    "$HOME/.config/zsh/.zshenv" \
    "$HOME/.config/zsh/.zprofile" \
    "$HOME/.config/zsh/.zshrc" \
    "$HOME/.config/zsh/functions.d/git_repository.zsh" \
    "$HOME/.config/git/ignore" \
    "$HOME/.config/git/ghq.config" \
    "$HOME/.config/tmux/tmux.conf" \
    "$HOME/.config/nvim/init.vim"
  do
    check_symlink "$file"
  done

  if [ -f "$HOME/.config/git/config.local" ]; then
    ok "local git config present"
  else
    warn "missing local git config: $HOME/.config/git/config.local"
  fi

  check_broken_links
  check_zsh
  check_git
  check_tmux
  check_nvim
  check_secret_scan

  exit "$STATUS"
}

main "$@"
