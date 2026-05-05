# Shared helpers sourced by install.sh and scripts/*.sh

stow_version_ok() {
  version=$(stow --version 2>&1 | sed -n 's/.* \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n 1)
  [ -n "$version" ] || return 1

  major=$(printf '%s' "$version" | cut -d. -f1)
  minor=$(printf '%s' "$version" | cut -d. -f2)
  patch=$(printf '%s' "$version" | cut -d. -f3)

  if [ "$major" -gt 2 ]; then return 0; fi
  if [ "$major" -lt 2 ]; then return 1; fi
  if [ "$minor" -gt 4 ]; then return 0; fi
  if [ "$minor" -lt 4 ]; then return 1; fi
  return 0
}
