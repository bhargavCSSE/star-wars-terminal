# star-wars-terminal: Jedi prompt for bash and zsh.
# Sourced from ~/.bashrc / ~/.zshrc by the installer.

# Load once per shell (a login shell may read both ~/.bash_profile and ~/.bashrc)
[ -n "${_SWT_LOADED:-}" ] && return 0
_SWT_LOADED=1

SWT_HOME="${SWT_HOME:-$HOME/.config/star-wars-terminal}"

# Oh My Posh installed by the script lives in ~/.local/bin on Linux
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) [ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH" ;;
esac

# Lightsaber color. Red is kept for failed commands, so it isn't offered here.
_swt_sabers="blue green purple yellow white"
_swt_rgb() {
  case "$1" in
    green) echo "166;227;161" ;; purple) echo "203;166;247" ;;
    yellow) echo "249;226;175" ;; white) echo "239;241;245" ;; *) echo "137;180;250" ;;
  esac
}
if [ -f "$SWT_HOME/saber.txt" ]; then
  _swt_saved="$(head -n 1 "$SWT_HOME/saber.txt" | tr -d '[:space:]')"
  case " $_swt_sabers " in *" $_swt_saved "*) [ -n "$_swt_saved" ] && export JEDI_SABER="$_swt_saved" ;; esac
  unset _swt_saved
fi

# Usage: saber green   (no argument shows the current color and the options)
saber() {
  if [ -z "$1" ]; then
    echo "Current saber: ${JEDI_SABER:-blue}. Options: blue, green, purple, yellow, white"
    return 0
  fi
  _swt_pick="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case " $_swt_sabers " in
    *" $_swt_pick "*) ;;
    *) echo "saber: \"$1\" isn't a saber color. Options: blue, green, purple, yellow, white" >&2; unset _swt_pick; return 1 ;;
  esac
  export JEDI_SABER="$_swt_pick"
  printf '%s\n' "$_swt_pick" > "$SWT_HOME/saber.txt"
  unset _swt_pick
}

# Prompt
if command -v oh-my-posh >/dev/null 2>&1; then
  if [ -n "$ZSH_VERSION" ]; then
    eval "$(oh-my-posh init zsh --config "$SWT_HOME/jedi.omp.json")"
  elif [ -n "$BASH_VERSION" ]; then
    eval "$(oh-my-posh init bash --config "$SWT_HOME/jedi.omp.json")"
  fi
fi

# A line from the Jedi Archives for each new session
if [ -f "$SWT_HOME/shell/quotes.txt" ]; then
  _swt_count="$(grep -c '|' "$SWT_HOME/shell/quotes.txt")"
  if [ "$_swt_count" -gt 0 ]; then
    _swt_line="$(grep '|' "$SWT_HOME/shell/quotes.txt" | sed -n "$(( RANDOM % _swt_count + 1 ))p")"
    printf '\033[38;2;%sm\356\267\230\033[0m \033[38;2;166;173;200m%s\033[0m \033[38;2;108;112;134m- %s\033[0m\n' \
      "$(_swt_rgb "${JEDI_SABER:-blue}")" "${_swt_line%%|*}" "${_swt_line#*|}"
  fi
  unset _swt_count _swt_line
fi
