#!/usr/bin/env bash
# star-wars-terminal installer for macOS and Linux.
#
#   Install:    curl -fsSL https://raw.githubusercontent.com/bhargavCSSE/star-wars-terminal/master/install.sh | bash
#   Uninstall:  curl -fsSL https://raw.githubusercontent.com/bhargavCSSE/star-wars-terminal/master/install.sh | bash -s -- --uninstall
#   From a clone:  ./install.sh [--uninstall] [--skip-deps]
#
# What it does:
#   - installs Oh My Posh and JetBrainsMono Nerd Font (Homebrew when available, official downloads otherwise)
#   - copies the theme to ~/.config/star-wars-terminal
#   - hooks the prompt into bash, zsh, fish and PowerShell (whichever you have)
#   - themes iTerm2, kitty and the VS Code terminal when they're installed
# Every settings file it edits is backed up first. Running it again is safe.

set -u

SWT_REPO="${SWT_REPO:-bhargavCSSE/star-wars-terminal}"
SWT_BRANCH="${SWT_BRANCH:-master}"
SWT_HOME="${SWT_HOME:-$HOME/.config/star-wars-terminal}"
SWT_BEGIN="# >>> star-wars-terminal >>>"
SWT_END="# <<< star-wars-terminal <<<"
SWT_ITERM_GUID="star-wars-terminal-0001"  # matches terminals/iterm2-profile.json
SWT_STAMP="$(date +%Y%m%d-%H%M%S)"
SWT_TMP=""
SWT_SRC=""

step() { printf '\033[36m\342\234\246 %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m%s\033[0m\n' "$1"; }
note() { printf '  \033[90m%s\033[0m\n' "$1"; }
warn() { printf '  \033[33m%s\033[0m\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

swt_os() {
  case "${SWT_OS:-$(uname -s)}" in
    Darwin|macos) echo macos ;;
    Linux|linux) echo linux ;;
    *) echo other ;;
  esac
}

download() { # url file
  if have curl; then curl -fsSL "$1" -o "$2"; elif have wget; then wget -qO "$2" "$1"; else return 1; fi
}

# ------------------------------------------------------------------ source files

