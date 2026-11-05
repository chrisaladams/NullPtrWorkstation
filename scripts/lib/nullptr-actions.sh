# shellcheck shell=bash
# nullptr Workstation — build / run / debug / clean for each project type.
# Sourced after nullptr-common.sh.

nw_cmake_build_type() { case "$1" in release) echo Release ;; *) echo Debug ;; esac; }

# generic projects: how they are built, from .nullptr-project (build=) or the files present
nw_generic_kind() {
  local root="$1"
  if [ -n "$(nw_meta "$root" build)" ]; then echo custom
  elif [ -f "$root/CMakeLists.txt" ]; then echo cmake
  elif [ -f "$root/Makefile" ] || [ -f "$root/makefile" ]; then echo make
  else echo none; fi
}

nw_artifact() {
  # nw_artifact ROOT CONFIG
  local root="$1" cfg="$2" t a
  t="$(nw_target "$root")"
  case "$(nw_type "$root")" in
    raylib)  printf '%s\n' "$root/build/$cfg/$t" ;;
    gameboy) printf '%s\n' "$root/build/$cfg/$t.gb" ;;
    generic)
      a="$(nw_meta "$root" artifact)"
      if [ -n "$a" ]; then case "$a" in /*) printf '%s\n' "$a" ;; *) printf '%s\n' "$root/$a" ;; esac
      elif [ "$(nw_generic_kind "$root")" = cmake ]; then printf '%s\n' "$root/build/$cfg/$t"
      else printf '%s\n' "$root/$t"; fi ;;
    *) nw_die "Unknown project type in $root/.nullptr-project" ;;
  esac
}

nw_cmake_build() {
  # nw_cmake_build ROOT CONFIG — configure once (Ninja), then build build/CONFIG
  local root="$1" cfg="$2" bdir="$1/build/$2"
  nw_have cmake || nw_die "cmake is not installed."
  if [ ! -f "$bdir/build.ninja" ]; then
    cmake -S "$root" -B "$bdir" -G Ninja \
      -DCMAKE_BUILD_TYPE="$(nw_cmake_build_type "$cfg")" \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
  fi
  cmake --build "$bdir"
  # clangd reads compile_commands.json from the project root
  if [ "$cfg" = debug ] && [ -f "$bdir/compile_commands.json" ]; then
    ln -sfn "build/debug/compile_commands.json" "$root/compile_commands.json"
  fi
}

nw_do_build() {
  # nw_do_build ROOT CONFIG
  local root="$1" cfg="$2"
  case "$(nw_type "$root")" in
    raylib) nw_cmake_build "$root" "$cfg" ;;
    generic)
      case "$(nw_generic_kind "$root")" in
        custom) nw_info "build= from .nullptr-project: $(nw_meta "$root" build)"
                (cd "$root" && CONFIG="$cfg" sh -c "$(nw_meta "$root" build)") ;;
        cmake)  nw_cmake_build "$root" "$cfg" ;;
        make)   make -C "$root" CONFIG="$cfg" ;;
        none)   nw_die "Nothing to build in $root: add a CMakeLists.txt or Makefile, or a build= line to .nullptr-project." ;;
      esac ;;
    gameboy)
      [ -x "$GBDK_HOME/bin/lcc" ] || nw_die "GBDK not found at $GBDK_HOME (see: gb-info)."
      make -C "$root" CONFIG="$cfg" GBDK_HOME="$GBDK_HOME"
      ;;
    *) nw_die "Unknown project type in $root/.nullptr-project" ;;
  esac
  nw_ok "Built $(nw_artifact "$root" "$cfg")"
}

nw_do_clean() {
  local root="$1"
  case "$(nw_type "$root")" in
    raylib)  rm -rf -- "$root/build"; rm -f -- "$root/compile_commands.json" ;;
    gameboy) make -C "$root" clean GBDK_HOME="$GBDK_HOME" ;;
    generic)
      if [ -n "$(nw_meta "$root" clean)" ]; then (cd "$root" && sh -c "$(nw_meta "$root" clean)")
      else case "$(nw_generic_kind "$root")" in
        cmake) rm -rf -- "$root/build"; rm -f -- "$root/compile_commands.json" ;;
        make)  make -C "$root" clean ;;
        *)     nw_warn "No clean= line and no CMake/Make build: nothing removed." ;;
      esac; fi ;;
  esac
  nw_ok "Cleaned $(basename "$root")"
}

nw_emulicious_cmd() {
  # prints the command (one word per line) that starts Emulicious, or fails
  if [ -f "$EMULICIOUS_HOME/Emulicious.jar" ] && nw_have java && nw_have emulicious; then
    printf '%s\n' emulicious
    return 0
  fi
  return 1
}

nw_do_run() {
  # nw_do_run ROOT CONFIG
  local root="$1" cfg="$2" art
  nw_do_build "$root" "$cfg"
  art="$(nw_artifact "$root" "$cfg")"
  case "$(nw_type "$root")" in
    generic)
      # a normal program: runs in this terminal. window=yes in .nullptr-project shows
      # workspace 3 first (windowed programs must be visible to start, e.g. GLFW/SDL)
      [ "$(nw_meta "$root" window)" = yes ] && nw_i3_workspace 3
      if [ -n "$(nw_meta "$root" run)" ]; then
        nw_info "run= from .nullptr-project: $(nw_meta "$root" run)"
        (cd "$root" && CONFIG="$cfg" sh -c "$(nw_meta "$root" run)")
      else
        [ -x "$art" ] || nw_die "No program at $art (set artifact= or run= in .nullptr-project)."
        nw_info "Running $art"
        (cd "$root" && "$art")
      fi
      [ "$(nw_meta "$root" window)" = yes ] && nw_i3_workspace 1
      return 0 ;;
  esac
  nw_in_graphical || nw_die "Running a game needs the graphical session (DISPLAY is not set)."
  case "$(nw_type "$root")" in
    raylib)
      nw_i3_workspace 3
      nw_info "Running $art  (close the game window or press Esc to return)"
      cd "$root" && "$art"
      nw_i3_workspace 1
      ;;
    gameboy)
      local -a emu
      mapfile -t emu < <(nw_emulicious_cmd) || true
      [ "${#emu[@]}" -gt 0 ] || nw_die "Emulicious is not installed. Run: sudo nullptr-install-emulicious"
      nw_i3_workspace 3
      nw_info "Opening $art in Emulicious (workspace 3)"
      cd "$root" && setsid -f "${emu[@]}" "$art" >/dev/null 2>&1 </dev/null
      ;;
  esac
}

nw_do_debug() {
  # nw_do_debug ROOT [backend]
  local root="$1" backend="${2:-nvim}" art
  case "$backend" in
    nvim)
      if nw_editor_running; then
        nw_info "Starting the debugger in AstroVim (tmux window 1)…"
        nw_editor_lua "require('nullptr.project').debug($(nw_lua_str "$root"))" && return 0
      fi
      nw_info "Opening AstroVim and starting the debugger…"
      cd "$root" || nw_die "cannot enter $root"
      exec nvim -c "lua require('nullptr.project').debug($(nw_lua_str "$root"))" "$root/src/main.c"
      ;;
    gdb)
      case "$(nw_type "$root")" in raylib|generic) ;; *) nw_die "--gdb only applies to native (raylib/generic) projects." ;; esac
      nw_do_build "$root" debug
      art="$(nw_artifact "$root" debug)"
      cd "$root" && exec gdb -q -tui -ex "break main" -ex run "$art"
      ;;
    emulicious)
      [ "$(nw_type "$root")" = gameboy ] || nw_die "--emulicious only applies to Game Boy projects."
      nw_do_build "$root" debug
      art="$(nw_artifact "$root" debug)"
      local -a emu
      mapfile -t emu < <(nw_emulicious_cmd) || true
      [ "${#emu[@]}" -gt 0 ] || nw_die "Emulicious is not installed. Run: sudo nullptr-install-emulicious"
      nw_info "Emulicious opens with the ROM. Open Tools ▸ Debugger; C source appears because"
      nw_info "build/debug/*.cdb sits next to the ROM and src/ is on the search path."
      nw_i3_workspace 3
      cd "$root" && setsid -f "${emu[@]}" "$art" >/dev/null 2>&1 </dev/null
      ;;
    vscodium)
      [ "$(nw_type "$root")" = gameboy ] || nw_die "--vscodium only applies to Game Boy projects."
      nw_have codium || nw_die "VSCodium is not installed (it is an optional fallback; see docs/gameboy-debugging.md)."
      nw_do_build "$root" debug
      nw_i3_workspace 4
      setsid -f codium "$root" "$root/src/main.c" >/dev/null 2>&1 </dev/null
      nw_info "VSCodium opened on workspace 4. Press F5 to launch 'Debug ROM in Emulicious'."
      ;;
    *) nw_die "Unknown debugger backend: $backend" ;;
  esac
}
