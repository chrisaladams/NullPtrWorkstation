# shellcheck shell=bash
# nullptr Workstation — shared helpers for the workstation commands.
# Installed to /usr/local/lib/nullptr/nullptr-common.sh and sourced by
# every command in /usr/local/bin. Not meant to be executed directly.
#
# Project model
#   A project is a directory containing a `.nullptr-project` file:
#       type=raylib|gameboy
#       target=<executable or ROM base name>
#   The *active project* is stored in $NW_STATE_DIR/active-project and is
#   updated by `projects`, `code`, `new-*` and by AstroVim whenever you open
#   or switch to a project there.

NW_PREFIX="${NW_PREFIX:-/usr/local}"
NW_SHARE="${NW_SHARE:-$NW_PREFIX/share/nullptr}"
NW_TEMPLATES="${NW_TEMPLATES:-$NW_SHARE/templates}"
NW_PROJECTS_DIR="${NW_PROJECTS_DIR:-$HOME/Projects}"
NW_STATE_DIR="${NW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/nullptr}"
NW_ACTIVE_FILE="$NW_STATE_DIR/active-project"
NW_RECENT_FILE="$NW_STATE_DIR/recent-projects"
NW_NVIM_SOCKET="${NW_NVIM_SOCKET:-${XDG_RUNTIME_DIR:-/tmp}/nullptr-nvim-$(id -u).sock}"
GBDK_HOME="${GBDK_HOME:-/opt/gbdk}"
EMULICIOUS_HOME="${EMULICIOUS_HOME:-/opt/emulicious}"
export GBDK_HOME

if [ -t 2 ]; then
  NW_C_BLUE=$'\e[38;5;111m' NW_C_GREEN=$'\e[38;5;150m' NW_C_YELLOW=$'\e[38;5;221m'
  NW_C_RED=$'\e[38;5;204m' NW_C_DIM=$'\e[2m' NW_C_BOLD=$'\e[1m' NW_C_OFF=$'\e[0m'
else
  NW_C_BLUE='' NW_C_GREEN='' NW_C_YELLOW='' NW_C_RED='' NW_C_DIM='' NW_C_BOLD='' NW_C_OFF=''
fi

nw_info() { printf '%s==>%s %s\n' "$NW_C_BLUE" "$NW_C_OFF" "$*" >&2; }
nw_ok()   { printf '%s ✔ %s %s\n' "$NW_C_GREEN" "$NW_C_OFF" "$*" >&2; }
nw_warn() { printf '%s !  %s %s\n' "$NW_C_YELLOW" "$NW_C_OFF" "$*" >&2; }
nw_die()  { printf '%s ✘ %s %s\n' "$NW_C_RED" "$NW_C_OFF" "$*" >&2; exit 1; }

nw_have() { command -v "$1" >/dev/null 2>&1; }

# nw_abspath PATH -> absolute, symlink-resolved path (PATH must exist)
nw_abspath() { (cd -P -- "$1" 2>/dev/null && pwd) || return 1; }

# nw_find_root DIR -> prints project root containing DIR, or fails
nw_find_root() {
  local d
  d="$(nw_abspath "${1:-$PWD}")" || return 1
  while [ -n "$d" ]; do
    if [ -f "$d/.nullptr-project" ]; then printf '%s\n' "$d"; return 0; fi
    [ "$d" = "/" ] && break
    d="$(dirname -- "$d")"
  done
  return 1
}

# nw_meta ROOT KEY -> value from .nullptr-project
nw_meta() {
  sed -n "s/^$2=//p" "$1/.nullptr-project" 2>/dev/null | head -n1
}

nw_type()   { nw_meta "$1" type; }
nw_target() { local t; t="$(nw_meta "$1" target)"; printf '%s\n' "${t:-$(basename -- "$1")}"; }

nw_active_get() {
  local p
  [ -f "$NW_ACTIVE_FILE" ] || return 1
  p="$(head -n1 "$NW_ACTIVE_FILE")"
  [ -n "$p" ] && [ -f "$p/.nullptr-project" ] || return 1
  printf '%s\n' "$p"
}

# nw_active_set ROOT — mark ROOT as the active project and record it as recent
nw_active_set() {
  local root tmp
  root="$(nw_find_root "$1")" || nw_die "Not a nullptr project: $1"
  mkdir -p "$NW_STATE_DIR"
  tmp="$(mktemp "$NW_STATE_DIR/.active.XXXXXX")"
  printf '%s\n' "$root" >"$tmp" && mv -f "$tmp" "$NW_ACTIVE_FILE"
  tmp="$(mktemp "$NW_STATE_DIR/.recent.XXXXXX")"
  { printf '%s\n' "$root"; grep -vxF -- "$root" "$NW_RECENT_FILE" 2>/dev/null; } | head -n 20 >"$tmp"
  mv -f "$tmp" "$NW_RECENT_FILE"
  # Let tmux show the project in its status bar (ignored outside tmux).
  if [ -n "${TMUX:-}" ] || tmux has-session -t dev 2>/dev/null; then
    tmux set-environment -g NULLPTR_PROJECT "$root" 2>/dev/null || true
    tmux refresh-client -S 2>/dev/null || true
  fi
}

