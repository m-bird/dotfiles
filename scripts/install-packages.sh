#!/usr/bin/env sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WITH_WORK=0

log() {
  printf '[packages] %s\n' "$*"
}

die() {
  printf '[packages] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: sh scripts/install-packages.sh [--with-work]

Options:
  --with-work  Install work-specific Homebrew packages too
  -h           Show this help
  --help       Show this help
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --with-work)
        WITH_WORK=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done
}

install_brewfile() {
  file=$1
  [ -f "$file" ] || die "missing Brewfile: $file"
  brew bundle --file="$file"
}

main() {
  parse_args "$@"

  case "$(uname -s)" in
    Darwin|Linux)
      command -v brew >/dev/null 2>&1 || die "Homebrew is required on macOS/Linux"
      install_brewfile "$REPO_DIR/packages/Brewfile"
      if [ "$WITH_WORK" -eq 1 ]; then
        install_brewfile "$REPO_DIR/packages/Brewfile.work"
      fi
      ;;
    FreeBSD)
      die "FreeBSD package automation is not implemented yet. Install packages manually."
      ;;
    *)
      die "unsupported OS: $(uname -s)"
      ;;
  esac

  log "done"
}

main "$@"
