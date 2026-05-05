#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TARGET="${HOME:?}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$HOME/.local/state/dotfiles/backups/$TIMESTAMP"

. "$REPO_DIR/scripts/lib.sh"

log() { printf '[install] %s\n' "$*"; }
die() { printf '[install] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: sh install.sh [-h]

Options:
  -h, --help    Show this help
EOF
}

check_stow() {
  command -v stow >/dev/null 2>&1 || die "stow not found. Install stow >= 2.4.0 first."
  stow_version_ok || die "stow >= 2.4.0 required. Install with Homebrew or pkg first."
  log "stow version OK"
}

create_dirs() {
  # Only dirs not covered by stow --no-folding (no managed files inside)
  mkdir -p \
    "$HOME/.local/state/zsh" \
    "$HOME/.cache/zsh"

  if [ ! -f "$HOME/.config/git/config.local" ]; then
    mkdir -p "$HOME/.config/git"
    : > "$HOME/.config/git/config.local"
    log "created empty local git config: $HOME/.config/git/config.local"
  fi
}

backup_file() {
  file=$1
  [ -e "$file" ] || return 0
  [ ! -L "$file" ] || return 0  # already a symlink — skip

  rel=${file#"$HOME/"}
  dest="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$dest")"
  cp -p "$file" "$dest"
  rm -f "$file"
  log "backed up: $file -> $dest"
}

backup_conflicts() {
  # Runs only on first install: backs up real files that stow would refuse to overwrite.
  # On subsequent runs all targets are already symlinks, so this is a no-op.
  mkdir -p "$BACKUP_DIR"

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
    backup_file "$file"
  done

  log "backup directory: $BACKUP_DIR"
}

apply_stow() {
  stow -d "$REPO_DIR" -t "$TARGET" --dotfiles --no-folding --restow home
  log "stow apply complete"
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    "") ;;
    *) die "unknown option: $1" ;;
  esac

  check_stow
  create_dirs
  backup_conflicts
  apply_stow
  log "done"
}

main "$@"