# Sets SWT_SRC to a folder holding the repo files (a clone, $SWT_SOURCE, or a fresh download)
get_source() {
  if [ -n "${SWT_SOURCE:-}" ] && [ -f "$SWT_SOURCE/theme/jedi.omp.json" ]; then SWT_SRC="$SWT_SOURCE"; return 0; fi
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    local dir; dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$dir/theme/jedi.omp.json" ]; then SWT_SRC="$dir"; return 0; fi
  fi
  SWT_TMP="$(mktemp -d)"
  local url="https://github.com/$SWT_REPO/archive/refs/heads/$SWT_BRANCH.tar.gz"
  note "Downloading $url"
  download "$url" "$SWT_TMP/src.tar.gz" || return 1
  tar -xzf "$SWT_TMP/src.tar.gz" -C "$SWT_TMP" || return 1
  local d
  for d in "$SWT_TMP"/*/; do [ -f "$d/theme/jedi.omp.json" ] && { SWT_SRC="${d%/}"; return 0; }; done
  return 1
}

# ------------------------------------------------------------------ file blocks

add_block() { # file line...
  local file="$1"; shift
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -qF "$SWT_BEGIN" "$file"; then return 1; fi
  { printf '\n%s\n' "$SWT_BEGIN"; printf '%s\n' "$@"; printf '%s\n' "$SWT_END"; } >> "$file"
}

remove_block() { # file
  local file="$1"
  [ -f "$file" ] && grep -qF "$SWT_BEGIN" "$file" || return 1
  local tmp; tmp="$(mktemp)"
  # drop the block, then any blank lines left at the end of the file
  awk -v b="$SWT_BEGIN" -v e="$SWT_END" '$0==b{skip=1} !skip{line[++n]=$0} $0==e{skip=0}
    END{while (n > 0 && line[n] == "") n--; for (i = 1; i <= n; i++) print line[i]}' "$file" > "$tmp" && cat "$tmp" > "$file"
  rm -f "$tmp"
}

backup() { # file
  cp "$1" "$1.swt-backup-$SWT_STAMP" && echo "$1.swt-backup-$SWT_STAMP"
}

# ------------------------------------------------------------------ dependencies

install_oh_my_posh() {
  if have oh-my-posh; then ok "Oh My Posh is already installed."; return 0; fi
  if [ "$(swt_os)" = macos ] && have brew; then
    brew install jandedobbeleer/oh-my-posh/oh-my-posh && { ok "Installed Oh My Posh."; return 0; }
  fi
  mkdir -p "$HOME/.local/bin"
  local script; script="$(mktemp)"
  download "https://ohmyposh.dev/install.sh" "$script" && bash "$script" -d "$HOME/.local/bin"
  rm -f "$script"
  export PATH="$HOME/.local/bin:$PATH"
  have oh-my-posh && ok "Installed Oh My Posh to ~/.local/bin." || warn "Couldn't install Oh My Posh. See https://ohmyposh.dev/docs/installation"
}

font_installed() {
  if [ "$(swt_os)" = macos ]; then
    ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null | grep -qi 'JetBrainsMonoNerdFontMono'
  else
    have fc-list && fc-list 2>/dev/null | grep -qi 'JetBrainsMono Nerd Font Mono'
  fi
}

install_font() {
  if font_installed; then ok "JetBrainsMono Nerd Font is already installed."; return 0; fi
  if [ "$(swt_os)" = macos ] && have brew; then
    brew install --cask font-jetbrains-mono-nerd-font && { ok "Installed JetBrainsMono Nerd Font."; return 0; }
  fi
  local dest
  if [ "$(swt_os)" = macos ]; then dest="$HOME/Library/Fonts"; else dest="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"; fi
  mkdir -p "$dest"
  local tmp; tmp="$(mktemp -d)"
  local base="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
  if have xz && download "$base/JetBrainsMono.tar.xz" "$tmp/font.tar.xz"; then
    tar -xJf "$tmp/font.tar.xz" -C "$tmp"
  elif have unzip && download "$base/JetBrainsMono.zip" "$tmp/font.zip"; then
    unzip -q "$tmp/font.zip" -d "$tmp"
  else
    warn "Couldn't download the font (needs curl or wget, plus xz or unzip)."; rm -rf "$tmp"; return 1
  fi
  find "$tmp" -name 'JetBrainsMonoNerdFontMono-*.ttf' -exec cp {} "$dest/" \;
  rm -rf "$tmp"
  have fc-cache && fc-cache -f "$dest" >/dev/null 2>&1
  ok "Installed JetBrainsMono Nerd Font Mono to $dest"
}

# ------------------------------------------------------------------ steps

copy_files() { # source
  mkdir -p "$SWT_HOME"
  cp "$1/theme/jedi.omp.json" "$SWT_HOME/jedi.omp.json"
  cp "$1/assets/starfield.png" "$SWT_HOME/starfield.png"
  rm -rf "$SWT_HOME/shell" "$SWT_HOME/terminals"
  cp -R "$1/shell" "$SWT_HOME/shell"
  cp -R "$1/terminals" "$SWT_HOME/terminals"
  ok "Copied the theme to $SWT_HOME"
}

hook_posix_rc() { # file
  if add_block "$1" "export SWT_HOME=\"$SWT_HOME\"" '[ -f "$SWT_HOME/shell/jedi.sh" ] && . "$SWT_HOME/shell/jedi.sh"'; then
    ok "Hooked the prompt into $1"
  else
    note "Already hooked: $1"
  fi
}

pwsh_profile() { pwsh -NoLogo -NoProfile -Command '$PROFILE.CurrentUserAllHosts' 2>/dev/null | tr -d '\r'; }

hook_shells() {
  local shell_name; shell_name="$(basename "${SHELL:-}")"
  if have zsh && { [ -f "$HOME/.zshrc" ] || [ "$shell_name" = zsh ]; }; then hook_posix_rc "$HOME/.zshrc"; fi
  if have bash && { [ -f "$HOME/.bashrc" ] || [ "$shell_name" = bash ]; }; then hook_posix_rc "$HOME/.bashrc"; fi
  if [ "$(swt_os)" = macos ] && [ -f "$HOME/.bash_profile" ]; then hook_posix_rc "$HOME/.bash_profile"; fi
  if have fish; then
    mkdir -p "$HOME/.config/fish/conf.d"
    printf 'set -gx SWT_HOME "%s"\nsource "$SWT_HOME/shell/jedi.fish"\n' "$SWT_HOME" > "$HOME/.config/fish/conf.d/star-wars-terminal.fish"
    ok "Hooked the prompt into fish"
  fi
  if have pwsh; then
    local profile; profile="$(pwsh_profile)"
    if [ -n "$profile" ]; then
      if add_block "$profile" "\$swtPrompt = '$SWT_HOME/shell/jedi.ps1'" 'if (Test-Path $swtPrompt) { . $swtPrompt }'; then
        ok "Hooked the prompt into PowerShell ($profile)"
      else
        note "Already hooked: $profile"
      fi
    fi
  fi
}

theme_iterm2() {
  [ "$(swt_os)" = macos ] || return 0
  [ -d "/Applications/iTerm.app" ] || [ -d "$HOME/Library/Application Support/iTerm2" ] || return 0
  local dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  mkdir -p "$dir"
  sed "s|{{BACKGROUND}}|$SWT_HOME/starfield.png|" "$SWT_HOME/terminals/iterm2-profile.json" > "$dir/star-wars-terminal.json"

  # Make it the default profile. iTerm2 restores a dynamic profile as the default at launch,
  # and only writes this setting when you change the default yourself.
  local current; current="$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null)"
  if [ "$current" != "$SWT_ITERM_GUID" ]; then
    [ -n "$current" ] && printf '%s
' "$current" > "$SWT_HOME/iterm2-previous-default"
    defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$SWT_ITERM_GUID"
  fi
  ok "Added a \"Star Wars\" profile to iTerm2 and made it the default."
  if pgrep -x iTerm2 >/dev/null 2>&1; then
    warn "iTerm2 is open: quit it (Cmd+Q) and reopen it to start using the Star Wars profile."
  fi
}

theme_kitty() {
  have kitty || [ -d "$HOME/.config/kitty" ] || return 0
  mkdir -p "$HOME/.config/kitty"
  sed "s|{{BACKGROUND}}|$SWT_HOME/starfield.png|" "$SWT_HOME/terminals/kitty.conf" > "$HOME/.config/kitty/star-wars-terminal.conf"
  add_block "$HOME/.config/kitty/kitty.conf" "include star-wars-terminal.conf" >/dev/null
  ok "Themed kitty (~/.config/kitty/star-wars-terminal.conf)"
}

python_ok() {
  have python3 || return 1
  # On macOS /usr/bin/python3 is a stub that pops up an installer when the developer tools are missing
  if [ "$(swt_os)" = macos ] && [ "$(command -v python3)" = /usr/bin/python3 ]; then xcode-select -p >/dev/null 2>&1 || return 1; fi
  return 0
}

merge_vscode() { # settings.json ours.json
  python3 - "$1" "$2" <<'PY'
import json, re, sys
path, ours_path = sys.argv[1], sys.argv[2]

def strip_jsonc(text):
    out, i, in_str, esc = [], 0, False, False
    while i < len(text):
        c = text[i]
        if in_str:
            out.append(c)
            if esc: esc = False
            elif c == '\\': esc = True
            elif c == '"': in_str = False
            i += 1; continue
        if c == '"':
            in_str = True; out.append(c); i += 1; continue
        if text.startswith('//', i):
            j = text.find('\n', i); i = len(text) if j < 0 else j; continue
        if text.startswith('/*', i):
            j = text.find('*/', i + 2); i = len(text) if j < 0 else j + 2; continue
        out.append(c); i += 1
    return re.sub(r',(\s*[}\]])', r'\1', ''.join(out))

try:
    with open(path, encoding='utf-8-sig') as f:
        text = f.read()
except FileNotFoundError:
    text = '{}'
settings = json.loads(strip_jsonc(text).strip() or '{}')
with open(ours_path, encoding='utf-8') as f:
    ours = json.load(f)
for key, value in ours.items():
    if key == 'workbench.colorCustomizations':
        settings.setdefault(key, {}).update(value)
    else:
        settings[key] = value
with open(path, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=4)
    f.write('\n')
PY
}

