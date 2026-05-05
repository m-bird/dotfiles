function peco-src() {
  local repo

  repo=$(ghq list | peco --query "$LBUFFER") || return 0
  if [[ -n "$repo" ]]; then
    repo=$(ghq list --full-path --exact "$repo")
    BUFFER="cd ${repo}"
    zle accept-line
  fi
  zle clear-screen
}

if command -v peco >/dev/null 2>&1 && command -v ghq >/dev/null 2>&1; then
  zle -N peco-src
  bindkey "^G" peco-src
fi