# nw_resolve_project [PATH] -> prints the project root to operate on.
# Precedence: explicit PATH > the project you are standing in (only if it
# agrees with the active one, or no project is active) > active project.
# If your shell is inside project A but AstroVim/`projects` made B active,
# we refuse instead of guessing.
nw_resolve_project() {
  local arg="${1:-}" here active
  if [ -n "$arg" ]; then
    if [ -d "$arg" ]; then
      nw_find_root "$arg" || nw_die "'$arg' is not inside a nullptr project (no .nullptr-project file)."
      return 0
    elif [ -d "$NW_PROJECTS_DIR/$arg" ]; then
      nw_find_root "$NW_PROJECTS_DIR/$arg" || nw_die "'$NW_PROJECTS_DIR/$arg' has no .nullptr-project file."
      return 0
    fi
    nw_die "No such project: $arg (looked in . and $NW_PROJECTS_DIR)"
  fi
  here="$(nw_find_root "$PWD" 2>/dev/null || true)"
  active="$(nw_active_get 2>/dev/null || true)"
  if [ -n "$here" ] && [ -n "$active" ] && [ "$here" != "$active" ]; then
    nw_warn "You are inside '$(basename "$here")' but the active project is '$(basename "$active")'."
    nw_warn "Refusing to guess. Either:"
    nw_warn "   projects use $(basename "$here")     # make this directory's project active"
    nw_warn "   ${NW_CMD:-build} $(basename "$active")   # name the project explicitly"
    exit 2
  fi
  if [ -n "$here" ]; then printf '%s\n' "$here"; return 0; fi
  if [ -n "$active" ]; then printf '%s\n' "$active"; return 0; fi
  nw_die "No project selected. Run 'projects' to choose one, or cd into a project."
}

nw_banner() {
  # nw_banner VERB ROOT
  printf '%s%s▶ %s%s %s%s%s  %s(%s · %s)%s\n' "$NW_C_BOLD" "$NW_C_BLUE" "$1" "$NW_C_OFF" \
    "$NW_C_BOLD" "$(basename -- "$2")" "$NW_C_OFF" "$NW_C_DIM" "$(nw_type "$2")" "$2" "$NW_C_OFF" >&2
}

# nw_validate_name NAME — safe project directory names only
nw_validate_name() {
  case "$1" in
    ''|.*|*/*) nw_die "Invalid project name '$1'." ;;
  esac
  printf '%s' "$1" | grep -Eq '^[A-Za-z][A-Za-z0-9_-]{0,63}$' ||
    nw_die "Project names must start with a letter and use only letters, digits, '-' or '_' (max 64)."
}

# nw_in_graphical — true if we can open X11 windows
nw_in_graphical() { [ -n "${DISPLAY:-}" ]; }

# nw_i3 ARGS… — i3-msg that always reaches the *running* i3. I3SOCK is ignored on purpose:
# a tmux server outlives an i3 restart (exit i3, startx again) and keeps the old socket path;
# without I3SOCK, i3-msg reads the live path from the X root window.
nw_i3() { env -u I3SOCK i3-msg "$@"; }

# nw_i3_workspace N — switch i3 to workspace N (1 code, 2 art, 3 game, 4 tools) if i3 runs
nw_i3_workspace() {
  local name
  case "$1" in 1) name="1: code" ;; 2) name="2: art" ;; 3) name="3: game" ;; 4) name="4: tools" ;; *) name="$1" ;; esac
  if nw_in_graphical && nw_have i3-msg; then nw_i3 -q "workspace number $name" >/dev/null 2>&1 || true; fi
}

# nw_editor_running — true if the dev AstroVim instance is listening
nw_editor_running() {
  [ -S "$NW_NVIM_SOCKET" ] && nvim --server "$NW_NVIM_SOCKET" --remote-expr '1' >/dev/null 2>&1
}

# nw_editor_lua 'lua code' — run Lua in the running dev editor and focus it
nw_editor_lua() {
  nvim --server "$NW_NVIM_SOCKET" --remote-send "<C-\\><C-n><Cmd>lua $1<CR>" >/dev/null 2>&1 || return 1
  if [ -n "${TMUX:-}" ] || tmux has-session -t dev 2>/dev/null; then tmux select-window -t dev:1 2>/dev/null || true; fi
  nw_i3_workspace 1
}

# Lua string literal for a path
nw_lua_str() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^/"/' -e 's/$/"/'; }