theme_vscode() {
  local base
  if [ "$(swt_os)" = macos ]; then base="$HOME/Library/Application Support"; else base="${XDG_CONFIG_HOME:-$HOME/.config}"; fi
  local app
  for app in "Code" "Code - Insiders" "Cursor" "VSCodium"; do
    local file="$base/$app/User/settings.json"
    [ -d "$base/$app/User" ] || continue
    if ! python_ok; then
      note "$app: add the settings in $SWT_HOME/terminals/vscode-settings.json to your settings.json (needs python3 to do it automatically)."
      continue
    fi
    local saved=""
    [ -f "$file" ] && saved="$(backup "$file")"
    if merge_vscode "$file" "$SWT_HOME/terminals/vscode-settings.json"; then
      ok "Themed the $app terminal${saved:+. Backup: $saved}"
    else
      warn "Couldn't update $file. Your file is unchanged."
      [ -n "$saved" ] && cp "$saved" "$file"
    fi
  done
}

terminal_notes() {
  note "Other terminals: set the font to \"JetBrainsMono Nerd Font Mono\" and use the Catppuccin Mocha colors."
  note "Ready-made files for Alacritty and WezTerm are in $SWT_HOME/terminals/"
  if [ "$(swt_os)" = linux ] && ! have kitty && [ ! -d "$HOME/.config/kitty" ]; then
    warn "The starfield background needs a terminal that can show images. GNOME's default terminals"
    warn "(Ptyxis and GNOME Terminal) can't. Install kitty (e.g. sudo dnf install kitty or"
    warn "sudo apt install kitty) and run this installer again to get it."
  fi
  if [ "$(swt_os)" = macos ] && [ ! -d "/Applications/iTerm.app" ] && [ ! -d "$HOME/Library/Application Support/iTerm2" ]; then
    warn "To see the starfield in Terminal.app, open Terminal > Settings > Profiles > Window,"
    warn "and under Background > Image choose $SWT_HOME/starfield.png"
  fi
}

