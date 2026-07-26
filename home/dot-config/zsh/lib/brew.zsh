# Homebrew の設置場所に関する正本。
typeset -g ZDOT_HOMEBREW_PREFIX=
typeset +x ZDOT_HOMEBREW_PREFIX

for _zdot_brew_prefix in \
  /opt/homebrew \
  /usr/local \
  /home/linuxbrew/.linuxbrew
do
  if [[ -x "${_zdot_brew_prefix}/bin/brew" ]]; then
    ZDOT_HOMEBREW_PREFIX=$_zdot_brew_prefix
    break
  fi
done

unset _zdot_brew_prefix
