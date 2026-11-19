# shellcheck shell=bash
# nullptr Workstation — shared helpers for the workstation commands.
# Installed to /usr/local/lib/nullptr/nullptr-common.sh and sourced by
# every command in /usr/local/bin. Not meant to be executed directly.
#
# There is no project model: a project is a folder (usually a git repository) in ~/Projects.
# nw_workdir picks the folder the tools act on: the repository you are in, else the one
# open in AstroVim (it records that in $NW_STATE_DIR/editor-cwd), else ~/Projects.

NW_PREFIX="${NW_PREFIX:-/usr/local}"
NW_SHARE="${NW_SHARE:-$NW_PREFIX/share/nullptr}"
NW_PROJECTS_DIR="${NW_PROJECTS_DIR:-$HOME/Projects}"
NW_STATE_DIR="${NW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/nullptr}"
NW_EDITOR_CWD_FILE="$NW_STATE_DIR/editor-cwd"
NW_NVIM_SOCKET="${NW_NVIM_SOCKET:-${XDG_RUNTIME_DIR:-/tmp}/nullptr-nvim-$(id -u).sock}"

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

# nw_git_root DIR -> top of the git repository containing DIR, or fails
nw_git_root() { git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null; }

# nw_workdir -> the folder the tools act on (see above)
nw_workdir() {
  local d
  if d="$(nw_git_root "$PWD")" && [ "$d" != "$HOME" ]; then printf '%s\n' "$d"; return 0; fi
  if [ -f "$NW_EDITOR_CWD_FILE" ]; then
    d="$(head -n1 "$NW_EDITOR_CWD_FILE")"
    if [ -n "$d" ] && [ -d "$d" ] && [ "$d" != "$HOME" ]; then printf '%s\n' "$d"; return 0; fi
  fi
  mkdir -p "$NW_PROJECTS_DIR"; printf '%s\n' "$NW_PROJECTS_DIR"
}

# nw_x_env VAR — VAR (DISPLAY or XAUTHORITY) of this user's running i3, if any
nw_x_env() {
  local pid v
  for pid in $(pgrep -u "$(id -u)" -x i3 2>/dev/null); do
    v="$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | sed -n "s/^$1=//p" | head -n1)"
    [ -n "$v" ] && { printf '%s\n' "$v"; return 0; }
  done
  return 1
}

# nw_in_graphical — true if we can open X11 windows. A shell that was started before the
# graphical session (e.g. a tmux window opened from the text console, then startx) has no
# DISPLAY; if this user's i3 is running, use its display instead of refusing.
NW_X_ADOPTED=0
nw_in_graphical() {
  [ -n "${DISPLAY:-}" ] && return 0
  local d a
  d="$(nw_x_env DISPLAY)" || return 1
  export DISPLAY="$d"
  if [ -z "${XAUTHORITY:-}" ]; then a="$(nw_x_env XAUTHORITY || true)"; [ -n "$a" ] && export XAUTHORITY="$a"; fi
  NW_X_ADOPTED=1
  return 0
}

# nw_need_graphical WHAT — stop with a clear way out when there is no graphical session
nw_need_graphical() {
  if nw_in_graphical; then
    if [ "$NW_X_ADOPTED" = 1 ] && [ -z "${TMUX:-}" ] && tty 2>/dev/null | grep -q '^/dev/tty[0-9]'; then
      nw_info "Opening on the graphical screen ($DISPLAY). If you are on a text console, press Ctrl+Alt+F1."
    fi
    return 0
  fi
  if pgrep -x Xorg >/dev/null 2>&1; then
    nw_die "$1 needs the graphical session. It is running on tty1: press Ctrl+Alt+F1."
  fi
  nw_die "$1 needs the graphical session, and it is not running (you are in the text console: no bar at the top).
   Start it:  leave tmux with Ctrl+b d, then type  startx   (on tty1).
   If it fails or closes at once:  less ~/.local/state/nullptr/xsession.log   and  helpme recovery"
}

# nw_i3 ARGS… — i3-msg that always reaches the *running* i3. I3SOCK is ignored on purpose:
# a tmux server outlives an i3 restart (exit i3, startx again) and keeps the old socket path;
# without I3SOCK, i3-msg reads the live path from the X root window.
nw_i3() { env -u I3SOCK i3-msg "$@"; }

# Workspaces (keep in sync with config/dotfiles/i3/config and nullptr/project.lua):
#   1 astro · 2 firefox · 3 libresprite · 4 tiled · 5 blockbench · 6 run · 7 tools
nw_ws_name() {
  case "$1" in
    1|astro|code)    echo "1: astro" ;;
    2|firefox|web)   echo "2: firefox" ;;
    3|libresprite)   echo "3: libresprite" ;;
    4|tiled|tiles)   echo "4: tiled" ;;
    5|blockbench|3d) echo "5: blockbench" ;;
    6|run)           echo "6: run" ;;
    7|tools)         echo "7: tools" ;;
    *)               echo "$1" ;;
  esac
}

# nw_i3_workspace ROLE|N — show that workspace (astro, firefox, libresprite, tiled, blockbench, run, tools) if i3 runs
nw_i3_workspace() {
  local name
  name="$(nw_ws_name "$1")"
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
  nw_i3_workspace astro
}

# Lua string literal for a path
nw_lua_str() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^/"/' -e 's/$/"/'; }