# ------------------------------------------------------------------ main

install_swt() {
  local skip_deps="${SWT_SKIP_DEPS:-}"
  [ "${1:-}" = "--skip-deps" ] && skip_deps=1
  if [ "$(swt_os)" = other ]; then
    warn "This installer supports macOS and Linux. On Windows, run install.ps1 in PowerShell."
    return 1
  fi
  printf '\n  \033[33mA long time ago in a terminal far, far away...\033[0m\n\n'
  get_source || { warn "Couldn't get the theme files."; [ -n "$SWT_TMP" ] && rm -rf "$SWT_TMP"; return 1; }

  if [ -z "$skip_deps" ]; then
    step "Installing Oh My Posh and JetBrainsMono Nerd Font"
    install_oh_my_posh
    install_font
  fi

  step "Copying the theme"
  copy_files "$SWT_SRC"

  step "Hooking the prompt into your shells"
  hook_shells

  step "Theming your terminals"
  theme_iterm2
  theme_kitty
  theme_vscode
  terminal_notes

  [ -n "$SWT_TMP" ] && rm -rf "$SWT_TMP"
  printf '\n  \033[32mDone. Open a new terminal window to see your lightsaber.\033[0m\n'
  printf '  \033[32mChange its color any time:  saber green   (blue, green, purple, yellow, white)\033[0m\n'
  printf '  \033[33mMay the Force be with you.\033[0m\n\n'
}

uninstall_swt() {
  step "Removing star-wars-terminal"
  local file
  for file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    remove_block "$file" && ok "Unhooked $file"
  done
  if have pwsh; then
    file="$(pwsh_profile)"
    [ -n "$file" ] && remove_block "$file" && ok "Unhooked $file"
  fi
  [ -f "$HOME/.config/fish/conf.d/star-wars-terminal.fish" ] && rm -f "$HOME/.config/fish/conf.d/star-wars-terminal.fish" && ok "Unhooked fish"
  remove_block "$HOME/.config/kitty/kitty.conf" && rm -f "$HOME/.config/kitty/star-wars-terminal.conf" && ok "Removed the kitty theme"
  if [ "$(swt_os)" = macos ] && [ "$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null)" = "$SWT_ITERM_GUID" ]; then
    # Hand the default back to the profile that had it before the install
    if [ -s "$SWT_HOME/iterm2-previous-default" ]; then
      defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$(head -n 1 "$SWT_HOME/iterm2-previous-default")"
    else
      defaults delete com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null
    fi
    ok "Restored your previous default iTerm2 profile"
  fi
  [ -f "$HOME/Library/Application Support/iTerm2/DynamicProfiles/star-wars-terminal.json" ] &&
    rm -f "$HOME/Library/Application Support/iTerm2/DynamicProfiles/star-wars-terminal.json" && ok "Removed the iTerm2 profile"
  [ -d "$SWT_HOME" ] && rm -rf "$SWT_HOME" && ok "Removed $SWT_HOME"
  note "Kept: Oh My Posh, the Nerd Font and the VS Code terminal settings."
  note "Earlier versions of each edited settings file are saved next to it as *.swt-backup-*."
}

main() {
  case "${1:-}" in
    --uninstall) uninstall_swt ;;
    --skip-deps|"") install_swt "${1:-}" ;;
    -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null || echo "Usage: install.sh [--uninstall] [--skip-deps]" ;;
    *) echo "Unknown option: $1 (use --uninstall or --skip-deps)" >&2; return 1 ;;
  esac
}

[ -n "${SWT_NO_AUTORUN:-}" ] || main "$@"
